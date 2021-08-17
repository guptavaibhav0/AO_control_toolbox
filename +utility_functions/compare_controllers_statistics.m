function compare_controllers_statistics(Fs, n_photons, n_repeat, options)
%compare_controllers_statistics Generate statistical data of residual RMS
% 
%	compare_controllers_statistics(Fs, n_photons, n_repeat) generates residual
%   RMS values for `n_repeats` for the flux noise defined by `n_photons` and
%   controller frequency of `Fs` Hz.
%
%   compare_controllers_statistics(___, name, value) specifies the optional and
%   plotting parameters.
%
%   Name-Value Pair Arguments:
%     |----------------|-------------------------------------------------------|
%     | Name           | Description                                           |
%     |----------------|-------------------------------------------------------|
%     | readout_noise  | If detector has a readout noise                       |
%     |                |   Default: false                                      |
%     |----------------|-------------------------------------------------------|
%     | save_data      | To save generated PSD data in the file                |
%     |                | `data/optimise_datadriven/%d_Hz/%d_photons.mat`       |
%     |                |   Default: true                                       |
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

    arguments
        Fs                      (1, 1) double   = 400
        n_photons               (1, 1) double   = 1600
        n_repeat                (1, 1) double   = 100
        options.readout_noise   (1, 1) logical  = false
        options.save_data       (1, 1) logical  = true
        options.print_progress  (1, 1) logical	= true
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
        "compare_controller_statistics", ...
        sprintf("%04d_Hz", Fs));
    save_filename = fullfile( ...
        parent_folder, ...
        sprintf("%04d_photons.mat", n_photons));

    if isfile(save_filename)
        % If already done, skip!
        return
    end

    % Communication/Calculation Lag [s]
    tau_lag = 0.4e-3;

    % Instrument Disturbance File
    instrument_filename = fullfile(datafolder, ...
        "vibrationNRCIMJun2018ForGupta.fits");
    instrument_Fs = 800;      % Sampling frequency for Instrument Noise [Hz]

    % Max. simulation time [s]
    max_T_sim = 100;

    % Simulation frequency [Hz]
    Fs_sim = Fs;

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

    %% Disturbance Model -------------------------------------------------------
    TMT_disturbance = TMT_disturbance_model();
    TMT_disturbance.w = logspace(-4, pi, 1000) * instrument_Fs;
    TMT_disturbance.Fs_sim = Fs_sim;
    TMT_disturbance.add_instrument_disturbance(...
        instrument_filename, instrument_Fs);

    %% Controllers -------------------------------------------------------------
    controllers = struct();

    for DoF = ["tip", "tilt"]
        for type = ["int", "data"]
            controllers.(DoF).(type) = VibrationController(type, ...
                "Fs"     , Fs     , ...
                "tau_lag", tau_lag, ...
                "solver" , options.solver   ...
            );
            controllers.(DoF).(type).set_disturbance_frd( ...
                TMT_disturbance.get_frd_model(DoF) ...
            );
            controllers.(DoF).(type).set_flux_noise_rms( ...
                utils.get_flux_noise_rms(n_photons, ...
                    "readout_noise", options.readout_noise) ...
            );
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

    %% Repeat Simulations ------------------------------------------------------
    print_progress = options.print_progress;
    readout_noise = options.readout_noise;

    empty_cells = cell(n_repeat, 1);
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

    parfor i_repeat = 1:n_repeat
        %%% Time series --------------------------------------------------------   
        ts = struct();
        ts.tip = TMT_disturbance.get_ts("tip", max_T_sim);
        ts.tilt = TMT_disturbance.get_ts("tilt", max_T_sim);
        ts.noise = utils.get_white_noise(...
            utils.get_flux_noise_rms(n_photons, ...
                "readout_noise", readout_noise), ...
            ts.tip.Time(end), ...
            Fs_sim ...
        );

        %%% Simulations --------------------------------------------------------
        simulators = struct();

        for DoF = ["tip", "tilt"]
            for type = ["int", "data"]
                simulators.(DoF).(type) = Simulator(Fs, tau_lag);
                simulators.(DoF).(type).set_controller(controllers.(DoF).(type));
                simulators.(DoF).(type).run(ts.(DoF), ts.noise);
            end
        end

        %%% Simulation Results -------------------------------------------------
        sim_data = utils.deepstructfun( ...
            @(x) x.result, ...
            simulators);

        for DoF = ["tip", "tilt"]
            sim_data.(DoF).raw.disturbance = ts.(DoF).Data ;
            sim_data.(DoF).raw.noise = ts.noise.Data;
            sim_data.(DoF).raw.total = ts.(DoF).Data + ts.noise.Data;
        end

        %%% Get PSD data -------------------------------------------------------
        N = length(ts.tip.Data);
        window = hamming(N);

        [psd_data, freq_data] = utils.deepstructfun(...
            @(x) pwelch(x, window, [], N, Fs_sim), ...
            sim_data);

        % All freq_data are same
        freq_data = freq_data.tip.data.disturbance;

        %%% RMS values of the error --------------------------------------------
        freq_range = [0, Fs_sim/2];

        rms_data(i_repeat) = utils.deepstructfun(...
            @(x) sqrt(bandpower(x, freq_data, freq_range, 'psd')), ...
            psd_data);

        if print_progress
            send(progressQueue, 1);
        end
    end

    %% Save RMS Data -----------------------------------------------------------
    if options.save_data
        if ~isfolder(parent_folder)
            mkdir(parent_folder)
        end
        save(save_filename, "rms_data");
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
        frac_completed = floor(count / n_repeat * 40);
        fprintf("%4d / %-4d\n", floor(count), n_repeat);
        fprintf("|%-40s|\n", ...
            sprintf("%s", repmat(char(8226), frac_completed, 1)) ...
        );
    end
end