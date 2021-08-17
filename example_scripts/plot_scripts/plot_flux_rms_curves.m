%% Cleanup
clearvars; close all; clc;

%% Parameters ------------------------------------------------------------------
options = struct();
options.save_plot = true;
options.readout_noise = false;

if options.readout_noise
    datafolder = fullfile("data", "readout");
    plotfolder = fullfile("figures", "readout");
else
    datafolder = fullfile("data", "no_readout");
    plotfolder = fullfile("figures", "no_readout");
end

options.plot_folder = fullfile(plotfolder, "flux_rms_curves");

%% Read Datafiles --------------------------------------------------------------
parent_folder = fullfile(datafolder, "compare_controller_statistics");
fs_folders = dir(fullfile(parent_folder, "*_Hz"));
n_fs_folders = length(fs_folders);

Fs_space = zeros(n_fs_folders, 1);
flux_space = cell(n_fs_folders, 1);
rms_mean_int = cell(n_fs_folders, 1);
rms_std_int = cell(n_fs_folders, 1);
rms_mean_data = cell(n_fs_folders, 1);
rms_std_data = cell(n_fs_folders, 1);

for i_fs_folder = 1:n_fs_folders
    Fs = double(extractBefore(...
        string(fs_folders(i_fs_folder).name), ...
        "_Hz" ...
    ));
    Fs_space(i_fs_folder) = Fs;

    photon_files = dir(fullfile( ...
        parent_folder, ...
        sprintf("%04d_Hz", Fs), ...
        "*_photons.mat") ...
    );
    n_photon_files = length(photon_files);

    flux_space{i_fs_folder} = zeros(n_photon_files, 1);
    rms_mean_int{i_fs_folder} = zeros(n_photon_files, 1);
    rms_std_int{i_fs_folder} = zeros(n_photon_files, 1);
    rms_mean_data{i_fs_folder} = zeros(n_photon_files, 1);
    rms_std_data{i_fs_folder} = zeros(n_photon_files, 1);

    for i_photon_file = 1:n_photon_files
        filedata = load(fullfile( ...
            photon_files(i_photon_file).folder, ...
            photon_files(i_photon_file).name));
        
        n_photons = double(extractBefore(...
            string(photon_files(i_photon_file).name), ...
            "_photons.mat" ...
        ));

        flux_space{i_fs_folder}(i_photon_file) = ...
            n_photons * Fs;

        tmp = 20 * log10(arrayfun( ...
            @(x) x.tip.int.total ./ x.tip.raw.total, ...
            filedata.rms_data));
        rms_mean_int{i_fs_folder}(i_photon_file) = mean(tmp);
        rms_std_int{i_fs_folder}(i_photon_file) = std(tmp);

        tmp = 20 * log10(arrayfun( ...
            @(x) x.tip.data.total ./ x.tip.raw.total, ...
            filedata.rms_data));
        rms_mean_data{i_fs_folder}(i_photon_file) = mean(tmp);        
        rms_std_data{i_fs_folder}(i_photon_file) = std(tmp);
    end
end

%% Plot flux-rms curves --------------------------------------------------------    
plot_helper(flux_space, rms_mean_int, rms_std_int, Fs_space, ...
    "integrator controller", options);

plot_helper(flux_space, rms_mean_data, rms_std_data, Fs_space, ...
    "data-driven controller", options);

%% Helper Functions ------------------------------------------------------------
function plot_helper(x, y, y_std, Fs_space, controller_type, options)
    n_Fs = length(Fs_space);
    
    fig = figure();

    if options.save_plot
        fig.Renderer = "painters";
        fig.Units = "centimeters";
        fig.PaperSize = fig.Position(3:4);
        fig.PaperUnits = "normalized";
        fig.PaperPosition = [0, 0, 1, 1];
    end
    
    t = tiledlayout(1, 1, "TileSpacing", "Compact", "Padding", "Compact");
    xlabel(t, "Photon Flux [# of photons / s]");
    ylabel(t, "Attenuation [dB]");
    title(t, sprintf("Attenuation for the AO system using %s", ...
        controller_type));
    
    ax = nexttile();
    ax.XScale = "log";
    hold on; box on; grid on;

    colors = [ ...
        "#0072BD", ...
        "#D95319", ...
        "#77AC30", ...
        "#7E2F8E", ... 
        "#A2142F", ... 
        "#4DBEEE", ... 
        "#EDB120"  ...         
    ];

    h_plot = zeros(n_Fs, 1);
    for i_Fs = 1:n_Fs
        h_plot(i_Fs) = plot_confidence(x{i_Fs}, y{i_Fs}, y_std{i_Fs}, ...
            "color", colors(i_Fs));
    end

    % Axis Limit
    xlim([min(cellfun(@(z) min(z), x)), max(cellfun(@(z) max(z), x))]);
    ylim([-55, -20]);
    
    % Legend
    h_leg = legend(h_plot, ...
        arrayfun(@(x) sprintf("%d Hz", x), Fs_space), ...
        "Orientation", "vertical", ...
        "Location", "southwest");
    title(h_leg, "Sampling Frequency");
    
    if options.save_plot
        if ~isfolder(options.plot_folder)
            mkdir(options.plot_folder)
        end
        plot_filename = fullfile( ...
            options.plot_folder, ...
            sprintf("%s", controller_type) ...
        );
        print(fig, plot_filename, "-dpng", "-painters", "-r300");
        print(fig, plot_filename, "-dpdf", "-painters");

        fig.Color = "none";
        fig.InvertHardcopy = "off";
        print(fig, plot_filename, "-dsvg", "-painters");
        close(fig);
    end
end

function h = plot_confidence(x, y, err, options)
    arguments
        x   (1, :) double
        y   (1, :) double
        err (1, :) double
        options.color
    end

    x_conf = [x, x(end:-1:1)];

    upper_bound = y + err;
    lower_bound = y - err;
    y_conf = [upper_bound, lower_bound(end:-1:1)];

    p = patch("XData", x_conf, "YData", y_conf);
    p.FaceColor = options.color;
    p.FaceAlpha = 0.4;
    p.EdgeColor = "none";
    hold on;

    h = plot(x, y, ...
        "LineWidth", 2, ...
        "Color", options.color);
end
