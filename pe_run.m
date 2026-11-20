function archive = pe_run(mode,backend,experiments)
%PE_RUN Build and run six ideal switched power electronics Simulink models.
%   pe_run('smoke') runs one representative operating point per topology.
%   pe_run runs the representative points and the additional listed scans.
if nargin == 0
    mode = 'full';
end
mode = validatestring(mode, {'full', 'smoke'});
if nargin < 2
    backend = 'switching';
end
if nargin < 3
    experiments = 1:6;
end
native = strcmp(backend,'sps');
sourceFiles = {'pe_run.m','pe_model.m','pe_draw.m','pe_switching.m','README.md'};
engineLabel = 'sim(model) with built-in Simulink blocks and ideal switching state updates';
prefix = 'pe_live';
if native
    load_system('powerlib');
    sourceFiles = {'pe_run.m','pe_sps_run.m','pe_sps_rect.m','pe_sps_inv.m', ...
        'pe_sps_dc.m','pe_draw.m','README_SPS.md'};
    engineLabel = 'sim(model) with Simscape Electrical Specialized Power Systems devices';
    prefix = 'pe_sps';
end
assert(~isempty(ver('simulink')), 'Simulink is required.');
sourceDir = fileparts(mfilename('fullpath'));
assert(exist('pe_draw','file') == 2, ...
    'Keep the MATLAB sources together on the MATLAB path.');

started = datetime('now', 'TimeZone', 'UTC', 'Format','yyyyMMdd_HHmmss_SSS');
tag = [prefix '_' char(started)];
outDir = fullfile(pwd,tag);
assert(~isfolder(outDir), 'This run folder already exists.');
mkdir(outDir);
parts = {'models','diagrams','waveforms','data','source'};
for index = 1:numel(parts)
    mkdir(fullfile(outDir, parts{index}));
end
for name = sourceFiles
    sourceFile = fullfile(sourceDir,name{1});
    if isfile(sourceFile)
        copyfile(sourceFile,fullfile(outDir,'source',name{1}));
    end
end

env = struct('matlab_version', version, 'matlab_release', version('-release'), ...
    'platform', computer, 'products', ver, 'mode', mode, 'run_id', tag, ...
    'start_utc', char(started), 'execution', engineLabel);
write_json(fullfile(outDir,'environment.json'),env);
diary(fullfile(outDir,'run_log.txt'));
logCleanup = onCleanup(@() diary('off'));
fprintf('Power electronics Simulink run %s [%s]\n', tag, mode);
fprintf('MATLAB %s; %s\n', version, computer);

names = {'single_phase_bridge','three_phase_bridge','voltage_source_inverter', ...
    'current_source_inverter','buck_boost','cuk'};
titles = {'Single-phase fully controlled bridge','Three-phase fully controlled bridge', ...
    'Voltage-source inverter','Current-source inverter','Inverting buck-boost','Inverting Cuk'};
frequency = [60 50 50 50 20000 20000];
stepsPerPeriod = [2400 2400 2400 2400 400 400];
startupCycles = [10 10 6 6 200 800];
logCycles = [2 2 2 2 4 4];
channelNames = { ...
    {'AC source (V)','Load voltage (V)','Load current (A)','Conduction state'}, ...
    {'Phase A voltage (V)','Load voltage (V)','Load current (A)','Conduction state'}, ...
    {'Bridge voltage (V)','Load voltage (V)','Load current (A)','Gating sign'}, ...
    {'Injected current (A)','Load voltage (V)','Resistor current (A)','Capacitor current (A)'}, ...
    {'Gate command','Output voltage (V)','Inductor current (A)','Diode conduction'}, ...
    {'Gate command','Output voltage (V)','Input inductor current (A)','Output inductor current (A)'}};
if native
    channelNames{1}{4} = 'SCR 1 gate';
    channelNames{2}{4} = 'SCR 1 gate';
    channelNames{3}{1} = 'Positive diagonal gate';
    channelNames{3}{4} = 'Negative diagonal gate';
    stepsPerPeriod(5:6) = 200;
    startupCycles(5:6) = [3500 9000];
