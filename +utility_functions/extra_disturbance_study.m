function extra_disturbance_study(Fs, n_photons, options)
%extra_disturbance_study Extra disturbance study for the controller
% 
%   extra_disturbance_study(Fs, n_photons) saves rms value of the error for the
%   controller with the extra disurbances. The flux noise is determined by the
%   `n_photons` recieved per timestep. Controller frequency is given by `Fs` Hz.
% 
%   extra_disturbance_study(___, name, value) specifies the optional and the
%   simulation parameters.
%
%   Name-Value Pair Arguments:
%     |----------------|-------------------------------------------------------|
%     | Name           | Description                                           |
%     |----------------|-------------------------------------------------------|
%     | design_extra   | Disturbance type for controller design                |
%     |                |   {"none", "chirp", "narrowband"}                     |
%     |----------------|-------------------------------------------------------|
%     | sim_extra      | Disturbance type for the simulation                   |
%     |                |   {"none", "chirp", "narrowband"}                     |
%     |----------------|-------------------------------------------------------|
%     | readout_noise  | If detector has a readout noise                       |
%     |                |   Default: false                                      |
%     |----------------|-------------------------------------------------------|
%     | save_data      | To save generated PSD data in the file                |
%     |                | `extra_disturbance_study/%d_Hz/%d_photons.mat`        |
%     |                |   Default: true                                       |
%     |----------------|-------------------------------------------------------|
%     | print_progress | To print the current progress                         |
%     |                |   Default: true                                       |
%     |----------------|-------------------------------------------------------|
%     | sound_alarm    | To sound the alarm at the end of the run              |
%     |                |   Default: false                                      |
%     |----------------|-------------------------------------------------------|
%     | solver         | Solver to use for data-driven design                  |
%     |                |   Default: "fusion"                                   |
%     |----------------|-------------------------------------------------------|
% 

    arguments
        Fs                      (1, 1) double  = 400
        n_photons               (1, 1) double  = 1600
        options.design_extra    (1, 1) string  = "none"
        options.sim_extra       (1, 1) string  = "narrowband"
        options.readout_noise   (1, 1) logical = false
        options.save_data       (1, 1) logical = true
        options.print_progress  (1, 1) logical = true
        options.sound_alarm     (1, 1) logical = false
        options.solver          (1, 1) string  = "fusion"
    end

    %% Study type selection ----------------------------------------------------
    
    % No extra disturbance 
    if (strcmp(options.design_extra, "none") && ...
        strcmp(options.sim_extra, "none"))
        error("utils:extra_disturbance_study:null_study", "\n\t%s", ...
            "No extra disturbance has been set for both simulation and design.", ...
            "Possible types are {'chirp', 'narrowband', 'none'}." ...
        );
    end
    
    % Mismatch in disturbance type
    if (~strcmp(options.design_extra, "none") && ...
        ~strcmp(options.sim_extra, "none"))
        if ~strcmp(options.design_extra, options.sim_extra)
            error("utils:extra_disturbance_study:type_mismatch", "\n\t%s", ...
                "The type of the extra disturbance must be same or 'none'.", ...
                sprintf("The disturbance type for controller design is '%s'.", options.design_extra), ...
                sprintf("The disturbance type for simulation is '%s'.", options.sim_extra)  ...
            );
        end
    end

    if strcmp(options.design_extra, "none")
        % Unknown Disturbance (Simulation only)
        study_type = "unknown_disturbance";
        extra_type = options.sim_extra;
    elseif strcmp(options.sim_extra, "none")
        % Unknown Disturbance (Design only)
        study_type = "wrong_disturbance";
        extra_type = options.design_extra;
    else
        % Known Disturbance (Design and Simulation)
        study_type = "known_disturbance";
        extra_type = options.sim_extra;
    end
    
    %% Basic Specifications ----------------------------------------------------
    if options.readout_noise
        datafolder = fullfile("data", "readout");
    else
        datafolder = fullfile("data", "no_readout");
    end

    % Save file for optimised results
    parent_folder = fullfile( ...
        datafolder, ...
        "extra_disturbance_study", ...
        sprintf("%s", study_type), ...
        sprintf("%s", extra_type), ...
        sprintf("%04d_Hz", Fs));
    save_filename = fullfile( ...
        parent_folder, ...
        sprintf("%04d_photons.mat", n_photons));

    if isfile(save_filename)
        % If already done, skip!
        return
    end
    
    %% Run Study ---------------------------------------------------------------
    switch study_type
        case "known_disturbance"
            [extra_space, rms_data] = ...
                utility_functions.extra_disturbance_study_known( ...
                    Fs, n_photons, ...
                    "readout_noise" , options.readout_noise, ...
                    "print_progress", options.print_progress, ...
                    "solver"        , options.solver, ...
                    "extra_type"    , extra_type ...
                );
        case "unknown_disturbance"
            [extra_space, rms_data] = ...
                utility_functions.extra_disturbance_study_unknown( ...
                    Fs, n_photons, ...
                    "readout_noise" , options.readout_noise, ...
                    "print_progress", options.print_progress, ...
                    "solver"        , options.solver, ...
                    "extra_type"    , extra_type ...
                );
        case "wrong_disturbance"
            [extra_space, rms_data] = ...
                utility_functions.extra_disturbance_study_wrong( ...
                    Fs, n_photons, ...
                    "readout_noise" , options.readout_noise, ...
                    "print_progress", options.print_progress, ...
                    "solver"        , options.solver, ...
                    "extra_type"    , extra_type ...
                );
    end

    %% Save Data ---------------------------------------------------------------
    if options.save_data
        if ~isfolder(parent_folder)
            mkdir(parent_folder)
        end
        save(save_filename, ...
            "rms_data", ...
            "extra_space");
    end

    %% Finish alarm ------------------------------------------------------------
    if options.sound_alarm
        alarm = load("handel"); sound(alarm.y, alarm.Fs);
    end
end