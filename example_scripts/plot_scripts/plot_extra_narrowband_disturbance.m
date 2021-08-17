%% Cleanup ---------------------------------------------------------------------
clearvars; close all; clc;

%% Parameters ------------------------------------------------------------------
options = struct();
options.save_plot = true;
options.readout_noise = true;
options.colors = [ ...
    "#0072BD";
    "#D95319";
    "#EDB120";
    "#7E2F8E";
    "#77AC30";
];

Fs = 400;
n_photons = 1600;

if options.readout_noise
    datafolder = fullfile("data", "readout");
    plotfolder = fullfile("figures", "readout");
else
    datafolder = fullfile("data", "no_readout");
    plotfolder = fullfile("figures", "no_readout");
end

options.plot_folder = fullfile(plotfolder, "extra_narrowband_disturbance");

%% Load required libraries -----------------------------------------------------
MATLAB_environment_setup();

%% Generate datafiles if not available -----------------------------------------
for type = "narrowband"
    % Unknown
    utility_functions.extra_disturbance_study(...
        "design_extra", "none", ...
        "sim_extra", type, ...
        "readout_noise", options.readout_noise);
    % Known
    utility_functions.extra_disturbance_study(...
        "design_extra", type, ...
        "sim_extra", type, ...
        "readout_noise", options.readout_noise);
    % Wrong
    utility_functions.extra_disturbance_study(...
        "design_extra", type, ...
        "sim_extra", "none", ...
        "readout_noise", options.readout_noise);
end

%% Plot ------------------------------------------------------------------------
for extra_type = "narrowband"
    for study_type = ["unknown_disturbance", "known_disturbance", "wrong_disturbance"]
        datafile = fullfile( ...
            datafolder, ...
            "extra_disturbance_study", ...
            study_type, ...
            extra_type, ...
            sprintf("%04d_Hz", Fs), ...
            sprintf("%04d_photons.mat", n_photons));
        dataset = load(datafile);
        plot_helper_narrowband(dataset, study_type, options);
    end
end

%% Cleanup ---------------------------------------------------------------------
if options.save_plot
    clearvars; close all; clc;
end

