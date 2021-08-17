%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PHILIPPE SCHUCHERT            %
% SCI-STI-AK, EPFL              %
% philippe.schuchert@epfl.ch    %
% March 2021                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Solve the problem using MOSEK + MOSEK FUSION



function [controller,sol,diagnostic] = solveddMOSEK(system,objective,constraint,parameters,sol)
% Do not recompute these values
persistent oinfW2_3 oinfW1_4 o2W1_4 o2W2_3 cW1_4 cW2_3
persistent ZFy ZFx Zx Zy Fy Fx PLANT z_  Ts z

% DATA_DRIVEN SOLVE, USES MOSEK + MOSEK FUSION
import mosek.fusion.*;


M = Model('DATA-DRIVEN OPTIMIZATION');

nCon = length(system.W); % number of constraint
nMod = length(system.model); % number of different models

if isempty(sol)
    % solution struct is not provided: 1st iter
    sol.satisfyConstraints  = 0;
    sol.nIter = 0;
end


%%
% Prepare initial system.controller
controller = system.controller;
X_c = system.controller.num';
Y_c = system.controller.den'; % rescale numerator

szx = length(X_c); % number of parameters num
szy = length(Y_c); % number of parameters num

% Controller coefficient variables

X = M.variable('X',[szx,1]);
Y = M.variable('Y',[szy,1]);

X_n = Expr.add(X_c,X);
Y_n = Expr.add(Y_c,Y);


if  sol.satisfyConstraints
    % If last solution almost satisfies the constraint, fix them and
    % optimize over the objective
    % M.constraint(slack,Domain.equalsTo(0));
    slack = Expr.constTerm(zeros(3,1)); %Matrix.dense(zeros(12,1));
    sol.slack = 0;
    sol.satisfyConstraints = 1;
    
else
    sol.satisfyConstraints = 0;
    slack = M.variable('slack',3,Domain.greaterThan(0));
end


%%

%{
OBJECTIVE : 1st step find system.controller that satisfies the constraint,
then optimize over the objective using constraint. Can be changed using
the softconstraint field, but it is generally not advised (root cause:
constraint impossible to achieve, "bad" system, etc..).
%}

% H_infinity objectives
gamma_inf_mmod = M.variable('gamma_inf',[1,1],Domain.greaterThan(0));
gamma_Inf_mmod = Expr.mul(Matrix.dense(ones(nCon,1)),gamma_inf_mmod);

% H_2 objectives
gamma_2_mmod = M.variable('gamma2',[nCon,nMod],Domain.greaterThan(0));


% do not "new" frequencies from the adaptive grid in the objective.
% Objective may be non-decreasing because of the additionals frequency
% points.
obj_2 = M.variable('o_2',1); % used for obj_2.level()



if not(sol.satisfyConstraints) % l1: some constraint not satified
    OBJ = Expr.sum(slack) ;
else
    % all constraint are satified. Optimize over the H2/Hinf objectives
    % OBJ = mean ( || P ||_2 + ||  P ||_inf )
    OBJ = Expr.add(Expr.sum(Expr.mul(Matrix.dense(1/1),gamma_inf_mmod)), Expr.add(Expr.sum(slack) ,obj_2));
end


obj = M.variable('objective',1);
M.constraint(Expr.sub(OBJ,obj),Domain.equalsTo(0)); % for obj.level();

M.objective('obj', ObjectiveSense.Minimize, OBJ);

%% ----------------

M.constraint(Y_n.index([0,0]), Domain.equalsTo(1));% leading coeff Y = 1

%%

