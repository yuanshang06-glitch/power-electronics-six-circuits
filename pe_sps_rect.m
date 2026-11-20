function pe_sps_rect(mdl,k)
% Connected R2024b Specialized Power Systems thyristor converter.
assert(ismember(k,[1,2]),'This builder supports experiments 1 and 2.');
load_system('powerlib');
try
    load_system('sps_lib');
catch
    % Older releases expose the blocks through powerlib.
end

f = [60,50];
r = [20,1];
l = [.20,.01];
sourceCount = [1,3];
arms = [2,3];
powergui = electric(mdl,'powergui','powergui',[40 35 145 76]);
maskValue(powergui,{'SimulationMode'}, {'Discrete'});
maskValue(powergui,{'SampleTime','Ts'}, {'modelStep'});
set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep','modelStep','StopTime','0.24');

bridge = electric(mdl,'Universal Bridge','SCR full bridge',[355 152 456 297]);
maskValue(bridge,{'Arms','NumberOfArms'}, {num2str(arms(k))});
maskValue(bridge,{'PowerElectronicDevice','PowerElectronicDevices'}, ...
    {'Thyristors','Thyristor'});
maskValue(bridge,{'Ron'}, {'0.0001'});
maskValue(bridge,{'Lon'}, {'0'});
maskValue(bridge,{'Rs'}, {'1e6'});
maskValue(bridge,{'Cs'}, {'inf'});
bp = get_param(bridge,'PortHandles');
assert(numel(bp.LConn)==arms(k) && numel(bp.RConn)==2 && numel(bp.Inport)==1, ...
    'Unexpected Universal Bridge terminal arrangement.');

sourcePorts = cell(1,sourceCount(k));
ground = electric(mdl,'Ground','AC reference',[81 367 105 397]);
groundPort = terminalPair(ground,1);
for phase = 1:sourceCount(k)
    y = 148+70*(phase-1);
    source = electric(mdl,'AC Voltage Source',['AC source ' char(64+phase)],[146 y 196 y+42]);
    maskValue(source,{'Amplitude'}, {'220*sqrt(2)'});
    maskValue(source,{'Frequency'}, {num2str(f(k))});
    maskValue(source,{'Phase'}, {num2str(-120*(phase-1))});
    sourceDialog = get_param(source,'DialogParameters');
    if isfield(sourceDialog,'SampleTime')
        set_param(source,'SampleTime','modelStep');
    end
    sourcePorts{phase} = terminalPair(source,2);
    wire(mdl,sourcePorts{phase}(2),groundPort);
    wire(mdl,sourcePorts{phase}(1),bp.LConn(phase));
end
if k == 1
    wire(mdl,groundPort,bp.LConn(2));
end

iSensor = electric(mdl,'Current Measurement','Load current',[502 158 540 194]);
vSensor = electric(mdl,'Voltage Measurement','Load voltage',[706 219 744 260]);
srcSensor = electric(mdl,'Voltage Measurement','Source voltage',[224 340 264 381]);
loadBranch = electric(mdl,'Series RLC Branch','Series RL load',[595 155 668 199]);
maskValue(loadBranch,{'BranchType'}, {'RL'});
maskValue(loadBranch,{'Resistance','R'}, {num2str(r(k))});
maskValue(loadBranch,{'Inductance','L'}, {num2str(l(k))});
lp = terminalPair(loadBranch,2);
ip = terminalPair(iSensor,2);
vp = terminalPair(vSensor,2);
sp = terminalPair(srcSensor,2);
wire(mdl,bp.RConn(1),ip(1));
wire(mdl,ip(2),lp(1));
wire(mdl,lp(2),bp.RConn(2));
wire(mdl,lp(1),vp(1));
wire(mdl,lp(2),vp(2));
wire(mdl,sourcePorts{1}(1),sp(1));
wire(mdl,groundPort,sp(2));

controller = [mdl '/SCR firing controller'];
add_block('built-in/Subsystem',controller,'Position',[185 37 305 93]);
mux = [controller '/SCR gating vector'];
gates = 2*arms(k);
add_block('simulink/Signal Routing/Mux',mux,'Inputs',num2str(gates), ...
    'Position',[300 30 305 297]);
firstGate = firingPulses(controller,k,f(k),gates);
add_block('built-in/Outport',[controller '/Gate_vector'],'Port','1','Position',[360 122 390 136]);
add_block('built-in/Outport',[controller '/Gate_1'],'Port','2','Position',[360 320 390 334]);
add_line(controller,'SCR gating vector/1','Gate_vector/1','autorouting','on');
add_line(controller,firstGate,'Gate_1/1','autorouting','on');
add_line(mdl,'SCR firing controller/1','SCR full bridge/1','autorouting','on');

names = {'Source_V','Load_V','Load_A','SCR1_pulse'};
feeds = {'Source voltage/1','Load voltage/1','Load current/1','SCR firing controller/2'};
for port = 1:4
    y = 160+50*(port-1);
    add_block('built-in/Outport',[mdl '/' names{port}],'Port',num2str(port), ...
        'Position',[856 y 887 y+14]);
    line = add_line(mdl,feeds{port},[names{port} '/1'],'autorouting','on');
    set_param(line,'Name',names{port});
