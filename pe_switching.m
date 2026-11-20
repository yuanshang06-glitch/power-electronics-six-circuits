function pe_switching(block)
% Level-2 MATLAB S-function for six ideal power converter circuits.
setup(block);
end

function setup(block)
block.NumDialogPrms = 5;
block.DialogPrmsTunable = repmat({'Nontunable'},1,5);
block.NumInputPorts = 1;
block.NumOutputPorts = 4;
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;
block.InputPort(1).Dimensions = 1;
block.InputPort(1).DatatypeID = 0;
block.InputPort(1).Complexity = 'Real';
block.InputPort(1).DirectFeedthrough = true;
for p = 1:4
    block.OutputPort(p).Dimensions = 1;
    block.OutputPort(p).DatatypeID = 0;
    block.OutputPort(p).Complexity = 'Real';
end
block.SampleTimes = [block.DialogPrm(5).Data, 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('PostPropagationSetup',@allocateStates);
block.RegBlockMethod('InitializeConditions',@initialize);
block.RegBlockMethod('Outputs',@outputs);
block.RegBlockMethod('Update',@advance);
end

function allocateStates(block)
k = block.DialogPrm(1).Data;
dimensions = [1 1 1 1 2 4];
block.NumDworks = 1;
block.Dwork(1).Name = 'CircuitStates';
block.Dwork(1).Dimensions = dimensions(k);
block.Dwork(1).DatatypeID = 0;
block.Dwork(1).Complexity = 'Real';
block.Dwork(1).UsedAsDiscState = true;
end

function initialize(block)
k = block.DialogPrm(1).Data;
duty = block.DialogPrm(4).Data;
% DC converters start near the averaged CCM operating point and settle
% under the actual switching equations. The AC circuits start at zero.
switch k
    case 5
        w = 24*duty/(1-duty);
        x = [w/(20*(1-duty));w];
    case 6
        w = 24*duty/(1-duty);
        x = [w*duty/(20*(1-duty));w/20;24+w;w];
    otherwise
        block.Dwork(1).Data = 0;
        return
end
% Approximate the beginning of the on-time by centering its ripple.
block.Dwork(1).Data = x-duty/(2*20000)*converterSlope(k,x,true);
end

function outputs(block)
k = block.DialogPrm(1).Data;
time = block.InputPort(1).Data;
x = block.Dwork(1).Data;
switch k
    case {1,2}
        alpha = block.DialogPrm(2).Data*pi/180;
        mode = block.DialogPrm(3).Data;
        [vSource,vLoad,which] = rectifierState(k,time,alpha,mode,x);
        iLoad = x;
        if mode == 1
            resistance = [20,1];
            iLoad = vLoad/resistance(k);
        end
        y = [vSource,vLoad,iLoad,which];
    case 3
        polarity = bridgeSign(time);
        vBridge = 100*polarity;
        y = [vBridge,vBridge,x,polarity];
    case 4
        iBridge = 5*bridgeSign(time);
        iR = x/20;
        y = [iBridge,x,iR,iBridge-iR];
    case 5
        on = pwm(time,block.DialogPrm(4).Data);
        y = [on,-x(2),x(1),~on && x(1)>0];
    case 6
        on = pwm(time,block.DialogPrm(4).Data);
        y = [on,-x(4),x(1),x(2)];
end
for p = 1:4
    block.OutputPort(p).Data = y(p);
end
end

function advance(block)
k = block.DialogPrm(1).Data;
t = block.InputPort(1).Data;
dt = block.DialogPrm(5).Data;
x = block.Dwork(1).Data;
switch k
    case {1,2}
        mode = block.DialogPrm(3).Data;
        if mode ~= 1
            alpha = block.DialogPrm(2).Data*pi/180;
            [~,vLoad] = rectifierState(k,t+dt/2,alpha,mode,x);
            r = [20,1];
            l = [.20,.01];
            x = max(0,firstOrder(x,vLoad/r(k),l(k)/r(k),dt));
        end
    case 3
        vBridge = 100*bridgeSign(t+dt/2);
        x = firstOrder(x,vBridge/20,.050/20,dt);
    case 4
        iBridge = 5*bridgeSign(t+dt/2);
        x = firstOrder(x,20*iBridge,20*220e-6,dt);
    case {5,6}
        x = converterStep(k,x,t,dt,block.DialogPrm(4).Data);
end
block.Dwork(1).Data = x;
end

function [vSource,vLoad,path] = rectifierState(k,time,alpha,mode,current)
% Each firing sector chooses the next eligible SCR pair. An inductive
% load keeps the pair conducting after its voltage reverses until the
% current reaches zero. The optional diode clamps that voltage instead.
frequency = [60,50];
phase = 2*pi*frequency(k)*time;
peak = 220*sqrt(2);
vSource = peak*sin(phase);
if k == 1
    spacing = pi;
    offset = 0;
    base = 0;
    pairCount = 2;
    pairPeak = peak;
else
    spacing = pi/3;
    offset = pi/6;
    base = pi/3;
    pairCount = 6;
    pairPeak = sqrt(3)*peak;
end
triggerPhase = phase-offset-alpha;
sector = floor(triggerPhase/spacing+1e-12);
position = triggerPhase-sector*spacing;
pairVoltage = pairPeak*sin(base+alpha+position);
vLoad = 0;
path = 0;
if sector < 0
    return
end
if k == 1 && mode == 3 && pairVoltage <= 0
    if current > 0
        path = 3;
    end
elseif pairVoltage > 0 || (mode ~= 1 && current > 0)
    vLoad = pairVoltage;
    path = mod(sector,pairCount)+1;
end
end

function y = firstOrder(x,steadyValue,timeConstant,dt)
% Exact update for a constant input held at the sample midpoint.
y = x+(steadyValue-x)*(-expm1(-dt/timeConstant));
end

function signValue = bridgeSign(t)
halfCycle = floor(t*100+1e-10);
signValue = 1-2*mod(halfCycle,2);
end

function on = pwm(t,duty)
position = t*20000-floor(t*20000+1e-10);
on = position < duty-1e-10;
end

function x = converterStep(k,x,t,dt,duty)
% The switch derivative changes at each PWM edge. Split the time step
% at an interior edge and use explicit midpoint on each subinterval.
period = 1/20000;
position = t/period-floor(t/period+1e-10);
on = position < duty-1e-10;
if on
    edge = (duty-position)*period;
else
    edge = (1-position)*period;
end
first = min(dt,edge);
x = midpoint(k,x,on,first);
if dt-first > 1e-15
    x = midpoint(k,x,~on,dt-first);
end
end

function next = midpoint(k,x,on,dt)
slope = converterSlope(k,x,on);
next = x + dt*converterSlope(k,x+dt*slope/2,on);
if k == 5
    next(1) = max(0,next(1));
end
end

function dx = converterSlope(k,x,on)
vin = 24;
l = .001;
r = 20;
c = 220e-6;
if k == 5
    % x = [iL; -vOutput]. With the switch off, the diode conducts
    % only while inductor current is positive.
    iL = x(1);
    w = x(2);
    if on
        dx = [vin/l;-w/(r*c)];
    elseif iL > 0
        dx = [-w/l;(iL-w/r)/c];
    else
        dx = [0;-w/(r*c)];
    end
else
    % x = [iL1; iL2; vTransfer; -vOutput]. iL2 is positive from the
    % negative output node toward the right plate of the transfer capacitor.
    % The supplied duty ratios and load operate in CCM.
    cTransfer = 100e-6;
    i1 = x(1);
    i2 = x(2);
    vTransfer = x(3);
    w = x(4);
    if on
        dx = [vin/l;(vTransfer-w)/l;-i2/cTransfer;(i2-w/r)/c];
    else
        dx = [(vin-vTransfer)/l;-w/l;i1/cTransfer;(i2-w/r)/c];
    end
end
end