if sol.nIter==0
    Ts = system.controller.Ts;
    z = tf('z',Ts);

    Fx = datadriven.utils.resp(tf(system.controller.Fx,1,Ts),system.W); % fixed part Y
    Fy = datadriven.utils.resp(tf(system.controller.Fy,1,Ts),system.W); % fixed part Y
    
    z_ = datadriven.utils.resp(z,system.W);
    Zy = z_.^((szy-1):-1:0); % [0,z,...,z^nx]
    Zx = z_.^((szx-1):-1:0); % [0,z,...,z^ny]
    ZFy = Zy.*Fy;
    ZFx = Zx.*Fx; % Frequency response K  with the fixed parts
    
    PLANT = zeros(nCon,nMod);
    for mod =  1: nMod
        PLANT(:,mod) = datadriven.utils.resp(system.model(:,:,mod),system.W); % Model Frequency response
    end
    
    
    if (~isempty(objective.o2.W1) || (~isempty(objective.o2.W4)))
        o2W1_4= zeros(nCon,nMod);
        for mod =  1: nMod
            % || x3 ||^2 = |x3(1)|^2+|x3(2)|^2+|x3(3)|^2+|x3(4)|^2
            %            = |W1|^2|Y|^2+|W2|^2|X|^2+|W3|^2|X|^2+|W4|^2|Y|^2
            %            = (|W1|^2+|W4|^2) |Y|^2 + (|W2|^2+|W3|^2) |X|^2 +
            if ~isempty(objective.o2.W1)
                W1 = datadriven.utils.resp(objective.o2.W1,system.W);
            else
                W1 = zeros(nCon,1);
            end
            if ~isempty(objective.o2.W4)
                W4 = PLANT(:,mod).*datadriven.utils.resp(objective.o4.W1,system.W);
            else
                W4 = zeros(nCon,1);
            end
            o2W1_4(:,mod) = sqrt(abs(W1).^2+abs(W4).^2);
        end
    else
        o2W1_4  = [];
    end
    
    if (~isempty(objective.oinf.W1) || (~isempty(objective.oinf.W4))) 
        oinfW1_4= zeros(nCon,nMod);
        for mod =  1: nMod
            % || x3 ||^2 = |x3(1)|^2+|x3(2)|^2+|x3(3)|^2+|x3(4)|^2
            %            = |W1|^2|Y|^2+|W2|^2|X|^2+|W3|^2|X|^2+|W4|^2|Y|^2
            %            = (|W1|^2+|W4|^2) |Y|^2 + (|W2|^2+|W3|^2) |X|^2 +
            if ~isempty(objective.oinf.W1)
                W1 = datadriven.utils.resp(objective.oinf.W1,system.W);
            else
                W1 = zeros(nCon,1);
            end
            if ~isempty(objective.oinf.W4)
                W4 = PLANT(:,mod).*datadriven.utils.resp(objective.oinf.W1,system.W);
            else
                W4 = zeros(nCon,1);
            end
            oinfW1_4(:,mod) = sqrt(abs(W1).^2+abs(W4).^2);
        end
    else
        oinfW1_4  = [];
    end
    
    
    if (~isempty(objective.o2.W2) || (~isempty(objective.o2.W3)))
        o2W2_3= zeros(nCon,nMod);
        for mod =  1: nMod
            % || x3 ||^2 = |x3(1)|^2+|x3(2)|^2+|x3(3)|^2+|x3(4)|^2
            %            = |W1|^2|Y|^2+|W2|^2|X|^2+|W3|^2|X|^2+|W4|^2|Y|^2
            %            = (|W1|^2+|W4|^2) |Y|^2 + (|W2|^2+|W3|^2) |X|^2 +
            if ~isempty(objective.o2.W3)
                W3 = datadriven.utils.resp(objective.o2.W3,system.W);
            else
                W3 = zeros(nCon,1);
            end
            if ~isempty(objective.o2.W2)
                W2 = datadriven.utils.resp(objective.o2.W2,system.W).*PLANT(:,mod);
            else
                W2 = zeros(nCon,1);
            end
            o2W2_3(:,mod) = sqrt(abs(W2).^2+abs(W3).^2);
        end
    else
        o2W2_3  = [];
    end
    
    if (~isempty(objective.oinf.W2) || (~isempty(objective.oinf.W3)))
        oinfW2_3= zeros(nCon,nMod);
        for mod =  1: nMod
            % || x3 ||^2 = |x3(1)|^2+|x3(2)|^2+|x3(3)|^2+|x3(4)|^2
            %            = |W1|^2|Y|^2+|W2|^2|X|^2+|W3|^2|X|^2+|W4|^2|Y|^2
            %            = (|W1|^2+|W4|^2) |Y|^2 + (|W2|^2+|W3|^2) |X|^2 +
            if ~isempty(objective.oinf.W3)
                W3 = datadriven.utils.resp(objective.oinf.W3,system.W);
            else
                W3 = zeros(nCon,1);
            end
            if ~isempty(objective.oinf.W2)
                W2 = PLANT(:,mod).*datadriven.utils.resp(objective.oinf.W2,system.W);
            else
                W2 = zeros(nCon,1);
            end
            oinfW2_3(:,mod) = sqrt(abs(W2).^2+abs(W3).^2);
        end
    else
        oinfW2_3  = [];
    end
    
    if (~isempty(constraint.W1) || ~isempty(constraint.W4))
        cW1_4= zeros(nCon,nMod);
        for mod =  1: nMod
            % batch W1 and W4 -> max(|W1|,|system.model*W4|)*||Y/P||_inf < 1
            if ~isempty(constraint.W1)
                W1 = abs(datadriven.utils.resp(constraint.W1,system.W));
            else
                W1 = zeros(nCon,1);
            end
            if ~isempty(constraint.W4)
                W4 = abs(PLANT(:,mod).*datadriven.utils.resp(constraint.W1,system.W));
            else
                W4 = zeros(nCon,1);
            end
            cW1_4(:,mod) = max(W1,W4);
        end
    else
        cW1_4  = [];
    end
    
    if (~isempty(constraint.W2) || ~isempty(constraint.W3))
        cW2_3= zeros(nCon,nMod);
        for mod =  1: nMod
            % batch W2 and W3 -> max(|system.model*W2|,|W3|)*||X/P||_inf < 1
            if ~isempty(constraint.W2)
                x3_d1 = PLANT(:,mod).*datadriven.utils.resp(constraint.W2,system.W);
            else
                x3_d1 = zeros(nCon,1);
            end
            
            if ~isempty(constraint.W3)
                x3_d2 = datadriven.utils.resp(constraint.W3,system.W);
            else
                x3_d2 = zeros(nCon,1);
            end
            cW2_3(:,mod) = max(abs(x3_d1),abs(x3_d2));
        end
    else
        cW2_3  = [];
    end
