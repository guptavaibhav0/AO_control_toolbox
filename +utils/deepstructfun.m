function varargout = deepstructfun(func, S)
%deepstructfun Applies a function to all sub-structures
% 
%   varargout = deepstructfun(func, S) applies the given `func` to all the 
%   leaves of the given structure in a recursive manner.
% 

    if isstruct(S)
        % If S is a structure, recurse on the structure nodes
        [varargout{1:nargout}] = structfun( ...
            @(x) utils.deepstructfun(func, x), ...
            S, ...
            'UniformOutput', false);
    else
        % If S is a leaf, apply the function
        [varargout{1:nargout}] = func(S);
    end

end