function psd_data = disturbance_variations_psd(options)
%disturbance_variations_psd Calculates the disturbance PSD for one night sky
% 
%   psd_data = disturbance_variations_psd(name, value) gives the PSD for a
%   single night of observation.
% 
%   Name-Value Pair Arguments:
%     |----------------|-------------------------------------------------------|
%     | Name           | Description                                           |
%     |----------------|-------------------------------------------------------|
%     | plot           | To plot the graphs for disturbance variations         |
%     |                |   Default: true                                       |
%     |----------------|-------------------------------------------------------|
%     | save_plot      | Autosave the graphs for disturbance variations        |
%     |                |   Default: true                                       |
%     |----------------|-------------------------------------------------------|
%     | save_data      | To save generated PSD data in the file                |
%     |                | `data/disturbance_psd.mat`                            |
%     |                |   Default: true                                       |
%     |----------------|-------------------------------------------------------|
%     | print_progress | To print the current progress                         |
%     |                |   Default: true                                       |
%     |----------------|-------------------------------------------------------|
%     | sound_alarm    | To sound the alarm at the end of the run              |
%     |                |   Default: false                                      |
%     |----------------|-------------------------------------------------------|
%
%   Other specifications for the simulations and the controllers specified 
%   in the `Basic Specifications` section:
%     |---------------------|--------------------------------------------------|
%     | Variable Name       | Description                                      |
%     |---------------------|--------------------------------------------------|
%     | instrument_filename | '.fit' file containing instrument disturbance as |
%     |                     | a timeseries                                     |
%     |---------------------|--------------------------------------------------|
%     | instrument_Fs       | Sampling frequency of instrument disturbance [Hz]|
%     |---------------------|--------------------------------------------------|
% 

    arguments
        options.plot            (1, 1) logical = true
        options.save_plot       (1, 1) logical = true
        options.save_data       (1, 1) logical = true
        options.print_progress  (1, 1) logical = true
        options.sound_alarm     (1, 1) logical = false
    end

    %% Basic Specifications ----------------------------------------------------
    
    % Plot folder
    options.plot_folder = fullfile("figures", "varying_disturbance_psd");

    % Save file for optimised results
    parent_folder = fullfile("data");
    save_filename = fullfile(parent_folder, "varying_disturbance_psd.mat");
    
    % Instrument Noise File
    instrument_filename = fullfile("data", "vibrationNRCIMJun2018ForGupta.fits");
    instrument_Fs = 800;      % Sampling frequency for Instrument Noise [Hz]

    freq_rad = logspace(-4, pi, 1000) * instrument_Fs;

    %% Variations to consider --------------------------------------------------
    variations = struct();
    variations.v = 5:5:50;
    variations.r0 = [0.08, 0.15, 0.30];
    variations.L0 = 15:5:40;
    variations.instrument_gain = [1, 2, 5, 10];
    variations.percentile = [50, 75, 85, 95];

    variations_grid = cell(5, 1);
    [variations_grid{:}] = ndgrid(...
        variations.v, ...
        variations.r0, ...
        variations.L0, ...
        variations.instrument_gain, ...
        variations.percentile);

    variations_space = [...
        variations_grid{1}(:), ...
        variations_grid{2}(:), ...
        variations_grid{3}(:), ...
        variations_grid{4}(:), ...
        variations_grid{5}(:)  ...
    ];

    %% Loop over variations space ----------------------------------------------
    if isfile(save_filename)
        load(save_filename, ...
            "freq_rad", ...
            "instrument_Fs", ...
            "psd_data", ...
            "variations_space");
        n_variations_space = size(variations_space, 1);
    else
        print_progress = options.print_progress;
        n_variations_space = size(variations_space, 1);

        empty_cells = cell(n_variations_space, 1);
        psd_data = struct(...
            "psd_instrument_tip" , empty_cells, ...
            "psd_instrument_tilt", empty_cells, ...
            "psd_atmospheric"    , empty_cells, ...
            "psd_windshake"      , empty_cells, ...
            "psd"                , empty_cells, ...
            "psd_tip"            , empty_cells, ...
            "psd_tilt"           , empty_cells  ...
        );

        if print_progress
            count = 0;
            progressQueue = parallel.pool.DataQueue;
            afterEach(progressQueue, @updateProgress);
            send(progressQueue, 0);
        end

        % Generate PSDs in parallel loop
        parfor i_variations_space = 1:n_variations_space
            variations = variations_space(i_variations_space, :);

            % TMT Disturbance
            TMT_disturbance = TMT_disturbance_model();
            TMT_disturbance.w = freq_rad;
            TMT_disturbance.add_instrument_disturbance(instrument_filename, ...
                instrument_Fs);

            TMT_disturbance.v = variations(1);
            TMT_disturbance.r0 = variations(2);
            TMT_disturbance.L0 = variations(3);
            TMT_disturbance.instrument_gain = variations(4);
            TMT_disturbance.percentile = variations(5);

            % PSDs
            psd_data(i_variations_space) = struct( ...
                "psd_instrument_tip" , TMT_disturbance.psd_instrument_tip , ...
                "psd_instrument_tilt", TMT_disturbance.psd_instrument_tilt, ...
                "psd_atmospheric"    , TMT_disturbance.psd_atmospheric    , ...
                "psd_windshake"      , TMT_disturbance.psd_windshake      , ...
                "psd"                , TMT_disturbance.psd                , ...
                "psd_tip"            , TMT_disturbance.psd_tip            , ...
                "psd_tilt"           , TMT_disturbance.psd_tilt             ...
            );

            if print_progress
                send(progressQueue, 1);
            end
        end
    end
    
    %% Save Data ---------------------------------------------------------------
    if options.save_data        
        if ~isfolder(parent_folder)
            mkdir(parent_folder)
        end
        save(save_filename, ...
            "freq_rad", ...
            "instrument_Fs", ...
            "psd_data", ...
            "variations_space");
    end
    
    %% Plot --------------------------------------------------------------------
    if options.plot
        plot_helper_disturbance();
        plot_helper_disturbance_windshake();
        plot_helper_disturbance_instrument();
        plot_helper_flux_noise();
    end

    %% Finish alarm ------------------------------------------------------------
    if options.sound_alarm
        alarm = load("handel"); sound(alarm.y, alarm.Fs);
    end

    %% Helper Functions --------------------------------------------------------
    function updateProgress(increment)
        count = count + increment;
        if count == 0
            fprintf("Current Variation: ");
        else
            fprintf(repmat('\b', 1, 12 + 43));
        end
        frac_completed = floor(count / n_variations_space * 40);
        fprintf("%4d / %-4d\n", floor(count), n_variations_space);
        fprintf("|%-40s|\n", ...
            sprintf("%s", repmat(char(8226), frac_completed, 1)) ...
        );
    end

    function plot_helper_disturbance()
        min_variation = min(variations_space, [], 1);
        max_variation = max(variations_space, [], 1);

        get_var_pt = @(variation, idx) 0.1 + 0.7 * ...
            (variation(idx) - min_variation(idx)) ./ ...
            (max_variation(idx) - min_variation(idx));
        get_color = @(variation) get_var_pt(variation, [1, 2, 3, 5]);

        typeNames = struct(...
            "psd_atmospheric"    , "Distrubance due to atmosperic turbulence", ...
            "psd"                , "Distrubance due to external environment" , ...
            "psd_tip"            , "Total distrubance at Tip"                , ...
            "psd_tilt"           , "Total distrubance at Tilt"                 ...
        );
        types = string(fields(typeNames))';

        for type = types
            fig = figure();
            if options.save_plot
                fig.Renderer = "painters";
                fig.Units = "centimeters";
                fig.PaperSize = fig.Position(3:4);
                fig.PaperUnits = "normalized";
                fig.PaperPosition = [0, 0, 1, 1];
            end

            t = tiledlayout(1, 1, "TileSpacing", "compact");
            xlabel(t, "Freq [Hz]");
            ylabel(t, "Noise Power [mas^2 / Hz]");
            title(t, typeNames.(type));

            ax = nexttile();
            set(ax, 'XScale', 'log', 'YScale', 'log');
            hold on; box on; grid on;

            for i_variations = n_variations_space:-1:1
                variation = variations_space(i_variations, :);
                plot(freq_rad / 2 / pi, psd_data(i_variations).(type), ...
                    "LineWidth", 1, ...
                    "Color", get_color(variation));
            end

            xlim([1e-2, instrument_Fs/2]);

            if options.save_plot
                if ~isfolder(options.plot_folder)
                    mkdir(options.plot_folder)
                end
                plot_filename = fullfile( ...
                    options.plot_folder, ...
                    replace(type, "psd_", "") ...
                );
                print(fig, plot_filename, "-dpng", "-painters", "-r300");
                print(fig, plot_filename, "-dpdf", "-painters");

                fig.Color = "none";
                fig.InvertHardcopy = "off";
                print(fig, plot_filename, "-dsvg", "-painters");
                close(fig);
            end
        end
    end

    function plot_helper_disturbance_windshake()
        windshake_variations = unique(variations_space(:, 5));
        
        n_windshake_variation = length(windshake_variations);
        get_color = [ ...
            "#0072BD";
            "#D95319";
            "#EDB120";
            "#7E2F8E";
        ];

        typeNames = struct(...
            "psd_windshake"      , "Distrubance due to telescope windshake"  ...
        );
        types = string(fields(typeNames))';

        for type = types
            fig = figure();
            if options.save_plot
                fig.Renderer = "painters";
                fig.Units = "centimeters";
                fig.PaperSize = fig.Position(3:4);
                fig.PaperUnits = "normalized";
                fig.PaperPosition = [0, 0, 1, 1];
            end

            t = tiledlayout(1, 1, "TileSpacing", "compact");
            xlabel(t, "Freq [Hz]");
            ylabel(t, "Noise Power [mas^2 / Hz]");
            title(t, typeNames.(type));

            ax = nexttile();
            set(ax, 'XScale', 'log', 'YScale', 'log');
            hold on; box on; grid on;

            for i_variations = 1:n_windshake_variation
                i_variation_space = find( ...
                    variations_space(:, 5) == windshake_variations(i_variations), ...
                    1);
                plot(freq_rad / 2 / pi, psd_data(i_variation_space).(type), ...
                    "LineWidth", 2, ...
                    "Color", get_color(i_variations));
            end
            
            h_leg = legend(...
                arrayfun(@(x) sprintf("%d", x), windshake_variations));
            title(h_leg, "Percentile");

            xlim([1e-2, instrument_Fs/2]);

            if options.save_plot
                if ~isfolder(options.plot_folder)
                    mkdir(options.plot_folder)
                end
                plot_filename = fullfile( ...
                    options.plot_folder, ...
                    replace(type, "psd_", "") ...
                );
                print(fig, plot_filename, "-dpng", "-painters", "-r300");
                print(fig, plot_filename, "-dpdf", "-painters");

                fig.Color = "none";
                fig.InvertHardcopy = "off";
                print(fig, plot_filename, "-dsvg", "-painters");
                close(fig);
            end
        end
    end

    function plot_helper_disturbance_instrument()
        instrument_variations = unique(variations_space(:, 4));
        
        n_instrument_variation = length(instrument_variations);
        get_color = [ ...
            "#0072BD";
            "#D95319";
            "#EDB120";
            "#7E2F8E";
        ];

        typeNames = struct(...
            "psd_instrument_tip" , "Distrubance at Tip due to vibration", ...
            "psd_instrument_tilt", "Distrubance at Tilt due to vibration" ...
        );
        types = string(fields(typeNames))';

        for type = types
            fig = figure();
            if options.save_plot
                fig.Renderer = "painters";
                fig.Units = "centimeters";
                fig.PaperSize = fig.Position(3:4);
                fig.PaperUnits = "normalized";
                fig.PaperPosition = [0, 0, 1, 1];
            end

            t = tiledlayout(1, 1, "TileSpacing", "compact");
            xlabel(t, "Freq [Hz]");
            ylabel(t, "Noise Power [mas^2 / Hz]");
            title(t, typeNames.(type));

            ax = nexttile();
            set(ax, 'XScale', 'log', 'YScale', 'log');
            hold on; box on; grid on;

            for i_variations = 1:n_instrument_variation
                i_variation_space = find( ...
                    variations_space(:, 4) == instrument_variations(i_variations), ...
                    1);
                plot(freq_rad / 2 / pi, psd_data(i_variation_space).(type), ...
                    "LineWidth", 2, ...
                    "Color", get_color(i_variations));
            end
            
            h_leg = legend(...
                arrayfun(@(x) sprintf("\\times %2d", x), instrument_variations));
            title(h_leg, "Vibration Gain");

            xlim([1e-2, instrument_Fs/2]);

            if options.save_plot
                if ~isfolder(options.plot_folder)
                    mkdir(options.plot_folder)
                end
                plot_filename = fullfile( ...
                    options.plot_folder, ...
                    replace(type, "psd_", "") ...
                );
                print(fig, plot_filename, "-dpng", "-painters", "-r300");
                print(fig, plot_filename, "-dpdf", "-painters");

                fig.Color = "none";
                fig.InvertHardcopy = "off";
                print(fig, plot_filename, "-dsvg", "-painters");
                close(fig);
            end
        end
    end

    function plot_helper_flux_noise()
        photon_space = logspace(log10(16), log10(6400), 100);

        fig = figure();
        if options.save_plot
            fig.Renderer = "painters";
            fig.Units = "centimeters";
            fig.PaperSize = fig.Position(3:4);
            fig.PaperUnits = "normalized";
            fig.PaperPosition = [0, 0, 1, 1];
        end

        t = tiledlayout(1, 1, "TileSpacing", "compact");
        xlabel(t, "Number of photons per timestep");
        ylabel(t, "Noise RMS [mas]");
        title(t, "Flux Noise (Measurement Noise)");

        ax = nexttile();
        set(ax, 'XScale', 'log', 'YScale', 'log');
        hold on; box on; grid on;

        rms_space_readout = utils.get_flux_noise_rms(photon_space, ...
            "readout_noise", true);
        rms_space_no_readout = utils.get_flux_noise_rms(photon_space, ...
            "readout_noise", false);
        
        l1 = plot(photon_space, rms_space_no_readout, ...
            "LineWidth", 2, ...
            "Color", "#0072BD");
        l2 = plot(photon_space, rms_space_readout, ...
            "LineWidth", 2, ...
            "Color", "#D95319");

        h_leg = legend([l1, l2], ...
            "$0 ~ e^{-} ~ \textrm{per pixel}$", ...
            "$3 ~ e^{-} ~ \textrm{per pixel}$", ...
            "FontSize", 12, ...
            "Interpreter", "latex", ...
            "Orientation", "vertical", ...
            "Location", "northeast");
        title(h_leg, "\textrm{Readout Noise Level}")

        xlim([min(photon_space), max(photon_space)]);

        if options.save_plot
            if ~isfolder(options.plot_folder)
                mkdir(options.plot_folder)
            end
            plot_filename = fullfile(options.plot_folder, "flux_noise");

            print(fig, plot_filename, "-dpng", "-painters", "-r300");
            print(fig, plot_filename, "-dpdf", "-painters");

            fig.Color = "none";
            fig.InvertHardcopy = "off";
            print(fig, plot_filename, "-dsvg", "-painters");
            close(fig);
        end
    end
end
