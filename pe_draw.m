function fig = pe_draw(k, fullPng)
%PE_DRAW Draw one of the six power electronics circuits.
%   PE_DRAW(K, FILENAME) also exports the schematic as a PNG.
if nargin < 2
    fullPng = '';
end
validateattributes(k, {'numeric'}, {'scalar','integer','>=',1,'<=',6});
names = {'Single-phase fully controlled rectifier', ...
         'Three-phase fully controlled rectifier', ...
         'Single-phase voltage-source inverter', ...
         'Single-phase current-source inverter', ...
         'Inverting buck-boost converter', ...
         'Inverting Cuk converter'};
fig = figure('Color','w','Position',[80 80 1180 680], 'PaperPositionMode','auto');
ax = axes('Parent',fig,'Position',[.035 .075 .93 .83]);
hold(ax,'on');
axis(ax,'equal');
axis(ax,'off');
xlim(ax,[-0.8 13.4]);
ylim(ax,[-0.8 9.0]);
annotation(fig,'textbox',[.055 .91 .9 .07],'String',names{k}, ...
    'Interpreter','none','EdgeColor','none','Color',[.08 .13 .22], ...
    'FontName','Arial','FontSize',20,'FontWeight','bold');

switch k
    case {1,2}
        drawRectifier(k+1);
    case {3,4}
        drawInverter(k==4);
    case 5
        drawBuckBoost();
    case 6
        drawCuk();
end
if ~isempty(fullPng)
    drawnow;
    print(fig,char(fullPng),'-dpng','-r145');