%% Helper Functions ------------------------------------------------------------
function plot_helper_narrowband(dataset, study_type, options)
    %% Data Manipulation -------------------------------------------------------
    mag_space = unique(dataset.extra_space(:, 1));
    freq_space = unique(dataset.extra_space(:, 2));
    bw_space = unique(dataset.extra_space(:, 3));

    [freq_grid, bw_grid] = ndgrid(freq_space, bw_space);

    rms = struct();
    rms.raw = arrayfun(@(x) x.tip.raw.total, dataset.rms_data);
    rms.int = arrayfun(@(x) x.tip.int.total, dataset.rms_data);
    rms.data = arrayfun(@(x) x.tip.data.total, dataset.rms_data);

    rms_int_grid = arrayfun(...
        @(x, y) rms.int(all(dataset.extra_space(:, 2:3) == [x, y], 2), 1) ./ mag_space, ...
        freq_grid, bw_grid, ...
        'UniformOutput', 0 ...
    );

    rms_data_grid = arrayfun(...
        @(x, y) rms.data(all(dataset.extra_space(:, 2:3) == [x, y], 2), 1) ./ mag_space, ...
        freq_grid, bw_grid, ...
        'UniformOutput', 0 ...
    );

    improvement_grid = arrayfun(...
        @(x, y) rms.int(all(dataset.extra_space(:, 2:3) == [x, y], 2), 1) ./ ...
            rms.data(all(dataset.extra_space(:, 2:3) == [x, y], 2), 1) * 100 - 100, ...
        freq_grid, bw_grid, ...
        'UniformOutput', 0 ...
    );

    %% Plot Comparison ---------------------------------------------------------
    fig = figure();
    old_pos = fig.Position;
    fig.Position = [old_pos(1:2),  840, 420];
    if options.save_plot
        fig.Renderer = "painters";
        fig.Units = "centimeters";
        fig.PaperSize = fig.Position(3:4);
        fig.PaperUnits = "normalized";
        fig.PaperPosition = [0, 0, 1, 1];
    end

    t = tiledlayout(1, 1, "TileSpacing", "compact", "Padding", "compact");
    ylabel(t, "Normalised Residual RMS");
    xlabel(t, "Center Frequency of Narrowband Noise [Hz]");
    title(t, regexprep(...
        lower(replace(study_type, "_", " narrowband ")), ...
        "(^|\.)\s*.", ...
        "${upper($0)}"));

    x_space = freq_space;
    mean_int = cellfun(@(x) mean(x), rms_int_grid);
    std_int = cellfun(@(x) std(x), rms_int_grid);
    mean_data = cellfun(@(x) mean(x), rms_data_grid);
    std_data = cellfun(@(x) std(x), rms_data_grid);

    ax = nexttile();    
    hold on; grid on; box on;

    switch study_type
        case {"known_disturbance"}
            % Integrator Controller
            b_int = bar(x_space, mean_int, 0.8, "LineWidth", 1);
            for i_int = 1:length(b_int)
                b_int(i_int).FaceColor = options.colors(i_int);
                b_int(i_int).FaceAlpha = 0.75;

                errorbar(b_int(i_int).XEndPoints, b_int(i_int).YEndPoints, ...
                    std_int(:, i_int), ...
                    "LineStyle" , "none"    , ...
                    "CapSize"   , 5         , ...
                    "Color"     , "#000000" , ...
                    "LineWidth" , 1           ...
                );
            end

            % Data-driven Controller
            b_data = bar(x_space, mean_data, 0.8, "LineWidth", 1);
            hatchbar(b_data);
            for i_data = 1:length(b_data)
                b_data(i_data).FaceColor = options.colors(i_data);
                b_data(i_data).FaceAlpha = 1;

                errorbar(b_data(i_data).XEndPoints, b_data(i_data).YEndPoints, ...
                    std_data(:, i_data), ...
                    "LineStyle" , "none"    , ...
                    "CapSize"   , 5         , ...
                    "Color"     , "#000000" , ...
                    "LineWidth" , 1           ...
                ); 
            end
            
            b_leg = b_data;
        case {"unknown_disturbance", "wrong_disturbance"}
            % Data-driven Controller
            b_data = bar(x_space, mean_data, 0.8, "LineWidth", 1);
            hatchbar(b_data);
            for i_data = 1:length(b_data)
                b_data(i_data).FaceColor = options.colors(i_data);
                b_data(i_data).FaceAlpha = 0.75;

                errorbar(b_data(i_data).XEndPoints, b_data(i_data).YEndPoints, ...
                    std_data(:, i_data), ...
                    "LineStyle" , "none"    , ...
                    "CapSize"   , 5         , ...
                    "Color"     , "#000000" , ...
                    "LineWidth" , 1           ...
                ); 
            end
            
            % Integrator Controller
            b_int = bar(x_space, mean_int, 0.8, "LineWidth", 1);
            for i_int = 1:length(b_int)
                b_int(i_int).FaceColor = options.colors(i_int);
                b_int(i_int).FaceAlpha = 1;

                errorbar(b_int(i_int).XEndPoints, b_int(i_int).YEndPoints, ...
                    std_int(:, i_int), ...
                    "LineStyle" , "none"    , ...
                    "CapSize"   , 5         , ...
                    "Color"     , "#000000" , ...
                    "LineWidth" , 1           ...
                );
            end
            
            b_leg = b_int;
    end

    xticks(x_space);
    
    % Frequency Legend
    h_leg = legend(ax, b_leg, arrayfun(@(x) sprintf("%d Hz", x), bw_space), ...
        "Orientation", "vertical", ...
        "Location", "layout");
    title(h_leg, "Bandwidth");
    h_leg.Layout.Tile = "east";
    
    % Controller Legend
    a=axes("position", get(ax,"position"), "visible", "off");
    p_leg = [];
    p_leg(1) = patch([-inf, inf], [-inf, inf], 'w', "LineWidth", 1);
    p_leg(2) = patch([-inf, inf], [-inf, inf], 'w', "LineWidth", 1);
    h_leg1 = legend(a, p_leg, "Integrator", "Data-driven", ...
        "Orientation", "horizontal", ...
        "Location", "northwest");
    title(h_leg1, "Controller Type");
    drawnow;
    icon_transform = h_leg1.EntryContainer.NodeChildren(1).Icon.Transform;
    line(icon_transform,  ...
        [0:0.2:0.8; 0.2:0.2:1], repmat([0;1], 1, 5), ...
        "Color", "#444444", ...
        "LineWidth", 1);
       
    if options.save_plot
        if ~isfolder(options.plot_folder)
            mkdir(options.plot_folder)
        end
        plot_filename = fullfile( ...
            options.plot_folder, ...
            sprintf("%s", replace(study_type, "_disturbance", "")) ...
        );
        print(fig, plot_filename, "-dpng", "-painters", "-r300");
        print(fig, plot_filename, "-dpdf", "-painters");

        fig.Color = "none";
        fig.InvertHardcopy = "off";
        print(fig, plot_filename, "-dsvg", "-painters");
        close(fig);
    end
    
    %% Plot Improvement --------------------------------------------------------
    fig = figure();
    old_pos = fig.Position;
    fig.Position = [old_pos(1:2),  840, 420];
    if options.save_plot
        fig.Renderer = "painters";
        fig.Units = "centimeters";
        fig.PaperSize = fig.Position(3:4);
        fig.PaperUnits = "normalized";
        fig.PaperPosition = [0, 0, 1, 1];
    end
    x_space = freq_space;
    mean_improvement = cellfun(@(x) mean(x), improvement_grid);
    std_improvement = cellfun(@(x) std(x), improvement_grid);

    t = tiledlayout(1, 1, "TileSpacing", "compact", "Padding", "compact");
    xlabel(t, "Center Frequency of Narrowband Noise [Hz]");
    
    if all(mean_improvement >= 0)
        ylabel(t, "Performance Gain [%]");
    elseif all(mean_improvement <= 0)
        ylabel(t, "Performance Loss [%]");
    else
        ylabel(t, "Performance Gain/Loss [%]");
    end
    
    title(t, regexprep(...
        lower(replace(study_type, "_", " narrowband ")), ...
        "(^|\.)\s*.", ...
        "${upper($0)}"));

    ax = nexttile();    
    hold on; grid on; box on;

    % Integrator Controller
    b_improvement = bar(x_space, mean_improvement, 0.8, "LineWidth", 1);
    for i_improvement = 1:length(b_int)
        b_improvement(i_improvement).FaceColor = options.colors(i_improvement);
        b_improvement(i_improvement).FaceAlpha = 1;

        errorbar( ...
            b_improvement(i_improvement).XEndPoints, ...
            b_improvement(i_improvement).YEndPoints, ...
            std_improvement(:, i_improvement), ...
            "LineStyle" , "none"    , ...
            "CapSize"   , 5         , ...
            "Color"     , "#000000" , ...
            "LineWidth" , 1           ...
        );
    end
    xticks(x_space);
    
    h_improvement = legend(b_improvement, ...
        arrayfun(@(x) sprintf("%d Hz", x), bw_space), ...
        "Orientation", "vertical", ...
        "Location", "eastoutside");
    title(h_improvement, "Bandwidth");
    
    if options.save_plot
        if ~isfolder(options.plot_folder)
            mkdir(options.plot_folder)
        end
        plot_filename = fullfile( ...
            options.plot_folder, ...
            sprintf("%s_gain", ...
                replace(study_type, "_disturbance", "")) ...
        );
        print(fig, plot_filename, "-dpng", "-painters", "-r300");
        print(fig, plot_filename, "-dpdf", "-painters");

        fig.Color = "none";
        fig.InvertHardcopy = "off";
        print(fig, plot_filename, "-dsvg", "-painters");
        close(fig);
    end