end
conditions = operating_points(mode);
conditions = conditions(ismember([conditions.model],experiments));
rows = cell(0,1);
failures = struct('model',{},'case_id',{},'stage',{},'message',{});
for k = experiments
    mdl = sprintf('%s_%02d_%s',prefix,k,names{k});
    selected = conditions([conditions.model] == k);
    base = sprintf('%02d',k);
    try
        pe_draw(k,fullfile(outDir,'diagrams',[base '_circuit.png']));
    catch problem
        failures(end+1) = log_failure(k,'','circuit',problem);
    end

    period = 1/frequency(k);
    h = period/stepsPerPeriod(k);
    stop = (startupCycles(k) + logCycles(k))*period;
    try
        assert(~bdIsLoaded(mdl), 'Close the open model %s before running pe_run.', mdl);
        new_system(mdl);
        modelCleanup = onCleanup(@() close_model(mdl));
        set_point(mdl,selected(1),h);
        if native
            builders = {@pe_sps_rect,@pe_sps_inv,@pe_sps_dc};
            build = builders{ceil(k/2)};
            build(mdl,k);
        else
            pe_model(mdl,k);
        end
        set_point(mdl,selected(1),h);
        set_param(mdl, 'SolverType','Fixed-step','Solver','FixedStepDiscrete',...
            'FixedStep',num2str(h,17),'StopTime',num2str(stop,17),...
            'ReturnWorkspaceOutputs','on','SaveTime','off','SaveOutput','on',...
            'SaveFormat','StructureWithTime','OutputSaveName','yout');
        save_system(mdl, fullfile(outDir,'models',[mdl '.slx']));
    catch problem
        failures(end+1) = log_failure(k,'','build_model',problem);
        clear modelCleanup
        continue
    end
    try
        export_block_diagram(mdl,fullfile(outDir,'diagrams',[base '_simulink.png']));
    catch problem
        failures(end+1) = log_failure(k,'','model_image',problem);
    end

    for q = 1:numel(selected)
        c = selected(q);
        fprintf('Starting sim(%s), case %s\n', mdl,c.id);
        timer = tic;
        try
            set_point(mdl,c,h);
            simOut = sim(mdl);
            elapsed = toc(timer);
            [t, signals] = select_window(simOut.get('yout'),stop,h, ...
                stepsPerPeriod(k)*logCycles(k));
            dataPath = fullfile('data',[c.id '.csv']);
            wavePath = fullfile('waveforms',[c.id '.png']);
            recorded = array2table([t,signals], 'VariableNames', ...
                {'t_s','channel_1','output_V','current_A','auxiliary'});
            writetable(recorded,fullfile(outDir,dataPath));
            fullTrace = simOut.get('yout'); %#ok<NASGU>
            save(fullfile(outDir,'data',[c.id '.mat']),'fullTrace','c','h','stop','-v7');
            readings = measure(c,signals,elapsed,h,period,names{k}, ...
                channelNames{k},dataPath,wavePath,stop);
            readings.reference_check = check_representative(c,readings);
            rows{end+1,1} = readings; %#ok<AGROW>
            fprintf('Completed %s in %.3f s, %d retained samples, Vavg=%+.6f V\n', ...
                c.id,elapsed,numel(t),readings.output_mean_V);
        catch problem
            failures(end+1) = log_failure(k,c.id,'sim_or_export',problem); %#ok<AGROW>
            continue
        end
        try
            plot_trace(fullfile(outDir,wavePath),t,signals,channelNames{k}, ...
                titles{k},c,k);
        catch problem
            failures(end+1) = log_failure(k,c.id,'waveform_image',problem); %#ok<AGROW>
        end
    end
    close_system(mdl,0);
    clear modelCleanup
end

summary = vertcat(rows{:});
if ~isempty(summary)
    tableOutput = rmfield(summary,'channel_labels');
    writetable(struct2table(tableOutput),fullfile(outDir,'summary.csv'));
end
result = struct('run_id',tag,'mode',mode,'cases_requested',numel(conditions), ...
    'cases_logged',numel(summary),'results',summary,'failures',failures);
