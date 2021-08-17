function run_controller_statistics_hpc(env_idxs, options)
%run_controller_statistics_hpc Run controller statistics on HPC
% 
%   run_controller_statistics_hpc(env_idxs) runs controller statistics for all
%   environments (Fs and, n_photons) in the `env_idx` array. `env_idx` can have
%   values between 1 and 144.
% 
%   run_controller_statistics_hpc(___, solver) runs datadriven parameter search 
%   and uses `solver` for datadriven controller design.
% 
    
    arguments
        env_idxs              (1, :) double
        options.solver        (1, 1) string  = "sedumi"
        options.readout_noise (1, 1) logical = false
    end

    %% Setup ParPool for HPC ---------------------------------------------------

    % Create a temporary directory for parcluster
    % (this directory is removed automatically at the end of execution)
    t = tempname();
    mkdir(t);
    fprintf("Temporary space for parcluster: %s\n", t);

    % Cluster cleanup
    c = parcluster("local");
    c.JobStorageLocation = t;
    delete(c.Jobs);

    % Get the number of cores allocated by slurm
    n = str2double(getenv("SLURM_CPUS_PER_TASK"));

    % Create a parpool
    parpool(c, n);

    %% Load required libraries -------------------------------------------------
    MATLAB_environment_setup(true);
    
    %% Environment Space -------------------------------------------------------
    Fs_space = [100, 200, 400, 800];   % [Hz]
    photon_space = union(...
        linspace(16, 160, 19), ...
        [linspace(16, 1600, 10), ...
        linspace(1600, 4800, 9)]);

    [Fs_grid, photon_grid] = ndgrid(Fs_space, photon_space);
    env_space = [Fs_grid(:), photon_grid(:)];
    n_env_space = size(env_space, 1);
    
    % Ensure that `env_idxs` have correct values
    env_idxs = env_idxs(env_idxs <= n_env_space & env_idxs > 0);

    %% Simulations for the environments ----------------------------------------
    for env_idx = env_idxs
        clc;
        fprintf("Current Environment Space: %4d / %-4d\n", env_idx, n_env_space);
        env = env_space(env_idx, :);
        try
            utility_functions.compare_controllers_statistics(env(1), env(2), 100, ...
                "readout_noise", options.readout_noise, ...
                "solver", options.solver);
        catch ME
            % Skip in case of error
            warning("compare_controller_statistics_hpc:compare_controller_statistics", ...
                "%s\n", ME.identifier, ME.message);
            continue;
        end
    end
end

