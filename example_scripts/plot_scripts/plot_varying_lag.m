%% Cleanup
clearvars; close all; clc;

%% Parameters
options = struct();
options.save_plot = true;
options.readout_noise = false;
options.colors = [ ...
    "#0072BD";
    "#D95319";
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

options.plot_folder = fullfile(plotfolder, "varying_lag");

%% Load required libraries -----------------------------------------------------
MATLAB_environment_setup();

%% Generate Datafile if not available
utility_functions.varying_lag(Fs, n_photons, ...
    "readout_noise", options.readout_noise);

%% Load Datafile
parent_folder = fullfile(datafolder, "varying_lag");
datafile = fullfile( ...
    parent_folder, ...
    sprintf("%04d_Hz", Fs), ...
    sprintf("%04d_photons.mat", n_photons));

load(datafile);
n_variations_space = size(variations_space, 1);

%% Plot
fig = figure();
if options.save_plot
    fig.Renderer = "painters";
    fig.Units = "centimeters";
    fig.PaperSize = fig.Position(3:4);
    fig.PaperUnits = "normalized";
    fig.PaperPosition = [0, 0, 1, 1];
end

t = tiledlayout(1, 1, "TileSpacing", "compact", "Padding", "compact");
ylabel(t, "Residual RMS [mas]");
xlabel(t, "WFC Lag [s]");
title(t, "Varying WFC lag");

ax = nexttile();    
hold on; grid on; box on;

rms_vals_int = arrayfun(@(x) x.tip.int.total, rms_data);
rms_vals_data = arrayfun(@(x) x.tip.data.total, rms_data);

h_int = plot(variations_space, rms_vals_int, ...
    "LineStyle", "-", ...
    "LineWidth", 3, ...
    "Color", options.colors(1));
h_data = plot(variations_space, rms_vals_data, ...
    "LineStyle", "-", ...
    "LineWidth", 3, ...
    "Color", options.colors(2));

xlim([variations_space(1), variations_space(end)]);

xline(1/Fs, ...
    "LineStyle", "--", ...
    "LineWidth", 2, ...
    "Color", "#000000", ...
    "Label", "Single Time Step");

xline(tau_lag, ...
    "LineStyle", "--", ...
    "LineWidth", 2, ...
    "Color", "#000000", ...
    "Label", "Nominal WFC lag");

h_leg = legend([h_int, h_data], ...
    "Integrator Controller", ...
    "Data-driven Controller", ...
    "FontSize", 11, ...
    "Orientation", "vertical", ...
    "Location", "southeast");

if options.save_plot
    if ~isfolder(options.plot_folder)
        mkdir(options.plot_folder)
    end
    plot_filename = fullfile( ...
        options.plot_folder, ...
        sprintf("%dHz_%dphotons", Fs, n_photons) ...
    );
    print(fig, plot_filename, "-dpng", "-painters", "-r300");
    print(fig, plot_filename, "-dpdf", "-painters");

    fig.Color = "none";
    fig.InvertHardcopy = "off";
    print(fig, plot_filename, "-dsvg", "-painters");
    close(fig);
end