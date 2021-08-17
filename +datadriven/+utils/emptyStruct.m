%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PHILIPPE SCHUCHERT            %
% SCI-STI-AK, EPFL              %
% philippe.schuchert@epfl.ch    %
% March 2021                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% Empty structures required for datadriven 
%

function [SYS, OBJ, CON, PAR] = emptyStruct()
ctrl = struct('num',[],'den',[],'Ts',[],'Fx',[],'Fy',[]);
SYS = struct('model',[],'W',[],'controller',ctrl);


PAR = struct('tol',1e-6,'maxIter',100,'radius',1,'robustNyquist',true,'solver','');

OBJ  = struct('oinf',struct('W1',[],'W2',[],'W3',[],'W4',[]),...
               'o2',  struct('W1',[],'W2',[],'W3',[],'W4',[]));
CON = struct('W1',[],'W2',[],'W3',[],'W4',[]);
end