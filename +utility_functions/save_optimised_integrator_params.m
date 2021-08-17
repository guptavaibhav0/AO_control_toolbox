function save_optimised_integrator_params(options)
%save_optimised_integrator_params Optimised integrator controller parameters
% 
%   save_optimised_integrator_params(name, value) specifies the optional and
%   plotting parameters.
%
%   Name-Value Pair Arguments:
%     |----------------|-------------------------------------------------------|
%     | Name           | Description                                           |
%     |----------------|-------------------------------------------------------|
%     | readout_noise  | If detector has a readout noise                       |
%     |                |   Default: false                                      |
%     |----------------|-------------------------------------------------------|
%     | plot           | To plot the graphs for optimisation                   |
%     |                |   Default: true                                       |
%     |----------------|-------------------------------------------------------|
%     | save_plot      | Autosave the graphs for optimisation                  |
%     |                |   Default: true                                       |
%     |----------------|-------------------------------------------------------|
% 

    arguments
        options.readout_noise (1, 1) logical = false
        options.plot          (1, 1) logical = true
        options.save_plot     (1, 1) logical = true
    end

    %% Basic Specifications ----------------------------------------------------
    if options.readout_noise
        datafolder = fullfile("data", "readout");
        plotfolder = fullfile("figures", "readout");
    else
        datafolder = fullfile("data", "no_readout");
        plotfolder = fullfile("figures", "no_readout");
    end

    % Save file for optimised results        
    parent_folder = fullfile( ...
        datafolder, ...
        "optimise_integrator");

    options.plot_folder = fullfile( ...
        plotfolder, ...
        "optimise_integrator"); 

    nd_grid_file = fullfile(parent_folder, "nd_grid.mat");
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
        rms_data_space = [];
        for i_fs_folder = 1:n_fs_folders
            Fs = double(extractBefore(...
                string(fs_folders(i_fs_folder).name), ...
                "_Hz"));

            photon_files = dir(fullfile( ...
                parent_folder, ...
                sprintf("%04d_Hz", Fs), ...
                "*_photons.mat"));

            n_photon_files = length(photon_files);

            for ii = 1:n_photon_files
                data = load(fullfile(photon_files(ii).folder, photon_files(ii).name));
                data.param_space = data.gain_grid';
                flux = double(extractBefore(...
                    string(photon_files(ii).name), ...
                    "_photons.mat"));

                param_space = [param_space; ...
                    repmat(Fs, size(data.param_space, 1), 1), ...
                    repmat(flux, size(data.param_space, 1), 1), ...
                    data.param_space];

                rms_data_space = [rms_data_space; ...
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
            @(varargin) rms_data_space(all(param_space==[varargin{:}], 2), 1), ...
            params_grid{:});

        rms_data.tilt = arrayfun(...
            @(varargin) rms_data_space(all(param_space==[varargin{:}], 2), 2), ...
            params_grid{:});

        %%% Save n-d grid
        save(nd_grid_file, "unique_params", "params_grid", "rms_data");
    end

    %% Get optimised parameters ------------------------------------------------
    [Fs_space, photon_space] = unique_params{1:2};

    optimised_params = struct();
    get_optimal_gain = struct();
    for DoF = ["tip", "tilt"]
        for i_params = 3:length(unique_params)
            [~, idx] = min(rms_data.(DoF), [], i_params);
            optimised_params.(DoF) = unique_params{i_params}(idx);
            get_optimal_gain.(DoF) = griddedInterpolant(...
                {Fs_space, photon_space}, ...
                optimised_params.(DoF));
        end
    end

    %% Save optimised parameters -----------------------------------------------
    save(params_file, ...
        "optimised_params", ...
        "get_optimal_gain", ...
        "Fs_space", ...
        "photon_space");

    %% Plot --------------------------------------------------------------------
    if options.plot
        for DoF = ["tip", "tilt"]
            fig = figure();
            if options.save_plot
                fig.Renderer = "painters";
                fig.Units = "centimeters";
                fig.PaperSize = fig.Position(3:4);
                fig.PaperUnits = "normalized";
                fig.PaperPosition = [0, 0, 1, 1];
            end

            t = tiledlayout(ceil(length(Fs_space)/2), 2, ...
                "TileSpacing", "Compact", ...
                "Padding", "Compact");
            xlabel(t, "# of photons per timestep");
            ylabel(t, "Controller Gain");
            title(t, sprintf("%s at detector", upper(DoF)));

            for i_Fs_space = 1:length(Fs_space)
                x = squeeze(params_grid{2}(i_Fs_space, :, :));
                y = squeeze(params_grid{3}(i_Fs_space, :, :));
                z = squeeze(rms_data.(DoF)(i_Fs_space, :, :));

                ax = nexttile();
                hold on; box on; grid on;
                title(ax, sprintf("%d Hz", unique_params{1}(i_Fs_space)));
                set(ax, "layer", "top");

                contourf(x, y, z, 20, "EdgeColor", "none");
                colormap(flipud(winter));
                caxis([0, 1.5])

                plot(x, optimised_params.(DoF)(i_Fs_space, :), ...
                    "LineWidth", 3, ...
                    "Color", "#222222");

                if options.save_plot
                    ax.Color = "none";
                end
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
                    sprintf("optimise_integrator_%s", DoF) ...
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

    %% Helper Functions --------------------------------------------------------
    function rms_value = get_rms_values(rms_data, DoF)
        if isempty(rms_data.(DoF))
            % If simulations are not run
            rms_value = inf;
        else
            % Extract the total residual for integrator controller
            rms_value = rms_data.(DoF).int.total;
        end
    end

end