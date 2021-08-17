function MATLAB_environment_setup(use_hpc)
%%MATLAB_environment_setup Setup libraries for MATLAB
%
%   MATLAB_environment_setup() sets MATLAB environment for non-HPC usecases.
% 
%   MATLAB_environment_setup(true) sets MATLAB environment for HPC.
% 

    arguments
        use_hpc (1, 1) logical = false
    end

    if use_hpc
        % Add path to the `toolbox maanger`
        addpath("/home/users/g/guptavai/tbxmanager");
        tbxmanager restorepath;
        
        % Path to mosek/fusion (if available)
        % javaaddpath("${MOSEK}\9.2\tools\platform\win64x86\bin\mosek.jar")
    else
        if ~contains(path, "yalmip")
            tbxmanager restorepath;
        end
        
        % Path to mosek/fusion (if available)
        path_to_mosek = "C:\Program Files\Mosek\9.2\tools\platform\win64x86\bin\mosek.jar";
        if (strlength(path_to_mosek) && ~any(strcmp(javaclasspath('-dynamic'), path_to_mosek)))
            javaaddpath(path_to_mosek);
            fprintf("""Mosek"" added to the Matlab path");
        end
    end
end