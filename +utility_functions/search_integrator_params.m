function search_integrator_params(Fs, n_photons, options)
%search_integrator_params Parameter search for integrator controller
% 
%   search_integrator_params(Fs, n_photons) gives the rms value of the error for
%   all hyperparameters of integrator controller. The flux noise is determined
%   by the `n_photons` recieved per timestep. Controller frequency is given by 
%   `Fs` Hz.
% 
%   search_integrator_params(___, name, value) specifies the optional and the
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
%     | n_gain_grid      | Number of grid points for `gain` search             |
%     |                  |   Default: 1000                                     |
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
        Fs                      (1, 1) double   = 400
        n_photons               (1, 1) double   = 1600
        options.readout_noise   (1, 1) logical  = false
        options.save_data       (1, 1) logical  = true
        options.print_progress  (1, 1) logical	= true
        options.sound_alarm     (1, 1) logical	= false
        options.n_gain_grid     (1, 1) double   = 1000
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
        "optimise_integrator", ...
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
    max_gain_controller = 0.63;
    gain_grid = linspace(0.05, max_gain_controller, options.n_gain_grid);
    param_space = gain_grid(:);
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
    
    parfor ii = 1:n_param_space
        %%% Controllers
        controllers = struct();
        for DoF = ["tip", "tilt"]
            for type = "int"
                controllers.(DoF).(type) = VibrationController(type, ...
                    "Fs"     , Fs, ...
                    "tau_lag", tau_lag ...
                );
                controllers.(DoF).(type).set_disturbance_frd(...
                    TMT_disturbance.get_frd_model(DoF));
                controllers.(DoF).(type).set_flux_noise_rms( ...
                    utils.get_flux_noise_rms(n_photons, ...
                        "readout_noise", readout_noise));
                controllers.(DoF).(type).update_parameter(...
                    "gain", param_space(ii));
                controllers.(DoF).(type).design();
            end
        end

        %%% Simulators
        simulators = struct();

        for DoF = ["tip", "tilt"]
            for type = "int"
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

    %% Save Data ---------------------------------------------------------------
    if options.save_data
        if ~isfolder(parent_folder)
            mkdir(parent_folder)
        end
        save(save_filename, "rms_data", "gain_grid");
    end

    %% Helper Functions --------------------------------------------------------
    function updateProgress(increment)
        count = count + increment;
        if count == 0
            fprintf("Current Environment\n")
            fprintf("\t%-5s = %4d [%s] \n", ...
                "Fs"     , Fs        , "Hz", ...
                "Photon" , n_photons , "photons" ...
            );
            fprintf("Current Simulation: %4d / %-4d\n", count, n_param_space);
            fprintf("|%-40s|\n",  ...
                sprintf("%s", repmat(char(8226), 0 , 1)) ...
            );
        else
            fprintf(repmat('\b', 1, 12 + 43));
            fprintf("%4d / %-4d\n", ...
                count, ...
                n_param_space);
            frac_completed = floor(count/n_param_space * 40);
            fprintf("|%-40s|\n", ...
                sprintf("%s", repmat(char(8226), frac_completed, 1)) ...
            );
        end
    end

end