end

    function drawRectifier(n)
        legs = [3.4 5.4 7.4];
        phaseY = [3.25 4.4 5.55];
        top = 7.85;
        bottom = 1.05;
        xLoad = 9.8;
        for i = 1:n
            x = legs(i);
            y = phaseY(i);
            yUpper = 6.75;
            yLower = 1.95;
            scr(x,yUpper,['T' num2str(2*i-1)]);
            scr(x,yLower,['T' num2str(2*i)]);
            wire([x x],[top yUpper+.5]);
            wire([x x],[yUpper-.5 yLower+.5]);
            wire([x x],[yLower-.5 bottom]);
            dot(x,y);
            if i > 1
                dot(x,top);
                dot(x,bottom);
            end
        end
        wire([legs(1) xLoad],[top top]);
        wire([legs(1) xLoad],[bottom bottom]);
        seriesRL([xLoad top],[xLoad bottom],false);
        label(xLoad+.42,top+.02,'DC+');
        label(xLoad+.42,bottom+.02,'DC-');
        if n == 2
            wire([legs(1) .62 .62],[phaseY(1) phaseY(1) 3.36]);
            wire([.62 .62 legs(2)],[4.29 phaseY(2) phaseY(2)]);
            source([.62 3.825],'ac');
            label(.17,5.3,'220 V rms, 60 Hz');
            xFree = 12.0;
            branchColor = [.25 .33 .42];
            line(ax,[xLoad xFree xFree],[top top 4.97], ...
                'Color',branchColor,'LineStyle','--','LineWidth',1.25);
            line(ax,[xFree xFree xLoad],[3.93 bottom bottom], ...
                'Color',branchColor,'LineStyle','--','LineWidth',1.25);
            diode([xFree 3.93],[xFree 4.97]);
            dot(xLoad,top);
            dot(xLoad,bottom);
            label(xFree+.42,4.55,'Df');
            label(10.95,0.35,'Dashed branch: optional');
            label(7.95,.35,'R = 20 ohm, L = 0.20 H');
        else
            for i = 1:n
                y = phaseY(i);
                wire([.08 .64],[y y]);
                part([.64 y],[1.57 y],'ac','');
                wire([1.57 legs(i)],[y y]);
                label(1.82,y+.25,['Phase ' char('A'+i-1)]);
                dot(.08,y);
            end
            wire([.08 .08],[phaseY(1) phaseY(n)]);
            label(-.34,4.38,'N');
            label(.10,6.3,'220 V rms per phase, 50 Hz');
            label(7.9,.35,'R = 1 ohm, L = 10 mH');
        end
    end

    function drawInverter(isCurrent)
        top = 7.8;
        mid = 4.45;
        bottom = 1.1;
        xLeft = 3.1;
        xRight = 10.7;
        xSupply = .32;
        wire([xSupply xRight],[top top]);
        wire([xSupply xRight],[bottom bottom]);
        for i = 1:2
            x = [xLeft xRight];
            x = x(i);
            for j = 1:2
                limits = [top mid; mid bottom];
                yHi = limits(j,1);
                yLo = limits(j,2);
                m = (yHi+yLo)/2;
                name = ['S' num2str(2*i+j-2)];
                if isCurrent
                    wire([x x],[yHi m+.97]);
                    part([x m+.97],[x m+.03],'switch',name);
                    wire([x x],[m+.03 m-.06]);
                    diode([x m-.06],[x m-1.09]);
                    wire([x x],[m-1.09 yLo]);
                    label(x+.45,m-.56,['D' num2str(2*i+j-2)]);
                else
                    u = m+.97;
                    l = m-.97;
                    xd = x-1.14;
                    wire([x x],[yHi m+.56]);
                    part([x m+.56],[x m-.56],'switch',name);
                    wire([x x],[m-.56 yLo]);
                    wire([x xd xd],[u u m+.52]);
                    wire([xd xd x],[m-.52 l l]);
                    diode([xd m-.52],[xd m+.52]);
                    dot(x,u);
                    dot(x,l);
                    label(xd+.26,m,['D' num2str(2*i+j-2)]);
                end
            end
            dot(x,mid);
        end
        wire([xSupply xSupply],[top mid+.465]);
        wire([xSupply xSupply],[mid-.465 bottom]);
        if isCurrent
            source([xSupply mid],'current');
            label(-.02,mid+.83,'5 A');
            xA = xLeft+1.0;
            xB = xRight-1.66;
            yR = mid+.7;
            yC = mid-.7;
            wire([xLeft xA],[mid mid]);
            wire([xB xRight],[mid mid]);
            wire([xA xA xA+1.0],[yC yR yR]);
            wire([xA xA+1.0],[yC yC]);
            wire([xB xB xB-.42],[yC yR yR]);
            wire([xB xB-.42],[yC yC]);
            part([xA+1.0 yR],[xB-.42 yR],'R','R');
            part([xA+1.0 yC],[xB-.42 yC],'C','C');
            dot(xA,mid);
            dot(xB,mid);
            label(4.0,.35,'R = 20 ohm, C = 220 uF, f = 50 Hz');
        else
            source([xSupply mid],'voltage');
            label(-.19,mid+.83,'100 V');
            seriesRL([xLeft mid],[xRight mid],true);
            label(4.0,.35,'R = 20 ohm, L = 50 mH, f = 50 Hz');
        end
        label(xLeft+.13,mid+.25,'a');
        label(xRight-.43,mid+.25,'b');
        dot(xLeft,top);
        dot(xLeft,bottom);
    end

    function drawBuckBoost()
        y = 6.65;
        g = 2.1;
        xIn = .9;
        xSw = 5.45;
        xC = 9.0;
        xR = 11.55;
        drawInput(xIn,y,g);
        wire([xIn 2.4],[y y]);
        part([2.4 y],[3.9 y],'switch','S');
        wire([3.9 xSw 6.5],[y y y]);
        diode([7.7 y],[6.5 y]);
        label(7.02,y+.43,'D');
        wire([7.7 xR],[y y]);
        drawVertical(xSw,y,g,'L','L');
        outputNetwork(xC,xR,y,g,'C');
        wire([xIn xR],[g g]);
        dot(xSw,y);
        dot(xSw,g);
        label(.9,.7,'Vin = 24 V, fs = 20 kHz, L = 1 mH, C = 220 uF, R = 20 ohm');
    end

    function drawCuk()
        y = 6.65;
        g = 2.1;
        xIn = .9;
        xA = 4.2;
        xB = 7.25;
        xC = 10.35;
        xR = 12.2;
        drawInput(xIn,y,g);
        wire([xIn 1.75],[y y]);
        part([1.75 y],[3.45 y],'L','L1');
        wire([3.45 5.04],[y y]);
        part([5.04 y],[6.4 y],'C','C1');
        wire([6.4 7.7],[y y]);
        part([7.7 y],[9.55 y],'L','L2');
        wire([9.55 xR],[y y]);
        drawVertical(xA,y,g,'switch','S');
        m = (y+g)/2;
        wire([xB xB],[y m+.56]);
        diode([xB m+.56],[xB m-.56]);
        wire([xB xB],[m-.56 g]);
        label(xB+.45,m,'D');
        outputNetwork(xC,xR,y,g,'C2');
        wire([xIn xR],[g g]);
        for x = [xA xB]
            dot(x,y);
            dot(x,g);
        end
        label(9.22,7.5,'iL2');
        arrow([9.18 7.45],[8.43 7.45]);
        label(.9,.7,'Vin = 24 V, fs = 20 kHz, L1 = L2 = 1 mH, C1 = 100 uF, C2 = 220 uF, R = 20 ohm');
    end

    function drawInput(x,top,bottom)
        m = (top+bottom)/2;
        wire([x x],[top m+.465]);
        wire([x x],[m-.465 bottom]);
        source([x m],'voltage');
        label(x+.65,m,'Vin');
    end

    function outputNetwork(xC,xR,top,bottom,cap)
        drawVertical(xC,top,bottom,'C',cap);
        drawVertical(xR,top,bottom,'R','R');
        dot(xC,top);
        dot(xC,bottom);
        dot(xR,top);
        dot(xR,bottom);
        label(xR-.46,top+.48,'Vout (-)');
        label(xR-.45,bottom-.4,'0 V');
    end

    function drawVertical(x,yTop,yBottom,type,name)
        m = (yTop+yBottom)/2;
        wire([x x],[yTop m+.84]);
        part([x m+.84],[x m-.84],type,name);
        wire([x x],[m-.84 yBottom]);
    end

    function seriesRL(a,b,horizontal)
        d = b-a;
        if horizontal
            f = [.20 .43 .53 .77];
        else
            f = [.20 .39 .56 .75];
        end
        p = a+f(1)*d; q = a+f(2)*d;
        r = a+f(3)*d; s = a+f(4)*d;
        connect(a,p);
        part(p,q,'R','R');
        connect(q,r);
        part(r,s,'L','L');
        connect(s,b);
    end

    function scr(x,y,name)
        a = [x y-.5];
        b = [x y+.5];
        diode(a,b);
        wire([x x+.26 x+.51],[y+.09 y-.09 y-.09]);
        wire([x+.51 x+.58],[y-.09 y-.09]);
        label(x+.61,y+.19,name);
    end

    function diode(a,b)
        % A is the anode terminal and B is the cathode terminal.
        c = (a+b)/2;
        u = (b-a)/norm(b-a);
        v = [-u(2) u(1)];
        base = c-.22*u;
        bar = c+.19*u;
        connect(a,base);
        poly([base+.24*v; base-.24*v; bar],'w');
        connect(bar-.27*v,bar+.27*v);
        connect(bar,b);
    end

    function part(a,b,type,name)
        c = (a+b)/2;
        u = (b-a)/norm(b-a);
        v = [-u(2) u(1)];
        switch type
            case 'R'
                len = min(.66,norm(b-a)*.78);
                p = c-.5*len*u;
                q = c+.5*len*u;
                connect(a,p);
                poly([p+.15*v; q+.15*v; q-.15*v; p-.15*v],'w');
                connect(q,b);
            case 'L'
                len = min(.91,norm(b-a)*.82);
                p = c-.5*len*u;
                q = c+.5*len*u;
                connect(a,p);
                t = linspace(0,1,101)';
                wave = p + (t*len)*u + (.15*abs(sin(4*pi*t)))*v;
                wire(wave(:,1),wave(:,2));
                connect(q,b);
            case 'C'
                p = c-.075*u;
                q = c+.075*u;
                connect(a,p);
                connect(p-.29*v,p+.29*v);
                connect(q-.29*v,q+.29*v);
                connect(q,b);
            case 'switch'
                p = c-.32*u;
                q = c+.32*u;
                connect(a,p);
                connect(q,b);
                connect(p,q+.25*v);
                plot(ax,[p(1) q(1)],[p(2) q(2)],'o', ...
                    'LineStyle','none','MarkerSize',3,'MarkerFaceColor','w', ...
                    'MarkerEdgeColor',[.08 .13 .22],'LineWidth',1.1);
            case 'ac'
                source(c,'ac');
        end
        if ~isempty(name)
            if abs(u(1)) > .5
                label(c(1)-.1,c(2)+.39,name);
            else
                label(c(1)+.44,c(2),name);
            end
        end
    end

    function source(c,mode)
        t = linspace(0,2*pi,101);
        wire(c(1)+.465*cos(t),c(2)+.465*sin(t));
        switch mode
            case 'ac'
                s = linspace(-pi,pi,61);
                wire(c(1)+.29*s/pi,c(2)+.13*sin(s));
            case 'current'
                arrow(c+[0 -.26],c+[0 .27]);
            case 'voltage'
                wire(c(1)+[-.11 .11],c(2)+[.15 .15]);
                wire(c(1)+[0 0],c(2)+[.04 .26]);
                wire(c(1)+[-.11 .11],c(2)+[-.15 -.15]);
        end
    end

    function arrow(a,b)
        u = (b-a)/norm(b-a);
        v = [-u(2) u(1)];
        connect(a,b);
        poly([b; b-.18*u+.09*v; b-.18*u-.09*v],[.08 .13 .22]);
    end

    function connect(a,b)
        wire([a(1) b(1)],[a(2) b(2)]);
    end

    function wire(x,y)
        line(ax,x,y,'Color',[.08 .13 .22],'LineWidth',1.45);
    end

    function poly(p,color)
        patch(ax,p(:,1),p(:,2),color,'EdgeColor',[.08 .13 .22], ...
            'LineWidth',1.4);
    end

    function dot(x,y)
        plot(ax,x,y,'.','Color',[.08 .13 .22],'MarkerSize',15);
    end

    function label(x,y,str)
        text(ax,x,y,str,'FontName','Arial','FontSize',10.5, ...
            'Interpreter','none','Color',[.08 .13 .22], ...
            'VerticalAlignment','middle');
    end
end

