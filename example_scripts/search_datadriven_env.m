function search_datadriven_env(env_idxs, options)
%search_datadriven_env Run datadriven parameter search for multiple env
%
%   search_datadriven_env(env_idxs) runs datadriven parameter search for all
%   environments (Fs and n_photons) in the `env_idx` array. `env_idx` can have
%   values between 1 and 16.
% 
%   search_datadriven_env(___, solver) runs datadriven parameter search and uses
%   `solver` for datadriven controller design.
% 

    arguments
        env_idxs              (1, :) double
        options.solver        (1, 1) string  = "fusion"
        options.readout_noise (1, 1) logical = false
    end

    %% Load required libraries -------------------------------------------------
    MATLAB_environment_setup();

    %% Environment Space -------------------------------------------------------
    Fs_space = [100, 200, 400, 800];   % [Hz]
    photon_space = [16, 32, 64, 1600];	% Related to RMS of [0.1, 0.5, 1.0]

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
            utility_functions.search_datadriven_params(env(1), env(2), ...
                "solver"       , options.solver, ...
                "readout_noise", options.readout_noise, ...
                "use_parallel" , false);
        catch ME
            % Skip in case of error
            warning("search_datadriven_env:search_datadriven_params", ...
                "%s\n", ME.identifier, ME.message);
            continue;
        end
    end
end
