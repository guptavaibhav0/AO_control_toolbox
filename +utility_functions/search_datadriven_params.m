function search_datadriven_params(Fs, n_photons, options)
%search_datadriven_params Parameter search for data-driven controller
% 
%   search_datadriven_params(Fs, n_photons) gives the rms value of the error for
%   all hyperparameters of data-driven controller. The flux noise is determined
%   by the `n_photons` recieved per timestep. Controller frequency is given by
%   `Fs` Hz.
% 
%   search_datadriven_params(___, name, value) specifies the optional and the
%   simulation parameters.
%
%   Name-Value Pair Arguments:
%     |------------------|-----------------------------------------------------|
%     | Name             | Description                                         |
%     |------------------|-----------------------------------------------------|
%     | readout_noise    | If detector has a readout noise                     |
%     |                  |   Default: false                                    |
%     |------------------|-----------------------------------------------------|
%     | save_data        | To save generated PSD data in the file              |
%     |                  | `optimise_datadriven/%d_Hz/%d_photons.mat`          |
%     |                  |   Default: true                                     |
%     |------------------|-----------------------------------------------------|
%     | print_progress   | To print the current progress                       |
%     |                  |   Default: true                                     |
%     |------------------|-----------------------------------------------------|
%     | sound_alarm      | To sound the alarm at the end of the run            |
%     |                  |   Default: false                                    |
%     |------------------|-----------------------------------------------------|
%     | solver           | Solver to use for data-driven design                |
%     |                  |   Default: "fusion"                                 |
%     |------------------|-----------------------------------------------------|
%     | n_bandwidth_grid | Number of grid points for `bandwidth` search        |
%     |                  |   Default: 15                                       |
%     |------------------|-----------------------------------------------------|
%     | n_alpha_grid     | Number of grid points for `alpha` search            |
%     |                  |   Default: 16                                       |
%     |------------------|-----------------------------------------------------|
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

    arguments
        Fs                       (1, 1) double   = 400      % [Hz]
        n_photons                (1, 1) double   = 1600     % [photons]
        options.readout_noise    (1, 1) logical  = false
        options.save_data        (1, 1) logical  = true
        options.print_progress   (1, 1) logical	 = true
        options.sound_alarm      (1, 1) logical	 = false
        options.solver           (1, 1) string   = "fusion"
        options.n_bandwidth_grid (1, 1) double   = 11
        options.n_alpha_grid	 (1, 1) double   = 21
        options.use_parallel	 (1, 1) logical  = false
    end

    %% Basic Specifications ----------------------------------------------------
    if options.readout_noise
        datafolder = fullfile("data", "readout");
    else
        datafolder = fullfile("data", "no_readout");
    end

    % Save file for search results
    parent_folder = fullfile( ...
        datafolder, ...
        "optimise_datadriven", ...
        sprintf("%04d_Hz", Fs));
    save_filename = fullfile( ...
        parent_folder, ...
        sprintf("%04d_photons.mat", n_photons));
    
    if isfile(save_filename)
        % If already done, skip!
        return
    end

    % Simulation frequency [Hz]
    Fs_sim = Fs;

    % Communication/Calculation Lag [s]
    tau_lag = 0.4e-3;
    
    % Instrument Noise File
    instrument_filename = fullfile("data", "vibrationNRCIMJun2018ForGupta.fits");
    instrument_Fs = 800;      % Sampling frequency for Instrument Noise [Hz]
    
    % Max. simulation time [s]
    max_T_sim = 100;
    
    %% Parameter Space ---------------------------------------------------------
    integrator_params = load(fullfile(...
        datafolder, ...
        "optimise_integrator", ...
        "optimised_params.mat"));

    gain_space = 0.5; %integrator_params.get_optimal_gain.tip(Fs, n_photons);
    
    order_space     = 5;
    bandwidth_space = linspace(50, 150, options.n_bandwidth_grid);
    alpha_space     = linspace(50, 250, options.n_alpha_grid);
    
    [gain_grid, order_grid, bandwidth_grid, alpha_grid] = ...
        ndgrid(gain_space, order_space, bandwidth_space, alpha_space);
    
    param_space = [ ...
        gain_grid(:)     , ...
        order_grid(:)    , ...
        bandwidth_grid(:), ...
        alpha_grid(:)      ...
    ];
    n_param_space = size(param_space, 1);
        
    %% TMT Disturbance Model ---------------------------------------------------
    TMT_disturbance = TMT_disturbance_model();
    TMT_disturbance.w = logspace(-4, pi, 1000) * instrument_Fs;
    TMT_disturbance.Fs_sim = Fs_sim;
    TMT_disturbance.add_instrument_disturbance(instrument_filename, instrument_Fs);

    ts = struct();
    ts.tip = TMT_disturbance.get_ts("tip", max_T_sim);
    ts.tilt = TMT_disturbance.get_ts("tilt", max_T_sim);
    ts.noise = utils.get_white_noise(...
        utils.get_flux_noise_rms(n_photons, ...
            "readout_noise", options.readout_noise), ...
        ts.tip.Time(end), ...
        Fs_sim ...
    );

    %% Loop over parameter space -----------------------------------------------
    print_progress = options.print_progress;
    readout_noise = options.readout_noise;
    solver = options.solver;
    
    empty_cells = cell(n_param_space, 1);
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

    loop_start = tic;
    % Internally both loops performs same action
    if options.use_parallel
        parfor ii = 1:n_param_space
            param = param_space(ii, :);

            %%% Controllers
            controllers = struct();
            for DoF = ["tip", "tilt"]
                for type = "data"
                    controllers.(DoF).(type) = VibrationController(type, ...
                        "Fs"     , Fs, ...
                        "tau_lag", tau_lag, ...
                        "solver" , solver ...
                    );
                    controllers.(DoF).(type).set_disturbance_frd(...
                        TMT_disturbance.get_frd_model(DoF));
                    controllers.(DoF).(type).set_flux_noise_rms( ...
                        utils.get_flux_noise_rms(n_photons, ...
                            "readout_noise", readout_noise));
                    controllers.(DoF).(type).update_parameter(...
                        "gain"      , param(1), ...
                        "order"     , param(2), ...
                        "bandwidth" , param(3), ...
                        "alpha"     , param(4) ...
                    );
                    controllers.(DoF).(type).design(false);
                end
            end

            %%% Simulators
            simulators = struct();

            for DoF = ["tip", "tilt"]
                for type = "data"
                    simulators.(DoF).(type) = Simulator(Fs, tau_lag);
                    simulators.(DoF).(type).set_controller(controllers.(DoF).(type));
                    simulators.(DoF).(type).run(ts.(DoF), ts.noise);
                end
            end

            %%% Simulation Data Results
            sim_data = utils.deepstructfun( ...
                @(x) x.result, ...
                simulators);

            for DoF = ["tip", "tilt"]
                sim_data.(DoF).raw.disturbance = ts.(DoF).Data;
                sim_data.(DoF).raw.noise = ts.noise.Data;
                sim_data.(DoF).raw.total = ts.(DoF).Data + ts.noise.Data;
            end

            %%% PSD
            N = length(ts.tip.Data);
            window = hamming(N);

            [psd_data, freq_data] = utils.deepstructfun(...
                @(x) pwelch(x, window, [], N, Fs_sim), ...
                sim_data);

            % All freq_data are same
            freq_data = freq_data.tip.raw.disturbance;

            %%% RMS of signal
            freq_range = [0, Fs_sim/2];

            rms_data(ii) = utils.deepstructfun(...
                @(x) sqrt(bandpower(x, freq_data, freq_range, 'psd')), ...
                psd_data);

            if print_progress
                send(progressQueue, 1);
            end
        end
    else
        for ii = 1:n_param_space
            param = param_space(ii, :);

            %%% Controllers
            controllers = struct();
            for DoF = ["tip", "tilt"]
                for type = "data"
                    controllers.(DoF).(type) = VibrationController(type, ...
                        "Fs"     , Fs, ...
                        "tau_lag", tau_lag, ...
                        "solver" , solver ...
                    );
                    controllers.(DoF).(type).set_disturbance_frd(...
                        TMT_disturbance.get_frd_model(DoF));
                    controllers.(DoF).(type).set_flux_noise_rms( ...
                        utils.get_flux_noise_rms(n_photons, ...
                            "readout_noise", readout_noise));
                    controllers.(DoF).(type).update_parameter(...
                        "gain"      , param(1), ...
                        "order"     , param(2), ...
                        "bandwidth" , param(3), ...
                        "alpha"     , param(4) ...
                    );
                    controllers.(DoF).(type).design(false);
                end
            end

            %%% Simulators
            simulators = struct();

            for DoF = ["tip", "tilt"]
                for type = "data"
                    simulators.(DoF).(type) = Simulator(Fs, tau_lag);
                    simulators.(DoF).(type).set_controller(controllers.(DoF).(type));
                    simulators.(DoF).(type).run(ts.(DoF), ts.noise);
                end
            end

            %%% Simulation Data Results
            sim_data = utils.deepstructfun( ...
                @(x) x.result, ...
                simulators);

            for DoF = ["tip", "tilt"]
                sim_data.(DoF).raw.disturbance = ts.(DoF).Data;
                sim_data.(DoF).raw.noise = ts.noise.Data;
                sim_data.(DoF).raw.total = ts.(DoF).Data + ts.noise.Data;
            end

            %%% PSD
            N = length(ts.tip.Data);
            window = hamming(N);

            [psd_data, freq_data] = utils.deepstructfun(...
                @(x) pwelch(x, window, [], N, Fs_sim), ...
                sim_data);

            % All freq_data are same
            freq_data = freq_data.tip.raw.disturbance;

            %%% RMS of signal
            freq_range = [0, Fs_sim/2];

            rms_data(ii) = utils.deepstructfun(...
                @(x) sqrt(bandpower(x, freq_data, freq_range, 'psd')), ...
                psd_data);

            if print_progress
                send(progressQueue, 1);
            end
        end
    end
    toc(loop_start);

    %% Save Data ---------------------------------------------------------------
    if options.save_data
        if ~isfolder(parent_folder)
            mkdir(parent_folder)
        end
        save(save_filename, "rms_data", "param_space");
    end

    %% Finish alarm ------------------------------------------------------------
    if options.sound_alarm
        alarm = load("handel"); sound(alarm.y, alarm.Fs);
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
        frac_completed = floor(count / n_param_space * 40);
        fprintf("%4d / %-4d\n", floor(count), n_param_space);
        fprintf("|%-40s|\n", ...
            sprintf("%s", repmat(char(8226), frac_completed, 1)) ...
        );
    end

end