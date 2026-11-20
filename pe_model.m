function pe_model(mdl,k)
% Build the executable circuit model inside an existing Simulink diagram.
names = {
    'Source_V','Load_V','Load_A','Conducting_pair'
    'Phase_A_V','Load_V','Load_A','Conducting_pair'
    'Bridge_V','Load_V','Load_A','Bridge_sign'
    'Bridge_A','Load_V','Resistor_A','Capacitor_A'
    'Gate','Output_V','Inductor_A','Diode_on'
    'Gate','Output_V','Input_inductor_A','Output_inductor_A'
    };
circuit = {'Single-phase controlled rectifier','Three-phase controlled rectifier', ...
    'Voltage-source inverter','Current-source inverter','Inverting buck-boost','Inverting Cuk'};
description = {
    '220 Vrms, 60 Hz | R = 20 ohm | L = 200 mH | loadMode 1 R, 2 RL, 3 RL with freewheel | state 3 = freewheel'
    '220 Vrms phase voltage, 50 Hz | R = 1 ohm | L = 10 mH | loadMode 1 R, 2 RL | pair order AB, AC, BC, BA, CA, CB'
    '100 V DC bus, 50 Hz | R = 20 ohm | L = 50 mH | bridge sign alternates each half-cycle'
    '5 A DC source, 50 Hz | R = 20 ohm in parallel with C = 220 uF'
    '24 V input, 20 kHz | R = 20 ohm | L = 1 mH | C = 220 uF | negative output'
    '24 V input, 20 kHz | R = 20 ohm | L1 = L2 = 1 mH | C1 = 100 uF, C2 = 220 uF | negative output'
    };

sampleTime = 'modelStep';
stopTime = 0.2;
if k >= 5

    stopTime = 0.04;
end

set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep',sampleTime,'StopTime',sprintf('%.15g',stopTime));

clock = [mdl '/Sample time'];
network = [mdl '/' circuit{k}];
add_block('simulink/Sources/Digital Clock',clock,'SampleTime',sampleTime, ...
    'Position',[55 140 115 176]);
add_block('built-in/Subsystem',network,'Position',[188 61 405 256]);
add_block('built-in/Inport',[network '/Time_s'],'Position',[35 98 65 112]);
solver = [network '/Switching and energy storage'];
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',solver, ...
    'FunctionName','pe_switching','Parameters', ...
    sprintf('%d, alphaDeg, loadMode, duty, %s',k,sampleTime), ...
    'Position',[133 61 350 181]);
add_line(network,'Time_s/1','Switching and energy storage/1','autorouting','on');
add_line(mdl,'Sample time/1',[circuit{k} '/1'],'autorouting','on');

ports = get_param(solver,'PortHandles');
if numel(ports.Outport) ~= 4
    set_param(mdl,'SimulationCommand','update');
end

for p = 1:4
    name = names{k,p};
    note = sprintf('/%s',name);
    y = 75+50*p;
    add_block('built-in/Outport',[network note],'Port',num2str(p), ...
        'Position',[445 y-31 475 y-17]);
    add_block('built-in/Outport',[mdl note],'Port',num2str(p), ...
        'Position',[523 y-51 553 y-37]);
    add_line(network,sprintf('Switching and energy storage/%d',p),[name '/1'],'autorouting','on');
    line = add_line(mdl,sprintf('%s/%d',circuit{k},p),[name '/1'],'autorouting','on');
    set_param(line,'Name',name)
end

annotation = Simulink.Annotation(mdl,description{k});
annotation.Position = [55 300];
sourceNote = Simulink.Annotation(network, ...
    'pe_switching.m defines the ideal switch paths and integrates the inductor and capacitor states.');
sourceNote.Position = [37 270];
end