write_json(fullfile(outDir,'manifest.json'),result);
fprintf('Logged %d/%d operating points. Recorded %d errors.\n', ...
    numel(summary),numel(conditions),numel(failures));
clear logCleanup

parts = [parts,{'environment.json','manifest.json','run_log.txt'}];
if ~isempty(summary)
    parts{end+1} = 'summary.csv';
end
archive = fullfile(pwd,[tag '.zip']);
zip(archive,parts,outDir);
latest = fullfile(pwd,[prefix '_results.zip']);
if native
    latest = fullfile(pwd,'pe_physical_results.zip');
end
copyfile(archive,latest,'f');
fprintf('Download %s (run archive: %s).\n',latest,archive);
if ~isempty(failures)
    error('pe_run:PartialRun', ...
        '%d run or export errors. See manifest.json and run_log.txt in %s.', ...
        numel(failures),latest);
end
end

function conditions = operating_points(mode)
conditions = [ ...
    point(1,'01_rl_a60',60,2,0.5), ...
    point(2,'02_rl_a90',90,2,0.5), ...
    point(3,'03_rl',0,1,0.5), ...
    point(4,'04_rc',0,1,0.5), ...
    point(5,'05_d50',0,1,0.5), ...
    point(6,'06_d50',0,1,0.5)];
if strcmp(mode,'full')
    extra = conditions([]);
    for a = [0,30,60,90,120]
        for load = 1:3
            if a == 60 && load == 2
                continue
            end
            labels = {'r','rl','rl_freewheel'};
            extra(end+1) = point(1,sprintf('01_%s_a%02d',labels{load},a),a,load,0.5); %#ok<AGROW>
        end
    end
    for a = [0,30,60,90]
        for load = 1:2
            if a == 90 && load == 2
                continue
            end
            labels = {'r','rl'};
            extra(end+1) = point(2,sprintf('02_%s_a%02d',labels{load},a),a,load,0.5); %#ok<AGROW>
        end
    end
    for k = 5:6
        for duty = [0.30 0.70]
            extra(end+1) = point(k,sprintf('%02d_d%02d',k,round(100*duty)),0,1,duty); %#ok<AGROW>
        end
    end
    conditions = [conditions,extra];
end
end

function c = point(model,id,alpha,load,duty)
c = struct('model',model,'id',id,'alpha_deg',alpha,'load_mode',load,'duty',duty);
end

function set_point(mdl,c,h)
workspace = get_param(mdl,'ModelWorkspace');
assignin(workspace,'alphaDeg',c.alpha_deg);
assignin(workspace,'loadMode',c.load_mode);
assignin(workspace,'duty',c.duty);
assignin(workspace,'modelStep',h);
end

function [t, signals] = select_window(trace,stop,h,count)
allTime = trace.time(:);
assert(numel(trace.signals)==4, 'Expected four scalar root outputs.');
indices = find(allTime >= stop-count*h-h/4 & allTime < stop-h/4);
assert(numel(indices)==count, 'Expected %d logged samples in steady window, found %d.', ...
    count,numel(indices));
t = allTime(indices)-allTime(indices(1));
assert(all(abs(diff(t)-h) < h/100), 'Logged time is irregular.');
signals = zeros(count,4);
for ch = 1:4
    values = trace.signals(ch).values;
    assert(numel(values)==numel(allTime), 'Root output %d is not scalar.',ch);
    signals(:,ch) = values(indices);
end
assert(all(isfinite(signals),'all'), 'Nonfinite value in the logged outputs.');
end

