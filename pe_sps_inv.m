function pe_sps_inv(mdl,k)
%PE_SPS_INV Native SPS single-phase bridges with diagonal gate commands.
assert(ismember(k,[3,4]),'Inverter experiment must be 3 or 4.');
load_system('powerlib');
add_block('powerlib/powergui',[mdl '/powergui'],'SimulationMode','Discrete', ...
    'SampleTime','modelStep','Position',[48 337 125 377]);
if k==3
    src = sps(mdl,'Electrical Sources/DC Voltage Source','100 V DC bus', ...
        [70 182 120 228],'Amplitude','100');
else
    src = sps(mdl,'Electrical Sources/Controlled Current Source','5 A current link', ...
        [70 182 120 228]);
    command = add_block('simulink/Sources/Constant',[mdl '/Current set point'], ...
        'Value','5','SampleTime','modelStep','Position',[15 190 49 220]);
    signal(mdl,command,src);
end
ref = sps(mdl,'Elements/Ground','DC reference',[62 274 92 300]);
gateP = add_block('simulink/Sources/Pulse Generator',[mdl '/Positive diagonal'], ...
    'PulseType','Sample based','Amplitude','1','Period','round(0.02/modelStep)', ...
    'PulseWidth','round(0.01/modelStep)','SampleTime','modelStep','PhaseDelay','0', ...
    'Position',[40 30 92 60]);
gateN = add_block('simulink/Sources/Pulse Generator',[mdl '/Negative diagonal'], ...
    'PulseType','Sample based','Amplitude','1','Period','round(0.02/modelStep)', ...
    'PulseWidth','round(0.01/modelStep)','SampleTime','modelStep', ...
    'PhaseDelay','round(0.01/modelStep)','Position',[126 30 178 60]);

legs = zeros(1,4);
for sc = 1:4
    xy = [225 110; 225 250; 373 110; 373 250];
    legs(sc) = sps(mdl,'Power Electronics/Ideal Switch',sprintf('S%d',sc), ...
        [xy(sc,:) xy(sc,:)+[54 38]],'Ron','0.001','Rs','1e5','Cs','inf');
end

signal(mdl,gateP,legs(1));
signal(mdl,gateN,legs(2));
signal(mdl,gateN,legs(3));
signal(mdl,gateP,legs(4));

% Put the DC feed terminal on the upper rail for both source blocks.
sa = fliplr(pin(src));
sw1 = pin(legs(1)); sw2 = pin(legs(2)); sw3 = pin(legs(3)); sw4 = pin(legs(4));
node(mdl,[sa(1) sw1(1) sw3(1)]);
node(mdl,[sa(2) pin(ref) sw2(2) sw4(2)]);

iLoad = sps(mdl,'Measurements/Current Measurement','Load branch current', ...
    [470 147 514 177]);
vLoad = sps(mdl,'Measurements/Voltage Measurement','Load terminal voltage', ...
    [465 245 515 282]);
if k==3
    load = sps(mdl,'Elements/Series RLC Branch','20 ohm 50 mH load', ...
        [550 145 660 178],'BranchType','RL','Resistance','20','Inductance','0.05');
else
    load = sps(mdl,'Elements/Series RLC Branch','20 ohm load', ...
        [550 145 660 178],'BranchType','R','Resistance','20');
    cap = sps(mdl,'Elements/Series RLC Branch','220 uF shunt', ...
        [550 219 660 252],'BranchType','C','Capacitance','220e-6');
    iCap = sps(mdl,'Measurements/Current Measurement','Capacitor branch current', ...
        [641 252 690 285]);
end
lp = pin(load); im = pin(iLoad); vm = pin(vLoad);
if k==3
    node(mdl,[sw1(2) sw2(1) im(1) vm(1)]);
    node(mdl,[sw3(2) sw4(1) lp(2) vm(2)]);
    labels = {'Gate_A','Load_V','Load_A','Gate_B'};
    outputs = [gateP vLoad iLoad gateN];
else
    cp = pin(cap); ic = pin(iCap);
    node(mdl,[sw1(2) sw2(1) im(1) vm(1) ic(1)]);
    node(mdl,[sw3(2) sw4(1) lp(2) vm(2) cp(2)]);
    node(mdl,[ic(2) cp(1)]);
    bridge = add_block('simulink/Math Operations/Sum',[mdl '/Total injected current'], ...
        'Inputs','++','Position',[695 77 718 102]);
    connect_in(mdl,iLoad,bridge,1);
    connect_in(mdl,iCap,bridge,2);
    labels = {'Bridge_A','Load_V','Resistor_A','Capacitor_A'};
    outputs = [bridge vLoad iLoad iCap];
end
node(mdl,[im(2) lp(1)]);
for p = 1:4
    y = 55+68*p;
    terminal = add_block('built-in/Outport',[mdl '/' labels{p}], ...
        'Port',num2str(p),'Position',[789 y 821 y+15]);
    signal(mdl,outputs(p),terminal);
end
if k==3
    note = '100 V DC | 50 Hz | series RL | synchronous ideal switches allow reverse load current';
else
    note = '5 A DC link | 50 Hz | parallel RC | ideal synchronous diagonal commutation';
end
ann = Simulink.Annotation(mdl,note);
ann.Position = [205 357];
end

function h = sps(mdl,lib,name,position,varargin)
destination = [mdl '/' name];
try
    h = add_block(['powerlib/' lib],destination,'Position',position,varargin{:});
catch firstError
    components = strsplit(lib,'/');
    blockName = components{end};
    matches = find_system('powerlib','LookUnderMasks','all','FollowLinks','on', ...
        'Type','Block','Name',blockName);
    if isempty(matches)
        rethrow(firstError);
    end
    h = add_block(matches{1},destination,'Position',position,varargin{:});
end
end

function p = pin(block)
ports = get_param(block,'PortHandles');
p = [reshape(ports.LConn,1,[]) reshape(ports.RConn,1,[])];
end

function node(mdl,p)
for i = 2:numel(p)
    add_line(mdl,p(1),p(i),'autorouting','on');
end
end

function signal(mdl,source,destination)
connect_in(mdl,source,destination,1);
end

function connect_in(mdl,source,dest,index)
p = get_param(source,'PortHandles');
q = get_param(dest,'PortHandles');
add_line(mdl,p.Outport(1),q.Inport(index),'autorouting','on');
end




