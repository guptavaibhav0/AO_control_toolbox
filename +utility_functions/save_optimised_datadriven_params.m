function save_optimised_datadriven_params(options)
%save_optimised_datadriven_params Optimised datadriven controller parameters
% 
%   save_optimised_integrator_params(name, value) specifies the optional and the
%   plotting parameters.
%
%   Name-Value Pair Arguments:
%     |----------------|-------------------------------------------------------|
%     | Name           | Description                                           |
%     |----------------|-------------------------------------------------------|
%     | readout_noise  | If detector has a readout noise                       |
%     |                |   Default: false                                      |
%     |----------------|-------------------------------------------------------|
%     | same_bandwidth | Same desired bandwidth for all flux values            |
%     |                |   Default: true                                       |
%     |----------------|-------------------------------------------------------|
%     | plot           | To plot the graphs for optimisation                   |
%     |                |   Default: true                                       |
%     |----------------|-------------------------------------------------------|
%     | save_plot      | Autosave the graphs for optimisation                  |
%     |                |   Default: true                                       |
%     |----------------|-------------------------------------------------------|
% 

    arguments
        options.readout_noise   (1, 1) logical = false
        options.same_bandwidth  (1, 1) logical = true
        options.plot            (1, 1) logical = true
        options.save_plot       (1, 1) logical = true
    end

    %% Basic Specifications ----------------------------------------------------
    if options.readout_noise
        datafolder = fullfile("data", "readout");
        plotfolder = fullfile("figures", "readout");
    else
        datafolder = fullfile("data", "no_readout");
        plotfolder = fullfile("figures", "no_readout");
    end
    
    options.plot_folder = fullfile( ...
        plotfolder, ...
        "optimise_datadriven"); 
    
    parent_folder = fullfile( ...
        datafolder, ...
        "optimise_datadriven"); 

    nd_grid_file = fullfile(parent_folder, "nd_grid.mat");

    % Save file for optimised results      
    params_file = fullfile(parent_folder, "optimised_params.mat");

    %% Extract n-d grid --------------------------------------------------------
    if isfile(nd_grid_file)
        % If n-d grid file is already available, use it.
        load(nd_grid_file, "unique_params", "params_grid", "rms_data");        
    else
        %%% Read Datafiles
        fs_folders = dir(fullfile( ...
            parent_folder, ...
            "*_Hz"));

        n_fs_folders = length(fs_folders);

        param_space = [];
        rms = [];
        for i_fs_folder = 1:n_fs_folders
            Fs = double(extractBefore(...
                string(fs_folders(i_fs_folder).name), ...
                "_Hz"));
            photon_files = dir(fullfile( ...
                parent_folder, ...
                sprintf("%04d_Hz", Fs), ...
                "*_photons.mat"));

            n = length(photon_files);

            for ii = 1:n
                data = load(fullfile(photon_files(ii).folder, photon_files(ii).name));
                flux = double(extractBefore(...
                    string(photon_files(ii).name), ...
                    "_photons.mat"));
                param_space = [param_space; ...
                    repmat(Fs, size(data.param_space, 1), 1), ...
                    repmat(flux, size(data.param_space, 1), 1), ...
                    data.param_space];
                rms = [rms; ...
                    arrayfun(@(x) get_rms_values(x, "tip"), data.rms_data), ...
                    arrayfun(@(x) get_rms_values(x, "tilt"), data.rms_data)];
            end
        end

        %%% Generate n-d array
        n_params = size(param_space, 2);
        unique_params = cell(1, n_params);
        for ii = 1:n_params
            unique_params{ii} = unique(param_space(:, ii));
        end
        [params_grid{1:n_params}] = ndgrid(unique_params{:});

        rms_data = struct();

        rms_data.tip = arrayfun(...
            @(varargin) rms(all(param_space == [varargin{:}], 2), 1), ...
            params_grid{:}, ...
            'UniformOutput', 0 ...
        );
        rms_data.tilt = arrayfun(...
            @(varargin) rms(all(param_space == [varargin{:}], 2), 2), ...
            params_grid{:}, ...
            'UniformOutput', 0 ...
        );

        %%% Save n-d grid
        save(nd_grid_file, "unique_params", "params_grid", "rms_data");
    end

    %% Get optimised parameters ------------------------------------------------
    
    % Integrator Gain Optimal Params
    integrator_params = load(fullfile(...
        datafolder, ...
        "optimise_integrator", ...
        "optimised_params.mat"));
    
    [Fs_space, photon_space] = unique_params{1:2};
    
    n_unique_params = cellfun(@length, unique_params);
    optimised_params = struct();
    get_optimal_params = struct();
    
    for DoF = ["tip", "tilt"]
        optimised_params.(DoF) = find_optimal_params(...
            rms_data.(DoF), n_unique_params, params_grid);
        if options.same_bandwidth            
            selected_bandwidth = round(mean( ...
                cellfun(@(x) x(3), optimised_params.(DoF)), ...
                2) / 10) * 10;
            
            selected_bandwidth_idx = arrayfun( ...
                @(x) find(x == unique_params{5}), ...
                selected_bandwidth);

            optimised_params.(DoF) = find_optimal_params_bandwidth(...
                rms_data.(DoF), n_unique_params, params_grid, ...
                selected_bandwidth_idx);
        end
        
        tmp = arrayfun(...
            @(idx) cellfun(@(x) x(idx), optimised_params.(DoF)), ...
            1:4, ...
            "UniformOutput", false);
        
        % Use mean for alpha per freq. point
        tmp{4} = repmat(mean(tmp{4}, 2), 1, n_unique_params(1));
        
        get_optimal_params.(DoF) = cellfun(...
            @(x) griddedInterpolant({Fs_space, photon_space}, x), ...
            tmp, ...
            "UniformOutput", false);
        
    end

    %% Save optimised parameters -----------------------------------------------    
    save(params_file, ...
        "optimised_params", ...
        "get_optimal_params", ...
        "Fs_space", ...
        "photon_space");

    %% Plot --------------------------------------------------------------------
    if options.plot
        for freq_idx = 1:n_unique_params(1)
            x_list = cell(1, n_unique_params(2));
            y_list = cell(1, n_unique_params(2));
            z_list = cell(1, n_unique_params(2));
            selected_bandwidth_list = cell(1, n_unique_params(2));
            specs_list = cell(1, n_unique_params(2));
            i_count = 1;
            for photon_idx = 1:n_unique_params(2)
                for gain_idx = 1:n_unique_params(3)
                    for order_idx = 1:n_unique_params(4)
                        idxs = {freq_idx, photon_idx, gain_idx, order_idx};
                        
                        x = squeeze(params_grid{5}(idxs{:}, :, :));
                        y = squeeze(params_grid{6}(idxs{:}, :, :));
                        z = cell2mat(squeeze(rms_data.tip(idxs{:}, :, :)));
                        
                        selected_bandwidth = ...
                            optimised_params.tip{freq_idx, photon_idx}(3);
                        
                        specs = {unique_params{1}(idxs{1}), ...
                            unique_params{2}(idxs{2}), ...
                            unique_params{3}(idxs{3}), ...
                            unique_params{4}(idxs{4})};
                        
                        if isempty(z)
                            % Skip if no data
                            continue;
                        end
                        x_list{i_count} = x;
                        y_list{i_count} = y;
                        z_list{i_count} = z;
                        selected_bandwidth_list{i_count} = selected_bandwidth;
                        specs_list{i_count} = specs;
                        i_count = i_count + 1;
                    end
                end
            end
            plot_helper(x_list, y_list, z_list, ...
                selected_bandwidth_list, specs_list, options);
            plot_helper_bandwidth(x_list, y_list, z_list, ...
                selected_bandwidth_list, specs_list, options);
        end
    end

    %% Helper functions --------------------------------------------------------
    function rms_value = get_rms_values(rms_data, DoF)
        if isempty(rms_data.(DoF))
            % If simulations are not run
            rms_value = inf;
        else
            % Extract the total residual for datadriven controller
            rms_value = rms_data.(DoF).data.total;
        end
    end

    function plot_helper_bandwidth(x, y, z, selected_bandwidth, specs, options)
        get_color = [ ...
            "#0072BD";
            "#D95319";
            "#EDB120";
            "#7E2F8E";
        ];

        fig = figure();
        if options.save_plot
            fig.Renderer = "painters";
            fig.Units = "centimeters";
            fig.PaperSize = fig.Position(3:4);
            fig.PaperUnits = "normalized";
            fig.PaperPosition = [0, 0, 1, 1];
        end

        n_plots = length(x);
        
        t = tiledlayout(1, 1, ...
            "TileSpacing", "Compact", ...
            "Padding", "Compact");
        title(t, sprintf("%d Hz", specs{1}{1}));
        
        ax = nexttile();
        hold on; box on; grid on;
        xlabel(ax, "Desired closed-loop bandwidth [Hz]");
        ylabel(ax, "Normalised Residual RMS");
        
        h_plot = [];
        for i_plots = 1:n_plots

            tmp_z = z{i_plots}.';
            S = (1 ./ (tmp_z + 1));
            [~, ~, lridge] = tfridge(S, y{i_plots}(1, :));
            
            tmp_min_z = tmp_z(lridge);
            tmp_min_z = tmp_min_z / max(tmp_min_z);

            h_plot(i_plots) = plot(x{i_plots}(:,1), tmp_min_z, ...
                "Color", get_color(i_plots), ...
                "LineWidth", 2);

            xline(selected_bandwidth{i_plots}, ...
                "Color", "#000000", ...
                "LineStyle", "--", ...
                "LineWidth", 2, ...
                "Label", "Selected bandwidth");
        end
        
        h_leg = legend(h_plot, ...
            cellfun(@(x) sprintf("%d", x{2}), specs), ...
            "Orientation", "h", ...
            "Location", "northoutside");
        title(h_leg, "No. of photons per timestep");
        h_leg.Layout.Tile = "south";

        if options.save_plot    
            if ~isfolder(options.plot_folder)
                mkdir(options.plot_folder)
            end
            plot_filename = fullfile( ...
                options.plot_folder, ...
                sprintf("%04d_Hz_bandwidth", specs{1}{1}) ...
            );
            print(fig, plot_filename, "-dpng", "-painters", "-r300");
            print(fig, plot_filename, "-dpdf", "-painters");

            fig.Color = "none";
            fig.InvertHardcopy = "off";
            print(fig, plot_filename, "-dsvg", "-painters");
            close(fig);
        end
    end

    function plot_helper(x, y, z, selected_bandwidth, specs, options)
        fig = figure();
        if options.save_plot
            fig.Renderer = "painters";
            fig.Units = "centimeters";
            fig.PaperSize = fig.Position(3:4);
            fig.PaperUnits = "normalized";
            fig.PaperPosition = [0, 0, 1, 1];
        end

        n_plots = length(x);
        
        t = tiledlayout(ceil(n_plots/2), 2, ...
            "TileSpacing", "Compact", ...
            "Padding", "Compact");
        xlabel(t, "Desired closed-loop bandwidth [Hz]");
        ylabel(t, "Tradeoff factor (\alpha)");
        title(t, sprintf("%d Hz", specs{1}{1}));
        
        for i_plots = 1:n_plots
            ax = nexttile();
            hold on; box on; grid on;
            set(ax, "layer", "top");
            title(ax, sprintf(...
                "%d photons per timestep \n(gain %0.4f, order %d)", ...
                specs{i_plots}{2:4}));

            contourf(x{i_plots}, y{i_plots}, z{i_plots}, 500, ...
                'EdgeColor','none');
            colormap(flipud(turbo));
            caxis([0, 0.5]);

            S = (1 ./ (z{i_plots} + 1)).';
            [fridge, ~, ~] = tfridge(S, y{i_plots}(1, :));

            plot(x{i_plots}(:,1), fridge, ...
                "Color", "#000000", ...
                "LineWidth", 2);

            xline(selected_bandwidth{i_plots}, ...
                "Color", "#000000", ...
                "LineStyle", "--", ...
                "LineWidth", 2);
        end

        cb = colorbar("Location", "eastoutside");
        cb.Label.String = "Residual RMS [mas]";
        cb.Label.FontSize = 12;
        cb.Layout.Tile = 'east';

        if options.save_plot    
            if ~isfolder(options.plot_folder)
                mkdir(options.plot_folder)
            end
            plot_filename = fullfile( ...
                options.plot_folder, ...
                sprintf("%04d_Hz", specs{1}{1}) ...
            );
            print(fig, plot_filename, "-dpng", "-painters", "-r300");
            print(fig, plot_filename, "-dpdf", "-painters");

            fig.Color = "none";
            fig.InvertHardcopy = "off";
            print(fig, plot_filename, "-dsvg", "-painters");
            close(fig);
        end
    end

    function optimal_params = find_optimal_params_bandwidth(rms, n_unique_params, params_grid, selected_bandwidth_idx)
        % Minimal Extractions at given bandwidth idx
        min_rms = -inf(n_unique_params(1:2));

        min_gain_idx = nan(n_unique_params(1:2));
        min_order_idx = nan(n_unique_params(1:2));
        
        min_bandwidth_idx = nan(n_unique_params(1:2));
        min_alpha_idx = nan(n_unique_params(1:2));

        for freq_idx = 1:n_unique_params(1)
            for photon_idx = 1:n_unique_params(2)
                for gain_idx = 1:n_unique_params(3)
                    for order_idx = 1:n_unique_params(4)

                        tmp_rms = cell2mat(squeeze(rms(...
                            freq_idx, photon_idx, gain_idx, order_idx, :, :)));

                        if isempty(tmp_rms)
                            % If no data, skip!
                            break;
                        end

                        tmp_min_rms = min( ...
                            tmp_rms(selected_bandwidth_idx(freq_idx), :));
                        env_idx = {freq_idx, photon_idx};

                        if min_rms(env_idx{:}) < tmp_min_rms
                            % New minimum found
                            [bandwidth_idx, alpha_idx] = find(tmp_rms == tmp_min_rms);

                            min_rms(env_idx{:}) = tmp_min_rms;

                            min_gain_idx(env_idx{:}) = gain_idx;
                            min_order_idx(env_idx{:}) = order_idx;
                            min_bandwidth_idx(env_idx{:}) = bandwidth_idx;
                            min_alpha_idx(env_idx{:}) = alpha_idx;
                        end
                    end
                end
            end
        end
        
        % Optimal Parameters
        optimal_params = cell(n_unique_params(1:2));
        
        for freq_idx = 1:n_unique_params(1)
            for photon_idx = 1:n_unique_params(2)
                env_idx = {freq_idx, photon_idx};
                other_idx = cellfun(@(x) x(env_idx{:}), ...
                    {min_gain_idx, min_order_idx, min_bandwidth_idx, min_alpha_idx}, ...
                    "UniformOutput", 0);
                idx = [env_idx, other_idx];

                optimal_params{env_idx{:}} = cellfun(@(x) x(idx{:}), ...
                    params_grid(3:6));
            end
        end
    end

    function optimal_params = find_optimal_params(rms, n_unique_params, params_grid)
        % Minimal Extractions
        min_rms = -inf(n_unique_params(1:2));

        min_gain_idx = nan(n_unique_params(1:2));
        min_order_idx = nan(n_unique_params(1:2));
        min_bandwidth_idx = nan(n_unique_params(1:2));
        min_alpha_idx = nan(n_unique_params(1:2));

        for freq_idx = 1:n_unique_params(1)
            for photon_idx = 1:n_unique_params(2)
                for gain_idx = 1:n_unique_params(3)
                    for order_idx = 1:n_unique_params(4)

                        tmp_rms = cell2mat(squeeze(rms(...
                            freq_idx, photon_idx, gain_idx, order_idx, :, :)));

                        if isempty(tmp_rms)
                            % If no data, skip!
                            break;
                        end

                        tmp_min_rms = min(min(tmp_rms));
                        env_idx = {freq_idx, photon_idx};

                        if min_rms(env_idx{:}) < tmp_min_rms
                            % New minimum found
                            [bandwidth_idx, alpha_idx] = find(tmp_rms == tmp_min_rms);

                            min_rms(env_idx{:}) = tmp_min_rms;

                            min_gain_idx(env_idx{:}) = gain_idx;
                            min_order_idx(env_idx{:}) = order_idx;
                            min_bandwidth_idx(env_idx{:}) = bandwidth_idx;
                            min_alpha_idx(env_idx{:}) = alpha_idx;
                        end
                    end
                end
            end
        end

        % Optimal Parameters
        optimal_params = cell(n_unique_params(1:2));
        
        for freq_idx = 1:n_unique_params(1)
            for photon_idx = 1:n_unique_params(2)
                env_idx = {freq_idx, photon_idx};
                other_idx = cellfun(@(x) x(env_idx{:}), ...
                    {min_gain_idx, min_order_idx, min_bandwidth_idx, min_alpha_idx}, ...
                    "UniformOutput", 0);
                idx = [env_idx, other_idx];

                optimal_params{env_idx{:}} = cellfun(@(x) x(idx{:}), ...
                    params_grid(3:6));
            end
        end
    end

end