end

% Controller coefficents (at location Q, where Q the scheduling
% parameters).
integ =  Ts/(2*pi)* ([diff(system.W(:));0] + [2*system.W(1);diff(system.W(:))]);

gamma_Inf = gamma_Inf_mmod.slice([0,0],[nCon,1]);

XY_n = Expr.vstack(X_n,Y_n);
XY = Expr.vstack(X,Y);
XY_c = [X_c(:);Y_c(:)];
Ycs=Zy*(Y_c); Xcs=Zx*(X_c); % Frequency response without the fixed parts
Yc = Ycs.*Fy; Xc = Xcs.*Fx; % Frequency response Kinit with the fixed parts

if ~isempty(parameters.radius)
     % close the polygonal chain
        if abs(system.W(1))<1e-4
            zstart = conj(z_(2));
        else
            zstart = conj(z_(1));
        end
        
        if abs(system.W(end)-pi/Ts)<1e-4
            zfinish = conj(z_(end-1));
        else
            zfinish = conj(z_(end));
        end
        z2 = [zstart;z_;zfinish];
        
    Zy_ = (parameters.radius*z2).^((szy-1):-1:0);
    Ycs_= Zy_*(Y_c);
    dY = datadriven.utils.getNormalDirection(Ycs_);
    
    x1_a = 2*real(conj(dY).*Zy_(2:end,:));
    x1_b = 2*real(conj(dY).*Zy_(1:end-1,:));
    
    M.constraint(Expr.add(Expr.constTerm(x1_a*Y_c),Expr.mul(Matrix.dense(x1_a),Y)),Domain.greaterThan(0));
    M.constraint(Expr.add(Expr.constTerm(x1_b*Y_c),Expr.mul(Matrix.dense(x1_b),Y)),Domain.greaterThan(0));
end

