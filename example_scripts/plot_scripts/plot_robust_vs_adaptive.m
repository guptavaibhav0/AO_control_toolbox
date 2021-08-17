%%plot_varying_atmospheric_study Plot results for atmospheric variations
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

plot_folder = fullfile(plotfolder, "robust_vs_adaptive");

%% Load required libraries -----------------------------------------------------
MATLAB_environment_setup();

%% Generate Datafile if not available
utility_functions.varying_atmospheric_robust(Fs, n_photons, ...
    "readout_noise", options.readout_noise);
utility_functions.varying_atmospheric_adaptive(Fs, n_photons, ...
    "readout_noise", options.readout_noise);

%% Load Datafiles
parent_folder = fullfile(datafolder, "varying_atmospheric_robust");
datafile = fullfile( ...
    parent_folder, ...
    sprintf("%04d_Hz", Fs), ...
    sprintf("%04d_photons.mat", n_photons));
robust = load(datafile);

parent_folder = fullfile(datafolder, "varying_atmospheric_adaptive");
datafile = fullfile( ...
    parent_folder, ...
    sprintf("%04d_Hz", Fs), ...
    sprintf("%04d_photons.mat", n_photons));
adaptive = load(datafile);

%% Plot
binwidth = 0.005;
binedges = 0:binwidth:0.4;
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
    residual_rms_robust = arrayfun(@(x) x.(DoF).data.total, robust.rms_data);
    residual_rms_adaptive = arrayfun(@(x) x.(DoF).data.total, adaptive.rms_data);

    ax = nexttile();    
    hold on;
    set(ax, "YColor", "none", "Color", "none");
    set(ax, "layer", "top");

    % Robust controller
    histogram(residual_rms_robust, ...
        "BinEdges", binedges, ...
        "EdgeAlpha", 0, ...
        "Normalization", histogram_type, ...
        "FaceColor", "#0072BD", ...
        "FaceAlpha", 0.5);
    
    [pdf_vals, pdf_pts] = ksdensity(residual_rms_robust, binedges, ...
        "Bandwidth", 0.02, ...
        "Function", "pdf");
    plot(pdf_pts, pdf_vals, ...
        "Color", "#0072BD", ...
        "LineWidth", 2);

    % Adaptive Controller
    histogram(residual_rms_adaptive, ...
        "BinEdges", binedges, ...
        "EdgeAlpha", 0, ...
        "Normalization", histogram_type, ...
        "FaceColor", "#D95319", ...
        "FaceAlpha", 0.5);
    
    [pdf_vals, pdf_pts] = ksdensity(residual_rms_adaptive, binedges, ...
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
    "MarkerSize", 40 ...
);
l2 = plot(-inf, -inf, ...
    "Color", "#D95319", ...
    "LineStyle", "none", ...
    "Marker", ".", ...
    "MarkerSize", 40 ...
);

legend([l1, l2], ...
    "Robust controller", ...
    "Adaptive controller", ...
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

%% Plot
binwidth = 2;
binedges = 0:binwidth:200;
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
xlabel(t, "Performance Gain [%]");
title(t, sprintf("PDF of Performance Gain\n(%d Hz, %d photons per timestep)", Fs, n_photons));

for DoF = ["tip", "tilt"]
    residual_rms_robust = arrayfun(@(x) x.(DoF).data.total, robust.rms_data);
    residual_rms_adaptive = arrayfun(@(x) x.(DoF).data.total, adaptive.rms_data);
    gain = residual_rms_robust ./ residual_rms_adaptive * 100 - 100;

    ax = nexttile();    
    hold on;
    set(ax, "YColor", "none", "Color", "none");
    set(ax, "layer", "top");

    % Gain
    histogram(gain, ...
        "BinEdges", binedges, ...
        "EdgeAlpha", 0, ...
        "Normalization", histogram_type, ...
        "FaceColor", "#0072BD", ...
        "FaceAlpha", 0.5);
    
    [pdf_vals, pdf_pts] = ksdensity(gain, binedges, ...
        "Bandwidth", 10, ...
        "Function", "pdf");
    plot(pdf_pts, pdf_vals, ...
        "Color", "#0072BD", ...
        "LineWidth", 2);
    
    title(sprintf("%s", upper(DoF)));
    xlim([binedges(1), binedges(end)]);
end

if options.save_plot
    if ~isfolder(plot_folder)
        mkdir(plot_folder)
    end
    plot_filename = fullfile( ...
        plot_folder, ...
        sprintf("%dHz_%dphotons_gain", Fs, n_photons) ...
    );
    print(fig, plot_filename, "-dpng", "-painters", "-r300");
    print(fig, plot_filename, "-dpdf", "-painters");

    fig.Color = "none";
    fig.InvertHardcopy = "off";
    print(fig, plot_filename, "-dsvg", "-painters");
    close(fig);
end

%% Cleanup
if options.save_plot
    clearvars; close all; clc;
end