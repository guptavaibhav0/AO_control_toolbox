function search_integrator_env(env_idxs, options)
%search_integrator_env Run integrator parameter search for different envs
%
%   search_integrator_env(env_idxs) runs integrator parameter search for all
%   environments (Fs and, n_photons) in the `env_idx` array. `env_idx` can have
%   values between 1 and 112.
% 
    
    arguments
        env_idxs                (1, :) double
        options.readout_noise   (1, 1) logical = true
    end

    %% Setup ParPool -----------------------------------------------------------
    p = gcp('nocreate'); % If no pool, do not create new one
    if isempty(p)
        % Cluster cleanup
        c = parcluster("local");
        delete(c.Jobs);

        % Get the number of cores allocated by slurm
        n = feature("numcores");

        % Create a parpool
        parpool(c, n);
    end

    %% Load required libraries -------------------------------------------------
    MATLAB_environment_setup();

    %% Environment Space -------------------------------------------------------
    Fs_space = [100, 200, 400, 800];   % [Hz]
    photon_space = union(...
        linspace(16, 160, 19), ...
        linspace(16, 1600, 10));

    [Fs_grid, photon_grid] = ndgrid(Fs_space, photon_space);
    env_space = [Fs_grid(:), photon_grid(:)];
    n_env_space = size(env_space, 1);

    % Ensure that `env_idxs` have correct values
    env_idxs = env_idxs(env_idxs <= n_env_space & env_idxs > 0);

    %% Simulations for given environment ---------------------------------------
    for env_idx = env_idxs
        clc;
        fprintf("Current Environment Space: %4d / %-4d\n", env_idx, n_env_space);
        env = env_space(env_idx, :);
        try
            utility_functions.search_integrator_params(env(1), env(2), ...
                "readout_noise", options.readout_noise);
        catch ME
            % Skip in case of error
            warning("search_datadriven_env:search_datadriven_params", ...
                "%s\n", ME.identifier, ME.message);
            continue;
        end
    end
end