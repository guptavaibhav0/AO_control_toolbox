%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PHILIPPE SCHUCHERT            %
% SCI-STI-AK, EPFL              %
% philippe.schuchert@epfl.ch    %
% March 2021                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% Iteratively solve the datadriven problem
%

function [controller, sol] = datadriven(system, obj, cons, params, verbose, solver)
if nargin == 6
    params.solver = solver;
end
if nargin < 5
    verbose = true;
end

if verbose
    fprintf("  iter  |   slack    |     obj     |  decrease   | Total SOLVE time\n")
    fprintf("--------|------------|-------------|-------------|-----------------\n")
end


iter = 0; op = NaN; sol = [];
solveTime = 0;
while iter < params.maxIter
    iter = iter + 1;
    switch params.solver
        case 'fusion'
            [system.controller,sol,d] = datadriven.utils.solveddMOSEK(system,obj,cons,params,sol);
        otherwise
            [system.controller,sol,d] = datadriven.utils.solveddYALMIP(system,obj,cons,params,sol);     
    end
    solveTime = solveTime + d.solvertime; % Does not include yalmiptime!
    if isnan(op)
        diffString = '           ';
        
    else
        diffString = num2str(sol.obj-op, '%.04e');
        
    end
    if sol.satisfyConstraints
        solString = num2str(abs(sol.obj),'%+.04e');
    else
        solString = '           ';
    end
    
    if verbose
        fprintf("   %03d  | %.04e | %s | %s | %8.04e \n",sol.nIter, sol.slack, solString , diffString,solveTime)
    end
    
    if sol.obj-op >= -params.tol
        break
    end
    if sol.satisfyConstraints
        op = sol.obj;
    end
    if sol.slack < 1e-4
        sol.satisfyConstraints  = 1;
    end
end

controller = system.controller;
sol = rmfield(sol,'satisfyConstraints');
end