for mod =  1: nMod
    % For every system, constraint and objectives
    
    gamma_2   = gamma_2_mmod.slice([0,mod-1],[nCon,mod]);
    
    % local 2 norm
    M.constraint(Expr.sub(obj_2,Expr.dot(integ,gamma_2)),Domain.greaterThan(0));
    
    % Initial system.controller coefficents (at location Q, where Q the scheduling
    % parameters).
    
    %% Important (new) values
    
    Pc = PLANT(:,mod).*Xc + Yc; % previous "" Open-loop "" (without numerator Yc)
    Cp =  [PLANT(:,mod).*ZFx, ZFy]; % P = Cp*[X;Y], Cp complex, [X;Y] real, new "" Open-loop "" frequency response
    
    %% OBJECTIVES
    %  only do if system.controller satisifies constraint
    x1 = Expr.add( Expr.mul(2*real(Cp.*conj(Pc)),XY_n), -conj(Pc).*Pc );
    
    if  (sol.satisfyConstraints)
        % H_inf objectives
        % Reminder : rotated cones 2*x1*x2 ≥ ||x3||^2, ||.||  Euclidean norm
        x2 = Expr.mul(0.5,gamma_Inf);
        x3 = [];
        %
        if ~isempty(oinfW1_4)
            x3_d = oinfW1_4(:,mod).*ZFy;
            x3 =  Expr.hstack( Expr.mul(real(x3_d),Y_n),Expr.mul(imag(x3_d),Y_n));
        end
        
        if ~isempty(oinfW2_3)
            x3_d = oinfW2_3(:,mod).*ZFx;
            if isempty(x3)
                x3 =  Expr.hstack(Expr.mul(real(x3_d),X_n),Expr.mul(imag(x3_d),X_n));
            else
                x3 =  Expr.hstack(x3, Expr.mul(real(x3_d),X_n),Expr.mul(imag(x3_d),X_n));
            end
        end
        
        if ~isempty(x3)
            % 2*x1*x2 ≥ ||x3||^2, ||.||  Euclidean norm
            M.constraint((Expr.hstack(x1,x2,x3)), Domain.inRotatedQCone());
        end % END Hinf
        
        % H2
        x2 =   Expr.mul(0.5,gamma_2) ;
        x3 = [];
        
        if (~isempty(objective.o2.W1) || (~isempty(objective.o2.W4)))
            x3_d = o2W1_4(:,mod).*ZFy;
            x3 =  Expr.hstack( Expr.mul(real(x3_d),Y_n),Expr.mul(imag(x3_d),Y_n));
        end
        
        if ~isempty(o2W2_3)
            x3_d = o2W2_3(:,mod).*ZFx;
            if isempty(x3)
                x3 =  Expr.hstack( Expr.mul(real(x3_d),X_n),Expr.mul(imag(x3_d),X_n));
            else
                x3 =  Expr.hstack( x3, Expr.mul(real(x3_d),X_n),Expr.mul(imag(x3_d),X_n));
            end
        end
        
        if ~isempty(x3)
            M.constraint((Expr.hstack(x1,x2,x3)), Domain.inRotatedQCone());
        end % END H2
    end % END OBJ
    
    %% constraint
    % CONSTAINTS ||W_n S_n||_inf< 1    W1, W2, W3, W4
    % ||W1 S||_inf< 1   -> max(|W1|,|system.model*W4|)*||Y/P||_inf < 1
    % ||W2 T||_inf< 1
    % ||W3 U||_inf< 1   -> max(|system.model*W2|,|W3|)*||X/P||_inf < 1
    % ||W3 D||_inf< 1
    
    if ~isempty(cW1_4)
        x2 = Expr.add(Matrix.dense( 0.5*ones(nCon,1)), Expr.mul(Matrix.dense(ones(nCon,1)),slack.pick(1)));
        x3_d =  cW1_4(:,mod).*ZFy ;
        x3 =  Expr.hstack( Expr.mul(Matrix.dense(real(x3_d)),Y_n),Expr.mul(Matrix.dense(imag(x3_d)),Y_n));
        
        M.constraint(Expr.hstack(x1,x2,x3), Domain.inRotatedQCone());
    end
    
    
    if ~isempty(cW2_3)
        x2 = Expr.add(0.5*ones(nCon,1), Expr.mul(Matrix.dense(ones(nCon,1)),slack.pick(2)));
        x3_d = cW2_3(:,mod).*ZFx ;
        x3 =  Expr.hstack( Expr.mul(real(x3_d),X_n),Expr.mul(imag(x3_d),X_n));
        
        M.constraint((Expr.hstack(x1,x2,x3)), Domain.inRotatedQCone());
    end
  
    
    if  (parameters.robustNyquist)
        % close the polygonal chain
        if abs(system.W(1))<1e-4
            Pcstart = conj(Pc(2));
            Cpstart = conj(Cp(2,:));
        else
            Pcstart = conj(Pc(1));
            Cpstart = conj(Cp(1,:));
        end
        
        if abs(system.W(end)-pi/Ts)<1e-4
            Pcend = conj(Pc(end-1));
            Cpend = conj(Cp(end-1,:));
        else
            Pcend = conj(Pc(end));
            Cpend = conj(Cp(end,:));
        end
        Pc_ = [Pcstart;Pc;Pcend];
        Cp2 = [Cpstart;Cp;Cpend];
        dP = datadriven.utils.getNormalDirection(Pc_);
        x1_a = 2*real(conj(dP).*Cp2(2:end,:));
        x1_b = 2*real(conj(dP).*Cp2(1:end-1,:));
        
        M.constraint(Expr.add(Expr.constTerm(x1_a*XY_c),Expr.mul(Matrix.dense(x1_a),XY)),Domain.greaterThan(0));
        M.constraint(Expr.add(Expr.constTerm(x1_b*XY_c),Expr.mul(Matrix.dense(x1_b),XY)),Domain.greaterThan(0));
    end
    
end

M.setSolverParam("intpntSolveForm", "dual")

t1 = tic;
M.solve();
diagnostic.solvertime = toc(t1);
M.acceptedSolutionStatus(AccSolutionStatus.Anything);

kx = X_c + X.level();
ky = Y_c + Y.level();


sol.H2        = sqrt(obj_2.level());
sol.Hinf      = sqrt(max(gamma_inf_mmod.level()));
sol.obj       = max(obj.level(),0);

diagnostic.primal    = char(M.getPrimalSolutionStatus);
diagnostic.dual      = char(M.getDualSolutionStatus);
diagnostic.primalVal = M.primalObjValue();
diagnostic.dualVal   = M.dualObjValue();


if ~sol.satisfyConstraints
    sol.slack     = max(abs(slack.level()));
end

if ~(sol.slack <= 1e-4 && ~sol.satisfyConstraints)
    controller.num = reshape(kx,[1, szx]);
    controller.den = reshape(ky,[1, szy]);
end

sol.nIter = sol.nIter +1;
M.dispose();

end % END DATA_DRIVEN_SOLVE