end
description = Simulink.Annotation(mdl, ...
    'Specialized Power Systems | measured voltages and current | firing delay = alphaDeg');
description.Position = [350 408];
end

function firstGate = firingPulses(mdl,k,f,gates)
if k == 1
    % Two-arm order A upper, A lower, B upper, B lower.
    offsets = [0 180 180 0];
else
    % Three-arm natural order A upper, C lower, B upper, A lower,
    % C upper, B lower. Every SCR also gets the next pair's pulse.
    offsets = 30+60*(0:5);
end
for j = 1:gates
    label = sprintf('SCR%d firing',j);
    if k == 1
        pulse(mdl,label,offsets(j),f,[34 84+42*j 115 108+42*j]);
    else
        y = 30+42*j;
        first = [label ' primary'];
        second = [label ' retrigger'];
        pulse(mdl,first,offsets(j),f,[30 y-16 116 y]);
        pulse(mdl,second,offsets(j)+60,f,[129 y-16 215 y]);
        add_block('simulink/Math Operations/Sum',[mdl '/' label], ...
            'Inputs','++','Position',[238 y-18 258 y+8]);
        add_line(mdl,[first '/1'],[label '/1'],'autorouting','on');
        add_line(mdl,[second '/1'],[label '/2'],'autorouting','on');
    end
    add_line(mdl,[label '/1'],sprintf('SCR gating vector/%d',j),'autorouting','on');
end
firstGate = 'SCR1 firing/1';
end

function pulse(mdl,name,angle,f,position)
period = sprintf('round(1/(%g*modelStep))',f);
delay = sprintf('mod(round((alphaDeg+%g)*%s/360),%s)',angle,period,period);
add_block('simulink/Sources/Pulse Generator',[mdl '/' name], ...
    'PulseType','Sample based','Amplitude','1','Period',period, ...
    'PulseWidth',['max(1,round(' period '/36))'],'PhaseDelay',delay, ...
    'SampleTime','modelStep','Position',position);
end

function block = electric(mdl,name,label,position)
roots = {'powerlib','sps_lib'};
categories = {'Power Electronics','Electrical Sources','Sources','Elements', ...
    'Measurements','Sensors and Measurements','Utilities',''};
block = [mdl '/' label];
for root = roots
    for category = categories
        prefix = root{1};
        if ~isempty(category{1})
            prefix = [prefix '/' category{1}];
        end
        reference = [prefix '/' name];
        [found,~] = tryBlock(reference,block,position);
        if found
            return
        end
    end
end
% Some 2024b aliases have dedicated root libraries.
slug = strrep(name,' ','');
if strcmp(name,'powergui')
    slug = 'Powergui';
end
for suffix = {'Lib','Lib1'}
    reference = ['sps' slug suffix{1} '/' name];
    [found,~] = tryBlock(reference,block,position);
    if found
        return
    end
end
for root = roots
    if bdIsLoaded(root{1})
        matches = find_system(root{1},'LookUnderMasks','none','FollowLinks','off', ...
            'SearchDepth',4,'Type','Block','Name',name);
        for j = 1:numel(matches)
            [found,~] = tryBlock(matches{j},block,position);
            if found
                return
            end
        end
    end
end
error('pe_sps_rect:MissingLibraryBlock','Could not locate SPS block %s.',name);
end

function [found,why] = tryBlock(reference,destination,position)
why = '';
try
    add_block(reference,destination,'Position',position);
    found = true;
catch problem
    found = false;
    why = problem.message;
end
end

function maskValue(block,parameters,values)
dialog = get_param(block,'DialogParameters');
for p = parameters
    if isfield(dialog,p{1})
        for value = values
            try
                set_param(block,p{1},value{1});
                return
            catch problem
                failure = problem.message;
            end
        end
        error('pe_sps_rect:MaskValue','%s parameter %s: %s',block,p{1},failure);
    end
end
error('pe_sps_rect:MaskParameter','%s missing %s. Found %s.', ...
    block,strjoin(parameters,', '),strjoin(fieldnames(dialog),', '));
end

function handles = terminalPair(block,count)
ports = get_param(block,'PortHandles');
handles = [ports.LConn(:).',ports.RConn(:).'];
assert(numel(handles)==count,'Unexpected terminal count on %s.',block);
if count == 2
    a = get_param(handles(1),'Position');
    b = get_param(handles(2),'Position');
    [~,axis] = max(abs(a-b));
    if a(axis)>b(axis)
        handles = fliplr(handles);
    end
end
end

function wire(mdl,first,last)
% Conserving wires are bidirectional, including branches.
try
    add_line(mdl,first,last,'autorouting','on');
catch firstProblem
    try
        add_line(mdl,last,first,'autorouting','on');
    catch
        rethrow(firstProblem)
    end
end
end
