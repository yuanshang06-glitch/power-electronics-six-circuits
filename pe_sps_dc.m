function pe_sps_dc(mdl,k)
% Build two native Specialized Power Systems inverting DC converters.
assert(ismember(k,[5 6]),'pe_sps_dc builds circuits 5 and 6.');
load_system('powerlib');
set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep','modelStep','StopTime','0.04');
add_block('powerlib/powergui',[mdl '/powergui'],'SimulationMode','Discrete', ...
    'SampleTime','modelStep','Position',[35 30 115 67]);
gate = add_block('simulink/Sources/Pulse Generator',[mdl '/PWM 20 kHz'], ...
    'PulseType','Sample based','Amplitude','1','Period','round(1/(20e3*modelStep))', ...
    'PulseWidth','round(duty/(20e3*modelStep))','PhaseDelay','0', ...
    'SampleTime','modelStep','Position',[165 50 225 80]);
src = device('Electrical Sources','DC Voltage Source','24 V DC',[45 175 85 230], ...
    'Amplitude','24');
vout = device('Measurements','Voltage Measurement','Output voltage',[805 235 840 275]);
ground = device('Elements','Ground','Circuit reference',[405 405 425 425]);
loadR = branch('20 ohm','R','Resistance','20',[715 255 768 280],'down');
cap = branch('Output capacitor 220 uF','C','Capacitance','220e-6',[625 255 680 280],'down');
if k == 5
    sw = device('Power Electronics','Ideal Switch','S',[190 154 245 187], ...
        'Ron','1e-3','Rs','1e5','Cs','inf');
    rd = device('Power Electronics','Diode','D',[485 154 535 195], ...
        'Ron','1e-3','Lon','0','Vf','0','Rs','1e5','Cs','inf','Orientation','left');
    l1 = branch('L 1 mH','L','Inductance','1e-3',[350 256 402 281],'down');
    i1 = device('Measurements','Current Measurement','Inductor current',[353 210 395 245], ...
        'Orientation','down');
    i2 = device('Measurements','Current Measurement','Diode current',[580 155 609 183], ...
        'Orientation','left');
    sn = pins(sw); dn = pins(rd); ln = pins(l1);
    im = pins(i1); dm = pins(i2);
    vin = pins(src);
    tie([vin(2),sn(1)]);
    tie([sn(2),dn(2),im(1)]);
    tie([im(2),ln(1)]);
    tie([dn(1),dm(2)]);
    referencePort = ln(2);
    outputPort = dm(1);
    threshold = add_block('simulink/Logic and Bit Operations/Compare To Constant', ...
        [mdl '/Forward current test'],'const','0.001','relop','>', ...
        'Position',[645 96 715 123]);
    add_line(mdl,signal(i2,'Outport'),signal(threshold,'Inport'),'autorouting','on');
    auxiliary = signal(threshold,'Outport');
    names = {'Gate','Output_V','Inductor_A','Diode_on'};
    desc = 'Inverting buck-boost | 24 V | 20 kHz | L = 1 mH | C = 220 uF | R = 20 ohm';
else
    sw = device('Power Electronics','Ideal Switch','S',[310 242 360 270], ...
        'Ron','1e-3','Rs','1e5','Cs','inf','Orientation','down');
    rd = device('Power Electronics','Diode','D',[501 242 545 279], ...
        'Ron','1e-3','Lon','0','Vf','0','Rs','1e5','Cs','inf','Orientation','down');
    l1 = branch('L1 1 mH','L','Inductance','1e-3',[229 155 280 185],'right');
    l2 = branch('L2 1 mH','L','Inductance','1e-3',[553 155 611 185],'right');
    ct = branch('Transfer capacitor 100 uF','C','Capacitance','100e-6',[397 155 455 183],'right');
    i1 = device('Measurements','Current Measurement','Input inductor current',[145 155 183 183]);
    i2 = device('Measurements','Current Measurement','Output inductor current',[655 155 693 183], ...
        'Orientation','left');
    sn = pins(sw); dn = pins(rd); ln = pins(l1); lo = pins(l2);
    ci = pins(ct); im = pins(i1); om = pins(i2);
    vin = pins(src);
    tie([vin(2),im(1)]);
    tie([im(2),ln(1)]);
    tie([ln(2),sn(1),ci(1)]);
    tie([ci(2),dn(1),lo(1)]);
    tie([lo(2),om(2)]);
    tie([sn(2),dn(2)]);
    referencePort = sn(2);
    outputPort = om(1);
    auxiliary = signal(i2,'Outport');
    names = {'Gate','Output_V','Input_inductor_A','Output_inductor_A'};
    desc = 'Inverting Cuk | 24 V | 20 kHz | L1 = L2 = 1 mH | C1 = 100 uF | C2 = 220 uF | R = 20 ohm';
end
vp = pins(vout); rp = pins(loadR); cp = pins(cap); gp = pins(ground);
tie([outputPort,rp(1),cp(1),vp(1)]);
tie([referencePort,vin(1),rp(2),cp(2),vp(2),gp(1)]);
gateOut = signal(gate,'Outport');
add_line(mdl,gateOut,signal(sw,'Inport'),'autorouting','on');
outputs = [gateOut,signal(vout,'Outport'),signal(i1,'Outport'),auxiliary];
for j = 1:numel(outputs)
    y = 58+63*(j-1);
    out = add_block('built-in/Outport',[mdl '/' names{j}], ...
        'Port',num2str(j),'Position',[946 y 981 y+14]);
    h = add_line(mdl,outputs(j),signal(out,'Inport'),'autorouting','on');
    set_param(h,'Name',names{j});
end
note = Simulink.Annotation(mdl,desc);
note.Position = [42 485];

    function h = device(group,block,name,pos,varargin)
        try
            h = add_block(['powerlib/' group '/' block],[mdl '/' name], ...
                'Position',pos,varargin{:});
        catch firstError
            % Resolve reorganized library paths by exact block name.
            matches = find_system('powerlib','LookUnderMasks','all', ...
                'FollowLinks','on','Type','Block','Name',block);
            if isempty(matches)
                rethrow(firstError);
            end
            h = add_block(matches{1},[mdl '/' name],'Position',pos,varargin{:});
        end
    end

    function h = branch(name,type,param,value,pos,orientation)
        h = device('Elements','Series RLC Branch',name,pos,'BranchType',type, ...
            param,value,'Orientation',orientation);
    end

    function p = pins(h)
        all = get_param(h,'PortHandles');
        p = [all.LConn(:);all.RConn(:)].';
    end

    function p = signal(h,kind)
        all = get_param(h,'PortHandles');
        p = all.(kind);
        p = p(1);
    end

    function tie(p)
        % Anchor at the port used as the source of the first conserving line.
        % If this port belongs to an existing net, add_line can branch at it.
        for index = 2:numel(p)
            try
                add_line(mdl,p(1),p(index),'autorouting','on');
            catch firstError
                try
                    Simulink.connectBlocks(p(1),p(index));
                catch
                    rethrow(firstError);
                end
            end
        end
    end
end
