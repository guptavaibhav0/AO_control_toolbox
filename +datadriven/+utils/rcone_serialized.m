%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PHILIPPE SCHUCHERT            %
% SCI-STI-AK, EPFL              %
% philippe.schuchert@epfl.ch    %
% March 2021                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% cone from YALMIP is not serialized -> use this instead 
%

function rcone = rcone_serialized(x,y,z)
if ~isempty(z)
    % ||z||^2<2xy, x+y>0
    v = 1/sqrt(2);
    T = blkdiag([v,v;v,-v], eye(2*size(z,2)));
    
    Z = T\[x.';y.';real(z).';imag(z).'];
    
    rcone = cone(Z);
else
    rcone = [];
end
end