%%plot_varying_atmosphere Plot results for atmospheric variations
%   
%   Specifications for the simulations and the controllers are specified in the
%   `Basic Specifications` section.
%   
%   Basic Specifications:
%    |-------------------|-----------------------------------------------------|
%    | Variable Name     | Description                                         |
%    |-------------------|-----------------------------------------------------|
%    | Fs                | Controller Frequency in [Hz]                        |
%    |-------------------|-----------------------------------------------------|
%    | n_photons         | Number of photons per timestep                      |
%    |                   |   * Assumes spot size of 8 mas                      |
%    |-------------------|-----------------------------------------------------|
%    | options.save_plot | Autosave the graphs for optimisation                |
%    |                   |     {false, true}                                   |
%    |-------------------|-----------------------------------------------------|
% 

%% Cleanup
clearvars; close all; clc;

%% Parameters
options = struct();
options.save_plot = true;
options.readout_noise = false;

Fs = 400;
n_photons = 1600;

if options.readout_noise
    datafolder = fullfile("data", "readout");
    plotfolder = fullfile("figures", "readout");
else
    datafolder = fullfile("data", "no_readout");
    plotfolder = fullfile("figures", "no_readout");
end

plot_folder = fullfile(plotfolder, "varying_disturbance");

%% Load required libraries -----------------------------------------------------
MATLAB_environment_setup();

%% Generate Datafile if not available
utility_functions.varying_atmospheric_robust(Fs, n_photons, ...
    "readout_noise", options.readout_noise);

%% Load Datafile
parent_folder = fullfile(datafolder, "varying_atmospheric_robust");
datafile = fullfile( ...
    parent_folder, ...
    sprintf("%04d_Hz", Fs), ...
    sprintf("%04d_photons.mat", n_photons));

load(datafile);
n_variations_space = size(variations_space, 1);

%% Plot
binwidth = 0.005;
binedges = 0:binwidth:1;
histogram_type = "pdf"; % {pdf, probability, cumcount}

fig = figure();
if options.save_plot
    fig.Renderer = "painters";
    fig.Units = "centimeters";
    fig.PaperSize = fig.Position(3:4);
    fig.PaperUnits = "normalized";
    fig.PaperPosition = [0, 0, 1, 1];
end

t = tiledlayout(2, 1, "TileSpacing", "Compact", "Padding", "Compact");
xlabel(t, "Residual RMS [mas]");
title(t, sprintf("PDF of residual RMS\n(%d Hz, %d photons per timestep)", Fs, n_photons));

for DoF = ["tip", "tilt"]
    residual_rms_data = arrayfun(@(x) x.(DoF).data.total, rms_data);
    residual_rms_int = arrayfun(@(x) x.(DoF).int.total, rms_data);

    ax = nexttile();
    hold on;
    set(ax, "YColor", "none", "Color", "none");
    set(ax, "layer", "top");

    % Data-driven controller
    histogram(residual_rms_data, ...
        "BinEdges", binedges, ...
        "EdgeAlpha", 0, ...
        "Normalization", histogram_type, ...
        "FaceColor", "#0072BD", ...
        "FaceAlpha", 0.5);
    
    [pdf_vals, pdf_pts] = ksdensity(residual_rms_data, binedges, ...
        "Bandwidth", 0.02, ...
        "Function", "pdf");
    plot(pdf_pts, pdf_vals, ...
        "Color", "#0072BD", ...
        "LineWidth", 2);

    % Integrator
    histogram(residual_rms_int, ...
        "BinEdges", binedges, ...
        "EdgeAlpha", 0, ...
        "Normalization", histogram_type, ...
        "FaceColor", "#D95319", ...
        "FaceAlpha", 0.5);
    
    [pdf_vals, pdf_pts] = ksdensity(residual_rms_int, binedges, ...
        "Bandwidth", 0.02, ...
        "Function", "pdf");
    plot(pdf_pts, pdf_vals, ...
        "Color", "#D95319", ...
        "LineWidth", 2);
    
    title(sprintf("%s", upper(DoF)));
    xlim([binedges(1), binedges(end)]);
end

l1 = plot(-inf, -inf, ...
    "Color", "#0072BD", ...
    "LineStyle", "none", ...
    "Marker", ".", ...
    "MarkerSize", 30 ...
);
l2 = plot(-inf, -inf, ...
    "Color", "#D95319", ...
    "LineStyle", "none", ...
    "Marker", ".", ...
    "MarkerSize", 30 ...
);
h_leg = legend([l1, l2], ...
    "Data-driven controller", ...
    "Integrator controller", ...
    "FontSize", 10, ...
    "Orientation", "horizontal", ...
    "Location", "northoutside");
h_leg.Layout.Tile = "north";

if options.save_plot
    if ~isfolder(plot_folder)
        mkdir(plot_folder)
    end
    plot_filename = fullfile( ...
        plot_folder, ...
        sprintf("%dHz_%dphotons", Fs, n_photons) ...
    );
    print(fig, plot_filename, "-dpng", "-painters", "-r300");
    print(fig, plot_filename, "-dpdf", "-painters");

    fig.Color = "none";
    fig.InvertHardcopy = "off";
    print(fig, plot_filename, "-dsvg", "-painters");
    close(fig);
end

%% Plot Nominal Disturbance Variation
load(fullfile("data", "varying_disturbance_psd.mat"));
min_variation = min(variations_space, [], 1);
max_variation = max(variations_space, [], 1);

get_var_pt = @(variation, idx) 0.3 + 0.5 * ...
    (variation(idx) - min_variation(idx)) ./ ...
    (max_variation(idx) - min_variation(idx));
get_color = @(variation) get_var_pt(variation, [1, 2, 3, 5]);

typeNames = struct(...
    "psd_tip" , "Total distrubance at Tip", ...
    "psd_tilt", "Total distrubance at Tilt" ...
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

    t = tiledlayout(1, 1, "TileSpacing", "compact", "Padding", "Compact");
    xlabel(t, "Frequency [Hz]");
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
    idx = all(variations_space == nominal_variation, 2);
    l = plot(freq_rad / 2 / pi, psd_data(idx).(type), ...
        "LineWidth", 2, ...
        "Color", [0, 0, 0]);

    xlim([1e-2, instrument_Fs/2]);
    
    % Legend
    legend(l, ...
        "Nominal Atmospheric Disturbance", ...
        "Orientation", "vertical", ...
        "Location", "northeast");

    if options.save_plot
        if ~isfolder(plot_folder)
            mkdir(plot_folder)
        end
        plot_filename = fullfile( ...
            plot_folder, ...
            sprintf("nominal_disturbance_%s", type) ...
        );
        print(fig, plot_filename, "-dpng", "-painters", "-r300");
        print(fig, plot_filename, "-dpdf", "-painters");

        fig.Color = "none";
        fig.InvertHardcopy = "off";
        print(fig, plot_filename, "-dsvg", "-painters");
        close(fig);
    end
end

%% Cleanup
if options.save_plot
    clearvars; close all; clc;
end