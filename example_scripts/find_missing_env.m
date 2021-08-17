%%find_missing_env Script to find environments left for grid search
%   
%   Helper script for finding env_idx of environments for which grid search has
%   not been performed. Useful when running search on HPC.
% 

%% Cleanup ---------------------------------------------------------------------
clearvars; close all; clc;

%% Basic Specifications --------------------------------------------------------
controller_type = "datadriven"; % {integrator, datadriven}

%% Environment Space -----------------------------------------------------------
Fs_space = [100, 200, 400, 800];   % [Hz]
photon_space = union(...
    linspace(16, 160, 19), ...
    linspace(16, 1600, 10));

[Fs_grid, photon_grid] = ndgrid(Fs_space, photon_space);
env_space = [Fs_grid(:), photon_grid(:)];
n_env_space = size(env_space, 1);

%% Read datafiles (Env. space covered) -----------------------------------------
folder = fullfile( ...
    "data", ...
    "readout", ...
    "optimise_integrator");

fs_folders = dir(fullfile( ...
    folder, ...
    "*_Hz"));

n_fs_folders = length(fs_folders);

env_space_covered = [];
for i_fs_folder = 1:n_fs_folders
    Fs = double(extractBefore(...
        string(fs_folders(i_fs_folder).name), ...
        "_Hz"));
    
    photon_files = dir(fullfile( ...
        folder, ...
        sprintf("%04d_Hz", Fs), ...
        "*_photons.mat"));
    
    photon_space_covered = double(extractBefore(...
        string({photon_files.name}), ...
        "_photons.mat"));
    n_photon_space_covered = length(photon_space_covered);
    
    env_space_covered = [env_space_covered;...
        repmat(Fs, n_photon_space_covered, 1), ...
        photon_space_covered(:)];
end

%% Left env. indexes -----------------------------------------------------------
env_space_left = setdiff(env_space, env_space_covered, "rows");
n_env_space_left = size(env_space_left, 1);

left_env_idx = zeros(n_env_space_left, 1);
for i_env_space_left = 1:n_env_space_left
    tmp = env_space == env_space_left(i_env_space_left, :);
    left_env_idx(i_env_space_left) = find(tmp(:, 1) & tmp(:, 2));
end

fprintf("%d,", left_env_idx);
fprintf("\n"); 