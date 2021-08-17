%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PHILIPPE SCHUCHERT            %
% SCI-STI-AK, EPFL              %
% philippe.schuchert@epfl.ch    %
% March 2021                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% Converts structure to controller K = X/Y
%

function [X,Y] = toXY(controller)
X = tf(conv(controller.num,controller.Fx),1,controller.Ts);
Y = tf(conv(controller.den,controller.Fy),1,controller.Ts);
end