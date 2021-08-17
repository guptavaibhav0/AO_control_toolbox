%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PHILIPPE SCHUCHERT            %
% SCI-STI-AK, EPFL              %
% philippe.schuchert@epfl.ch    %
% March 2021                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% Converts structure to TF
%

function Kdd = toTF(controller)
Kdd = tf(conv(controller.num,controller.Fx),conv(controller.den,controller.Fy),controller.Ts);
end