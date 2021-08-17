function varying_lag(Fs, n_photons, options)
    arguments
        Fs                      (1, 1) double   = 400
        n_photons               (1, 1) double   = 1600
        options.readout_noise   (1, 1) logical  = true
        options.save_data       (1, 1) logical  = true
        options.print_progress  (1, 1) logical	= true
        options.sound_alarm     (1, 1) logical	= false
        options.solver          (1, 1) string   = "fusion"
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
        "varying_lag", ...
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
    
    % Nominal Communication/Calculation Lag [s]
    tau_lag = 0.4e-3;
    
    % Instrument Noise File
    instrument_filename = fullfile("data", "vibrationNRCIMJun2018ForGupta.fits");
    instrument_Fs = 800;      % Sampling frequency for Instrument Noise [Hz]
    
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

    %% Variations in lag -------------------------------------------------------
    variations_space = linspace(0, 2/Fs, 101).';
    n_variations_space = size(variations_space, 1);

    %% Nominal TMT Disturbance Model -------------------------------------------
    TMT_disturbance = TMT_disturbance_model();
    TMT_disturbance.w = logspace(-4, pi, 1000) * instrument_Fs;
    TMT_disturbance.Fs_sim = Fs_sim;
    TMT_disturbance.add_instrument_disturbance(instrument_filename, instrument_Fs);
    
    ts = struct();
    ts.tip = TMT_disturbance.get_ts("tip", max_T_sim);
    ts.tilt = TMT_disturbance.get_ts("tilt", max_T_sim);
    ts.noise = utils.get_white_noise(...
        utils.get_flux_noise_rms(n_photons), ...
        ts.tip.Time(end), ...
        Fs_sim ...
    );

    %% Design controllers ------------------------------------------------------
    controllers = struct();
    for DoF = ["tip", "tilt"]
        for type = ["int", "data"]
            controllers.(DoF).(type) = VibrationController(type, ...
                "Fs"     , Fs            , ...
                "tau_lag", tau_lag       , ...
                "solver" , options.solver  ...
            );
            controllers.(DoF).(type).set_disturbance_frd( ...
                TMT_disturbance.get_frd_model(DoF));
            controllers.(DoF).(type).set_flux_noise_rms( ...
                utils.get_flux_noise_rms(n_photons));
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
            controllers.(DoF).(type).design();
        end
    end

    %% Loop over variations space ----------------------------------------------
    print_progress = options.print_progress;
    n_variations_space = size(variations_space, 1);
    
    empty_cells = cell(n_variations_space, 1);
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

    parfor i_variations_space = 1:n_variations_space
        variations = variations_space(i_variations_space, :);
        tmp_tau_lag = variations(1);

        %%% Simulators
        simulators = struct();
        for DoF = ["tip", "tilt"]
            for type = ["int", "data"]
                simulators.(DoF).(type) = Simulator(Fs, tmp_tau_lag);
                simulators.(DoF).(type).set_controller(...
                    controllers.(DoF).(type));
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

        %% PSD 
        N = length(ts.tip.Data);
        window = hamming(N);

        [psd_data, freq_data] = utils.deepstructfun(...
            @(x) pwelch(x, window, [], N, Fs_sim), ...
            sim_data);

        % All freq_data are same
        freq_data = freq_data.tip.data.disturbance;

        %% RMS of signal
        freq_range = [0, Fs_sim/2];

        rms_data(i_variations_space) = utils.deepstructfun(...
            @(x) sqrt(bandpower(x, freq_data, freq_range, 'psd')), ...
            psd_data);
        
        if print_progress
            send(progressQueue, 1);
        end
    end

    %% Save Data ---------------------------------------------------------------
    if options.save_data
        if ~isfolder(parent_folder)
            mkdir(parent_folder)
        end
        save(save_filename, ...
            "rms_data", ...
            "variations_space", ...
            "tau_lag");
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
        frac_completed = floor(count / n_variations_space * 40);
        fprintf("%4d / %-4d\n", floor(count), n_variations_space);
        fprintf("|%-40s|\n", ...
            sprintf("%s", repmat(char(8226), frac_completed, 1)) ...
        );
    end
end