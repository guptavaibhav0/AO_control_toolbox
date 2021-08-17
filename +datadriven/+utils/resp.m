%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PHILIPPE SCHUCHERT            %
% SCI-STI-AK, EPFL              %
% philippe.schuchert@epfl.ch    %
% March 2021                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% because typing  squeeze(freqresp(G,W)) many times is annoying
%

function resp_ = resp(G,W)
if ~isempty(G)
    resp_ = squeeze(freqresp(G,W));
else
    resp_ = zeros(size(W));
end
end