end

function hatchbar(bar_handle, options)
    arguments
        bar_handle
        options.LineSpacing = 0.1
        options.LineWidth   = 1
        options.LineColor   = "#444444"
    end
    n_bars = length(bar_handle);
    
    if (n_bars == 1)
        bar_gap = repmat(bar_handle.XEndPoints(2) - bar_handle(1).XEndPoints(1), ...
            1, length(bar_handle.XEndPoints));
    else
        bar_gap = bar_handle(2).XEndPoints - bar_handle(1).XEndPoints;
    end
    spacing = max(arrayfun(@(x) max(x.YEndPoints), bar_handle)) * options.LineSpacing;
    spacing = min(spacing, 0.05);
    
    for i_bars = 1:n_bars
        y_top = bar_handle(i_bars).YEndPoints;
        barwidth = bar_gap * bar_handle(i_bars).BarWidth;
        
        x_left = bar_handle(i_bars).XEndPoints - barwidth/2;

        n_group = length(x_left);
        for i_group = 1:n_group
            y_low = 0;
            x_tmp = [];
            y_tmp = [];
            while y_low < y_top(i_group)
                dy_relative = (y_top(i_group) - y_low) / spacing;
                if dy_relative > 1
                    dy_relative = 1;
                end
                x_range = [0; barwidth(i_group)] * dy_relative;
                y_range = [0; spacing] * dy_relative;
                x_tmp = [x_tmp, x_left(i_group) + x_range];
                y_tmp = [y_tmp, y_low + y_range];          
                y_low = y_low + spacing;
            end
            line(x_tmp, y_tmp,...
                "LineWidth", options.LineWidth, ...
                "Color", options.LineColor);        
        end
    end
end
