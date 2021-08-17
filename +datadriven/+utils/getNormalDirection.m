%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PHILIPPE SCHUCHERT            %
% SCI-STI-AK, EPFL              %
% philippe.schuchert@epfl.ch    %
% March 2021                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% normal inwards direction for the polygonal chain
%

function n = getNormalDirection(r)
n = 1j*diff(r);
for ii = 1 : length(n)
    if n(ii) == 0
        n(ii) = r(ii);
    elseif  imag(n(ii)'*r(ii))*imag(n(ii)'*r(ii+1))>0
       [~, idx] = min(abs(r(ii:ii+1)));
       n(ii) = r(ii-1+idx);
   end 
end
n = n./abs(n);
n = n.*sign(real(conj(n).*r(1:end-1)));
end

