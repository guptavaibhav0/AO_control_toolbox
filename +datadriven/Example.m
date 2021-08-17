% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PHILIPPE SCHUCHERT            %
% SCI-STI-AK, EPFL              %
% philippe.schuchert@epfl.ch    %
% March 2021                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Example use of the datadriven command
clc; close all

%% Things we know / have measured

Ts = 1;
z = tf('z',1);

G = 0.002/(z-1.002); % System to be controller, unstable (pole at z=1.002)
% Here parameteric model is used, as the closed-loop will be simulated.
% Only the frequency response function (FRF) is needed for controller synthesis.


K = pid(50,10,0,0,1); % Inital controller that is known to be stabilizing
Sinit = feedback(1,G*K);

disp(['Eigenvalues close-loop using initial controller: ', num2str(max(abs(eig(Sinit)))), ' (stable CL)']) % < 1 --> Stable Closed-loop

%%


% Initial controller of order 1, but we want a final controller of order 3:
% -> zero padding to get the correct order.
[num,den] = tfdata(K,'v'); % get numerator/denominator of PID controller
orderK = 3;
den(orderK+1) = 0; % zero padding
num(orderK+1) = 0; % zero padding

% Poles on unit cicle of the controller have to be in the fixed parts
Fy = [1 -1]; % fixed parts in denominator.
den_new = deconv(den,Fy); % den = conv(den_new,Fy).

% Denominator has only 2 tunable coefficients (first one is fixed to 1).
% Numerator has 4 tunable coefficients,  Fx = 1. No need to change num.

%% SET-UP system info

[SYS, OBJ, CON, PAR] = datadriven.utils.emptyStruct(); % load empty structure


ctrl = struct('num',num,'den',den_new,'Ts',Ts,'Fx',1,'Fy',Fy); % assemble controller

SYS.controller = ctrl;
SYS.model = G; % Specify model(s)
SYS.W = datadriven.utils.logspace2(0.01,pi/Ts,100); % specify frequency grid where problem is solved

%% Objective(s)
% See different fields of OBJ
W1 = 1/(tf('z',Ts)-1);
OBJ.o2.W1 = W1; % Only minimize || W1 S ||_\infty 

%% Constraints(s)
% See different fields of CON
W2 =  1/c2d(makeweight(2,0.1*pi/Ts,0),Ts);
CON.W2 = W2; % Only constraint || W2 T ||_\infty ≤ 1 

%% Solve problem
% See different fields of PAR
PAR.tol = 1e-4; % stop when change in objective < 1e-4. 
%PAR.maxIter = 10; % max Number of iterations

tic
[controller,obj] = datadriven.datadriven(SYS,OBJ,CON,PAR,'fusion');
toc

% Other solver can be used as last additional argument:
% [controller,obj] = datadriven(SYS,OBJ,CON,PAR,'sedumi'); to force YALMIP
% to use sedumi as solver.
% If mosek AND mosek Fusion are installed, you can use
% [controller,obj] = datadriven(SYS,OBJ,CON,PAR,'fusion');
% (much faster, no need for YALMIP as middle-man)

%% Analysis using optimal controller

Kdd = datadriven.utils.toTF(controller); % 
S = feedback(1,G*Kdd);

bodemag(Sinit,'-.r',S,'-r',1-S,1/W2,'--k',SYS.W)
ylim([-20 10])
grid
legend('Initial $\mathcal{S}$','Final $\mathcal{S}$','$\mathcal{T}$','$\overline{W_2}^{-1}$','interpreter','LaTeX')
legend('Initial $\mathcal{S}$','Final $\mathcal{S}$','$\mathcal{T}$','$\overline{W_2}^{-1}$','interpreter','LaTeX')
% Need to plot legend two times (bug with MATLAB 2020).
shg

disp(['H2 computed using trapz integration: ', num2str(obj.H2)])
disp(['H2 true value: ', num2str(norm(minreal(S*W1),2))])
% True H2 value not accessible when using the FRF