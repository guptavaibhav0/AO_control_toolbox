function [extra_space, rms_data] = extra_disturbance_study_unknown( ...
    Fs, n_photons, options)
%extra_disturbance_study_unknown Unknown extra disturbance study
% 
%   extra_disturbance_study_known(Fs, n_photons) gives the rms value of the 
%   error for the controller when the extra disurbances are unknown during the
%   design phase. The flux noise is determined by the `n_photons` recieved per
%   timestep. Controller frequency is given by `Fs` Hz.
% 
%   extra_disturbance_study_known(___, name, value) specifies the optional and
%   simulation parameters.
%
%   Name-Value Pair Arguments:
%     |----------------|-------------------------------------------------------|
%     | Name           | Description                                           |
%     |----------------|-------------------------------------------------------|
%     | extra_type     | Extra disturbance type                                |
%     |                |   {"none", "chirp", "narrowband"}                     |
%     |----------------|-------------------------------------------------------|
%     | readout_noise  | If detector has a readout noise                       |
%     |                |   Default: false                                      |
%     |----------------|-------------------------------------------------------|
%     | print_progress | To print the current progress                         |
%     |                |   Default: true                                       |
%     |----------------|-------------------------------------------------------|
%     | solver         | Solver to use for data-driven design                  |
%     |                |   Default: "fusion"                                   |
%     |----------------|-------------------------------------------------------|
%   
%   Other specifications for the simulations and the controllers specified 
%   in the `Basic Specifications` section:
%     |---------------------|--------------------------------------------------|
%     | Variable Name       | Description                                      |
%     |---------------------|--------------------------------------------------|
%     | tau_lag             | Communication lag [s]                            |
%     |---------------------|--------------------------------------------------|
%     | instrument_filename | '.fit' file containing instrument disturbance as |
%     |                     | a timeseries                                     |
%     |---------------------|--------------------------------------------------|
%     | instrument_Fs       | Sampling frequency of instrument disturbance [Hz]|
%     |---------------------|--------------------------------------------------|
%     | max_T_sim           | Simulation time [s]                              |
%     |---------------------|--------------------------------------------------|
% 
%   Note:
%     * Do not use this function directly, instead use the wrapper function
%       `extra_disturbance_study`.
%

    arguments
        Fs                      (1, 1) double  = 400
        n_photons               (1, 1) double  = 1600
        options.extra_type      (1, 1) string  = "chirp"
        options.readout_noise   (1, 1) logical = false
        options.print_progress  (1, 1) logical = true
        options.solver          (1, 1) string  = "fusion"
    end

    %% Basic Specifications ----------------------------------------------------
    if options.readout_noise
        datafolder = fullfile("data", "readout");
    else
        datafolder = fullfile("data", "no_readout");
    end
    
    % Simulation frequency [Hz]
    Fs_sim = Fs;

    % Communication/Calculation Lag [s]
    tau_lag = 0.4e-3;
    
    % Instrument Noise File
    filename = fullfile("data", "vibrationNRCIMJun2018ForGupta.fits");
    Fs_data = 800;      % Sampling frequency for Instrument Noise [Hz]
    
    % Max. simulation time [s]
    max_T_sim = 100;

    %% Optimised Parameters ----------------------------------------------------
    integrator_params = load(fullfile(...
        datafolder, ...
        "optimise_integrator", ...
        "optimised_params.mat"));

    datadriven_params = load(fullfile(...
        datafolder, ...
        "optimise_datadriven", ...
        "optimised_params.mat"));

    for DoF = ["tip", "tilt"]
        integrator_gain.(DoF) = ...
            integrator_params.get_optimal_gain.(DoF)(Fs, n_photons);

        param = cellfun( ...
            @(x) x(Fs, n_photons), ...
            datadriven_params.get_optimal_params.(DoF));

        controller_gain.(DoF) = param(1);    
        controller_order.(DoF) = param(2);
        controller_bandwidth.(DoF) = param(3);
        controller_alpha.(DoF) = param(4);
    end

    %% Nominal TMT Disturbance Model -------------------------------------------
    TMT_disturbance = TMT_disturbance_model();
    TMT_disturbance.w = logspace(-4, pi, 1000) * Fs_data;
    TMT_disturbance.Fs_sim = Fs_sim;
    TMT_disturbance.add_instrument_disturbance(filename, Fs_data);
    
    ts = struct();
    ts.tip = TMT_disturbance.get_ts("tip", max_T_sim);
    ts.tilt = TMT_disturbance.get_ts("tilt", max_T_sim);
    ts.noise = utils.get_white_noise(...
        utils.get_flux_noise_rms(n_photons, ...
            "readout_noise", options.readout_noise), ...
        ts.tip.Time(end), ...
        Fs_sim ...
    );

    %% Extra Disturbance -------------------------------------------------------
    extra_space = utils.get_extra_disturbance_space(options.extra_type);
    n_extra_space = size(extra_space, 1);

    %%% Extra disturbance for simulation
    ts_extra = cell(1, n_extra_space);
    for i_extra_space = 1:n_extra_space
        switch options.extra_type
            case "chirp"
                ts_extra{i_extra_space} = ...
                    utils.get_chirp_disturbance( ...
                        extra_space(i_extra_space, 1), ...
                        ts.tip.Time(end), Fs_sim ...
                    );
            case "narrowband"
                ts_extra{i_extra_space} = ...
                    utils.get_narrowband_disturbance( ...
                        extra_space(i_extra_space, 1), ...
                        extra_space(i_extra_space, 2), ...
                        extra_space(i_extra_space, 3), ...
                        ts.tip.Time(end), Fs_sim ...
                    );
            otherwise
                time_data = 0:1/Fs_sim:ts.tip.Time(end);
                ts_extra{i_extra_space} = timeseries(...
                    time_data.' * 0, ...
                    time_data, ...
                    "Name", "No Extra Disturbance" ...
                );
        end
    end

    %% Design controllers ------------------------------------------------------
    empty_cells = cell(1, 1);
    controllers = struct(...
        "tip" , empty_cells, ...
        "tilt", empty_cells  ...
    );

    for DoF = ["tip", "tilt"]
        for type = ["int", "data"]
            controllers.(DoF).(type) = ...
                VibrationController(type, ...
                    "Fs"     , Fs            , ...
                    "tau_lag", tau_lag       , ...
                    "solver" , options.solver  ...
                );
            controllers.(DoF).(type).set_disturbance_frd( ...
                TMT_disturbance.get_frd_model(DoF));
            controllers.(DoF).(type).set_flux_noise_rms( ...
                utils.get_flux_noise_rms(n_photons, ...
                    "readout_noise", options.readout_noise));
            if type == "int"
                controllers.(DoF).(type).update_parameter( ...
                    "gain", integrator_gain.(DoF));
            else
                controllers.(DoF).(type).update_parameter(...
                    "gain"      , controller_gain.(DoF)     , ...
                    "order"     , controller_order.(DoF)    , ...
                    "bandwidth" , controller_bandwidth.(DoF), ...
                    "alpha"     , controller_alpha.(DoF)    );
            end
            controllers.(DoF).(type).design(false);
        end
    end

    %% Loop over extra disturbance space ---------------------------------------
    print_progress = options.print_progress;
    
    empty_cells = cell(n_extra_space, 1);
    rms_data = struct(...
        "tip", empty_cells, ...
        "tilt", empty_cells ...
    );

    if print_progress
        count = 0;
        progressQueue = parallel.pool.DataQueue;
        afterEach(progressQueue, @updateProgress);
        send(progressQueue, 0);
    end

    parfor i_extra_space = 1:n_extra_space
        %%% Simulators ---------------------------------------------------------
        simulators = struct();
        for DoF = ["tip", "tilt"]
            for type = ["int", "data"]
                simulators.(DoF).(type) = Simulator(Fs, tau_lag);
                simulators.(DoF).(type).set_controller(...
                    controllers.(DoF).(type));
                simulators.(DoF).(type).run( ...
                    ts.(DoF) + ts_extra{i_extra_space}, ...
                    ts.noise ...
                );
            end
        end

        % Simulation Data Results
        sim_data = utils.deepstructfun( ...
            @(x) x.result, ...
            simulators);
        for DoF = ["tip", "tilt"]
            sim_data.(DoF).raw.disturbance = ts.(DoF).Data + ...
                ts_extra{i_extra_space}.Data;
            sim_data.(DoF).raw.noise = ts.noise.Data;
            sim_data.(DoF).raw.total = ts.(DoF).Data + ts.noise.Data;
        end

        %%% PSD ----------------------------------------------------------------
        N = length(ts.tip.Data);
        window = hamming(N);

        [psd_data, freq_data] = utils.deepstructfun(...
            @(x) pwelch(x, window, [], N, Fs_sim), ...
            sim_data);

        % All freq_data are same
        freq_data = freq_data.tip.data.disturbance;

        %%% RMS of signal ------------------------------------------------------
        freq_range = [0, Fs_sim/2];

        rms_data(i_extra_space) = utils.deepstructfun(...
            @(x) sqrt(bandpower(x, freq_data, freq_range, 'psd')), ...
            psd_data);
        
        if print_progress
            send(progressQueue, 1);
        end
    end

    %% Helper Functions --------------------------------------------------------
    function updateProgress(increment)
        count = count + increment;
        if count == 0
            fprintf("Current Environment\n")
            fprintf("\t%-6s = %6d [%s] \n", ...
                "Fs"     , Fs        , "Hz", ...
                "Photon" , n_photons , "photons" ...
            );
            fprintf("Current Simulation: ");
        else
            fprintf(repmat('\b', 1, 12 + 43));
        end
        frac_completed = floor(count / n_extra_space * 40);
        fprintf("%4d / %-4d\n", floor(count), n_extra_space);
        fprintf("|%-40s|\n", ...
            sprintf("%s", repmat(char(8226), frac_completed, 1)) ...
        );
    end
end