function row = measure(c,y,elapsed,h,period,name,labels,dataPath,wavePath,stop)
v = y(:,2);
i = y(:,3);
aux = y(:,4);
row = struct('case_id',c.id,'model',name,'alpha_deg',c.alpha_deg, ...
    'load_mode',c.load_mode,'duty',c.duty,'sample_step_s',h, ...
    'period_s',period,'sample_count',numel(v),'stop_time_s',stop, ...
    'output_mean_V',mean(v),'output_rms_V',sqrt(mean(v.^2)), ...
    'output_peak_abs_V',max(abs(v)),'output_pkpk_V',max(v)-min(v), ...
    'current_mean_A',mean(i),'current_rms_A',sqrt(mean(i.^2)), ...
    'current_peak_abs_A',max(abs(i)),'current_min_A',min(i), ...
    'current_max_A',max(i),'aux_mean',mean(aux),'aux_min',min(aux), ...
    'aux_max',max(aux),'sim_wall_s',elapsed,'channel_labels',{labels}, ...
    'csv',strrep(dataPath,filesep,'/'),'waveform',strrep(wavePath,filesep,'/'));
end

function verdict = check_representative(c,row)
% Compare representative cases with basic independent expected readings.
switch c.id
    case '01_rl_a60'
        pass = abs(row.output_mean_V-99.03)<0.8 && row.current_min_A>2;
    case '02_rl_a90'
        pass = abs(row.output_mean_V-13.05)<1.0 && row.current_min_A<0.02;
    case '03_rl'
        pass = abs(row.current_rms_A-3.599)<0.03 && abs(row.output_rms_V-100)<0.01;
    case '04_rc'
        pass = abs(row.output_rms_V-53.329)<0.25;
    case '05_d50'
        pass = abs(row.output_mean_V+24)<0.1 && row.current_min_A>1.95 && ...
            abs(row.output_pkpk_V-0.136)<0.02;
    case '06_d50'
        pass = abs(row.output_mean_V+24)<0.1 && min(row.current_min_A,row.aux_min)>0.8 && ...
            abs(row.output_pkpk_V-0.017)<0.01;
    otherwise
        verdict = 'not_applicable';
        return
end
if pass
    verdict = 'passed';
else
    verdict = 'outside_expected_range';
    fprintf(2,'Numerical check outside expected range for %s. Review logged data.\n',c.id);
end
end

function plot_trace(filename,t,data,labels,heading,c,k)
fig = figure('Visible','off','Color','white','Position',[100 100 1040 782]);
figCleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig,4,1,'TileSpacing','compact','Padding','compact');
palette = [0.12 0.32 0.58; 0.73 0.24 0.19; 0.13 0.44 0.35; 0.43 0.26 0.58];
for ch = 1:4
    ax = nexttile(layout);
    plot(ax,1000*t,data(:,ch),'Color',palette(ch,:),'LineWidth',1.15);
    ylabel(ax,labels{ch},'FontSize',9)
    xlim(ax,1000*[t(1) t(end)]);
    ax.Box = 'off';
    ax.FontSize = 10;
    grid(ax,'on');
    if ch < 4
        ax.XTickLabel = [];
    end
end
xlabel(ax,'Time from start of retained steady window (ms)');
detail = c.id;
if k <= 2
    detail = sprintf('%s   |   Firing angle %g deg',c.id,c.alpha_deg);
elseif k >= 5
    detail = sprintf('%s   |   Duty %.0f%%',c.id,100*c.duty);
end
title(layout,{heading,detail},'Interpreter','none','FontSize',14);
print(fig,filename,'-dpng','-r144');
end

function export_block_diagram(mdl,filename)
try
    print(['-s' mdl],'-dpng',filename);
catch
    open_system(mdl);
    print(['-s' mdl],'-dpng',filename);
end
assert(isfile(filename),'Simulink diagram export did not produce a PNG.');
end

function close_model(mdl)
if bdIsLoaded(mdl)
    close_system(mdl,0);
end
end

function failure = log_failure(model,id,stage,problem)
failure = struct('model',model,'case_id',id,'stage',stage, ...
    'message',getReport(problem,'extended','hyperlinks','off'));
fprintf(2,'Model %d [%s] %s\n%s\n',model,id,stage,failure.message);
end

function write_json(filepath,value)
file = fopen(filepath,'wt','n','UTF-8');
assert(file ~= -1, 'Could not open %s for writing.',filepath);
cleanup = onCleanup(@() fclose(file));
fprintf(file,'%s\n',jsonencode(value,'PrettyPrint',true));
end




