%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PHILIPPE SCHUCHERT            %
% SCI-STI-AK, EPFL              %
% philippe.schuchert@epfl.ch    %
% March 2021                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Solve the problem using YALMIP
%

function [controller,sol,diagonstics] = solveddYALMIP(system,objective,constraints,parameters,sol)
persistent options
Ts = system.controller.Ts;
z = tf('z',Ts);
W = system.W(:);


nCon = length(W); % number of constraint
nMod = length(system.model); % number of different models

if isempty(sol)
    % solution struct is not provided: 1st iter
    sol.satisfyConstraints  = 0;
    sol.nIter = 0;
end



%%
% Prepare initial controller
X_c = system.controller.num';
Y_c = system.controller.den'; % rescale numerator

szx = length(X_c); % number of parameters num
szy = length(Y_c); % number of parameters num


% Controller coefficient variables

X_n = sdpvar(szx,1);
Y_n = sdpvar(szy,1);
Y_n(1) = 1;

XY_n = [X_n;Y_n];

if  sol.satisfyConstraints
    % If last solution almost satisfies the constraint, fix them and
    % optimize over the objective
    % M.constraint(slack,Domain.equalsTo(0));
    slack = zeros(3,1);
    sol.slack = 0;
    sol.satisfyConstraints = 1;
    
else
    sol.satisfyConstraints = 0;
    slack = sdpvar(3,1);
end


% H_infinity objectives
obj_inf = sdpvar;
gamma_inf = obj_inf*ones(nCon,1);


% H_2 objectives
gamma_2_local = sdpvar(nCon,nMod);
obj_2 = sdpvar;


OBJ =  obj_inf+ sum(slack) +obj_2;
CON = [slack>=0, gamma_2_local >=0, gamma_inf>=0, obj_2>=0];

z_ = datadriven.utils.resp(z,W);
Zy = z_.^((szy-1):-1:0); % [0,z,...,z^nx]
Zx = z_.^((szx-1):-1:0); % [0,z,...,z^ny]

Fx = datadriven.utils.resp(tf(system.controller.Fx,1,Ts),W); % fixed part X
Fy = datadriven.utils.resp(tf(system.controller.Fy,1,Ts),W); % fixed part Y

Ycs=Zy*(Y_c); Xcs=Zx*(X_c); % Frequency utils.response without the fixed parts
Yc = Ycs.*Fy; Xc = Xcs.*Fx; % Frequency utils.response Kinit with the fixed parts
ZFy = Zy.*Fy; ZFx = Zx.*Fx; % Frequency utils.response K  with the fixed parts

Yf = ZFy*Y_n;
Xf = ZFx*X_n;

if ~isempty(parameters.radius)
    % close the polygonal chain
    
    zstart = conj(z_(1));
    
    zfinish = conj(z_(end));
    
    z2 = [zstart;z_;zfinish];
    
    Zys_= (parameters.radius*z2).^((szy-1):-1:0);
    Ycs_= Zys_*(Y_c);
    
    n = datadriven.utils.getNormalDirection(Ycs_);
    
    polygonalY1 = 2*real(conj(n).*(Zys_(2:end,:)*Y_n));
    polygonalY2 = 2*real(conj(n).*(Zys_(1:end-1,:)*Y_n));
    
    CON = [CON, polygonalY1>=(1e-5)];
    CON = [CON, polygonalY2>=(1e-5)];
end

for mod =  1: nMod
    % For every model, constraint and objectives
    
    G = datadriven.utils.resp(system.model(:,:,mod),W); % Model Frequency utils.response
    Pc = G.*Xc + Yc; % previous "" Open-loop ""
    P  = G.*Xf + Yf; % previous "" Open-loop ""
    PHI = 2*real([G.*ZFx, ZFy].*conj(Pc))*XY_n-abs(Pc).^2; % New convexified part
    
    % OBJECTIVES
    %  only do if controller satisifies constraint
    if  (sol.satisfyConstraints)
        % local 2 norm
        gamma_2   = gamma_2_local(:,mod);
        integ =  Ts/(2*pi)* ([diff(W(:));0] + [2*W(1);diff(W(:))]);
        
        CON = [CON, integ.'*gamma_2 <= obj_2 ];
        
        % H_inf objectives
        % Reminder : rotated cones 2*x1*x2 ? ||x3||^2, ||.||  Euclidean norm
        gam = (0.5*gamma_inf);
        
        W1 = datadriven.utils.resp(objective.oinf.W1,W);
        W4 = datadriven.utils.resp(objective.oinf.W4,W).*G;
        W14 = sqrt(abs(W1).^2+abs(W4).^2);
        if all(W14==0), F_a = [];else, F_a = W14.*Yf;end
        
        W2 = datadriven.utils.resp(objective.oinf.W2,W).*G;
        W3 = datadriven.utils.resp(objective.oinf.W3,W);
        
        W23 = sqrt(abs(W2).^2+abs(W3).^2);
        if all(W23==0), F_b = [];else, F_b = W23.*Xf;end
        
        CON = [CON, datadriven.utils.rcone_serialized(PHI,gam,[F_a,F_b])];
        % END Hinf
        
        % H2
        gam =   0.5*gamma_2 ;
        
        W1 = datadriven.utils.resp(objective.o2.W1,W);
        W4 = datadriven.utils.resp(objective.o2.W4,W).*G;
        W14 = sqrt(abs(W1).^2+abs(W4).^2);
        if all(W14==0), F_a = [];else, F_a = W14.*Yf;end
        
        W2 = datadriven.utils.resp(objective.o2.W2,W).*G;
        W3 = datadriven.utils.resp(objective.o2.W3,W);
        
        W23 = sqrt(abs(W2).^2+abs(W3).^2);
        if all(W23==0), F_b = [];else, F_b = W23.*Xf;end
        
        
        CON = [CON, datadriven.utils.rcone_serialized(PHI,gam,[F_a,F_b])];
        
    end % END OBJ
    
    %% constraint
    if (parameters.robustNyquist)
        if abs(system.W(1))<1e-4
            Pcstart = conj(Pc(2));
            Pstart = conj(P(2,:));
        else
            Pcstart = conj(Pc(1));
            Pstart = conj(P(1,:));
        end
        
        if abs(system.W(end)-pi/Ts)<1e-4
            Pcend = conj(Pc(end-1));
            Pend = conj(P(end-1,:));
        else
            Pcend = conj(Pc(end));
            Pend = conj(P(end,:));
        end
        Pc_ = [Pcstart;Pc;Pcend];
        Cp2 = [Pstart;P;Pend];
        
        n = datadriven.utils.getNormalDirection(Pc_);
        
        polygonalP1 = 2*real(conj(n).*Cp2(1:end-1));
        polygonalP2 = 2*real(conj(n).*Cp2(2:end));
        
        CON = [CON, polygonalP1>=(1e-5)];
        CON = [CON, polygonalP2>=(1e-5)];
    end
    
    %  ||W_n S_n||_inf< 1    W1, W2, W3, W4
    % ||W1 S||_inf< 1   -> max(|W1|,|system.model*W4|)*||Y/P||_inf < 1
    % ||W2 T||_inf< 1
    % ||W3 U||_inf< 1   -> max(|system.model*W2|,|W3|)*||X/P||_inf < 1
    % ||W3 D||_inf< 1
    
    
    gam = 0.5*ones(nCon,1)*(1+slack(1));
    
    W1 = datadriven.utils.resp(constraints.W1,W);
    W4 = datadriven.utils.resp(constraints.W4,W).*G;
    W14 = max(abs(W1),abs(W4));
    if all(W14==0), F = [];else, F = W14.*Yf;end
    
    CON = [CON, datadriven.utils.rcone_serialized(PHI,gam,F)];
    
    gam = 0.5*ones(nCon,1)*(1+slack(2));
    
    W2 = datadriven.utils.resp(constraints.W2,W).*G;
    W3 = datadriven.utils.resp(constraints.W3,W);
    W23 = max(abs(W2),abs(W3));
    
    if all(W23==0), F = [];else, F = W23.*Xf;end
    CON = [CON, datadriven.utils.rcone_serialized(PHI,gam,F)];
    
end
if isempty(options)
    if strcmp(parameters.solver,'')
        options = sdpsettings('verbose',0);
    else
        options = sdpsettings('verbose',0,'solver',parameters.solver,'cachesolvers',1);
    end
end

diagonstics = optimize(CON,OBJ,options);

kx = double(X_n);
ky = double(Y_n);

sol.H2        = sqrt(double(obj_2));
sol.Hinf      = sqrt(double(obj_inf));
sol.obj       = double(OBJ);

controller = system.controller;
if ~sol.satisfyConstraints
    sol.slack     = max(double(slack));
end

if ~(sol.slack <= 1e-4 && ~sol.satisfyConstraints)
    controller.num = reshape(kx,[1, szx]);
    controller.den = reshape(ky,[1, szy]);
end

sol.nIter = sol.nIter +1;

end % END DATA_DRIVEN_SOLVE