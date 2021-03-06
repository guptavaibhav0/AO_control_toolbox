function compare_controllers(options)
%%compare_controllers Script to compare controllers
%   
%   Specifications for the simulations and the controllers are specified in the
%   `Basic Specifications` section:
%    |-------------------------------|-----------------------------------------|
%    | Variable Name                 | Description                             |
%    |-------------------------------|-----------------------------------------|
%    | Fs                            | Controller Frequency in [Hz]            |
%    |-------------------------------|-----------------------------------------|
%    | n_photons                     | Number of photons per timestep          |
%    |-------------------------------|-----------------------------------------|
%    | solver                        | Solver to use for data-driven design    |
%    |                               |   {"sedumi", "fusion"}                  |
%    |-------------------------------|-----------------------------------------|
%    | readout_noise                 | If detector has readout noise?          |
%    |-------------------------------|-----------------------------------------|
%    | extra_disturbance_type_design | Type of extra disturbance for design    |
%    |                               |   {"chirp", "narrowband", "none"}       |
%    |-------------------------------|-----------------------------------------|
%    | extra_disturbance_type_sim    | Type of extra disturbance for simulation|
%    |                               |   {"chirp", "narrowband", "none"}       |
%    |-------------------------------|-----------------------------------------|
%    | extra_disturbance_rms         | RMS value of the extra disturbance [mas]|
%    |-------------------------------|-----------------------------------------|
%    | tau_lag                       | Communication lag in [s]                |
%    |-------------------------------|-----------------------------------------|
%    | instrument_filename           | '.fit' file containing instrument       |
%    |                               | disturbance as a timeseries             |
%    |-------------------------------|-----------------------------------------|
%    | instrument_Fs                 | Sampling frequency of instrument        |
%    |                               | disturbance in [Hz]                     |
%    |-------------------------------|-----------------------------------------|
%    | max_T_sim                     | Simulation time in [s]                  |
%    |-------------------------------|-----------------------------------------|
% 

arguments
    % Controller Frequency [Hz]
    options.Fs (1, 1) double = 400  
    
    % No. of photons per timestep for flux noise
    options.n_photons (1, 1) double = 1600
    
    % Solver type {fusion, sedumi}
    options.solver (1, 1) string = "fusion"
    
    % Detector has readout noise?
    options.readout_noise (1, 1) logical = true
    
    % Extra disturbance types for controller design {"chirp", "narrowband", "none"}
    options.extra_disturbance_type_design (1, 1) string = "none";
    
    % Extra disturbance types for simulation {"chirp", "narrowband", "none"}
    options.extra_disturbance_type_sim (1, 1) string = "none";

    % RMS value of Extra Disturbance [mas]
    options.extra_disturbance_rms (1, 1) double = 5;

    % Communication/Calculation Lag [s]
    options.tau_lag (1, 1) double = 0.4e-3;

    % Instrument Disturbance File
    options.instrument_filename (1, 1) string = fullfile("data", "vibrationNRCIMJun2018ForGupta.fits");
    options.instrument_Fs (1, 1) double = 800;	% Sampling frequency for Instrument Noise [Hz]

    % Max. simulation time [s]
    options.max_T_sim (1, 1) double = 100;
    
    % Save plots
    options.save_plot (1, 1) logical = false
    options.plot_folder (1, 1) string = "";

    % LaTeX Table Specifications
    options.short_caption (1, 1) string = "";
    options.caption (1, 1) string = "";
    options.label (1, 1) string = "";
end

% Simulation frequency [Hz]
options.Fs_sim = options.Fs;

%% Load required libraries -----------------------------------------------------
MATLAB_environment_setup();

%% Optimised Parameters --------------------------------------------------------
if options.readout_noise
    datafolder = fullfile("data", "readout");
else
    datafolder = fullfile("data", "no_readout");
end

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
        integrator_params.get_optimal_gain.(DoF)(options.Fs, options.n_photons);
    
    param = cellfun( ...
        @(x) x(options.Fs, options.n_photons), ...
        datadriven_params.get_optimal_params.(DoF));
    
    controller_gain.(DoF) = param(1);    
    controller_order.(DoF) = param(2);
    controller_bandwidth.(DoF) = param(3);
    controller_alpha.(DoF) = param(4);
end

%% Disturbance Model -----------------------------------------------------------
TMT_disturbance = TMT_disturbance_model();
TMT_disturbance.w = logspace(-4, pi, 1000) * options.instrument_Fs;
TMT_disturbance.Fs_sim = options.Fs_sim;
TMT_disturbance.add_instrument_disturbance(...
    options.instrument_filename, ...
    options.instrument_Fs);

ts = struct();
ts.tip = TMT_disturbance.get_ts("tip", options.max_T_sim);
ts.tilt = TMT_disturbance.get_ts("tilt", options.max_T_sim);
ts.noise = utils.get_white_noise(...
    utils.get_flux_noise_rms(options.n_photons, ...
        "readout_noise", options.readout_noise), ...
    ts.tip.Time(end), ...
    options.Fs_sim ...
);

%% Extra Disturbance -----------------------------------------------------------

%%% Extra disturbance for controller design 
switch options.extra_disturbance_type_design
    case "chirp"
        extra_disturbance_design = utils.get_chirp_disturbance( ...
            options.extra_disturbance_rms, ts.tip.Time(end), options.Fs_sim ...
        );
    case "narrowband"
        extra_disturbance_design = utils.get_narrowband_disturbance( ...
            options.extra_disturbance_rms, 45, 15, ts.tip.Time(end), options.Fs_sim ...
        );
    otherwise
        % No Disturbance
        time_data = 0:1/options.Fs_sim:ts.tip.Time(end);
        extra_disturbance_design = timeseries(...
            time_data.' * 0, ...
            time_data, ...
            "Name", "No Extra Disturbance" ...
        );
end

[psd, freq] = pwelch(extra_disturbance_design.Data, [], [], ...
    TMT_disturbance.w / 2 / pi, options.Fs_sim);
extra_disturbance_design_frd = frd(sqrt(psd), freq * 2 * pi, 1 / options.Fs_sim);

%%% Extra disturbance for comparision and simulation
switch options.extra_disturbance_type_sim
    case "chirp"
        extra_disturbance_sim = utils.get_chirp_disturbance( ...
            options.extra_disturbance_rms, ts.tip.Time(end), options.Fs_sim ...
        );
    case "narrowband"
        extra_disturbance_sim = utils.get_narrowband_disturbance( ...
            options.extra_disturbance_rms, 45, 15, ts.tip.Time(end), options.Fs_sim ...
        );
    otherwise
        % No Disturbance
        time_data = 0:1/options.Fs_sim:ts.tip.Time(end);
        extra_disturbance_sim = timeseries(...
            time_data.' * 0, ...
            time_data, ...
            "Name", "No Extra Disturbance" ...
        );
end

%% Controllers -----------------------------------------------------------------
controllers = struct();

for DoF = ["tip", "tilt"]
    for type = ["int", "data"]
        controllers.(DoF).(type) = VibrationController(type, ...
            "Fs"     , options.Fs     , ...
            "tau_lag", options.tau_lag, ...
            "solver" , options.solver   ...
        );
        controllers.(DoF).(type).set_disturbance_frd( ...
            TMT_disturbance.get_frd_model(DoF) + extra_disturbance_design_frd ...
        );
        controllers.(DoF).(type).set_flux_noise_rms( ...
            utils.get_flux_noise_rms(options.n_photons, ...
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
        controllers.(DoF).(type).design();
    end
end

%% Simulations -----------------------------------------------------------------
simulators = struct();

for DoF = ["tip", "tilt"]
    for type = ["int", "data"]
        simulators.(DoF).(type) = Simulator(options.Fs, options.tau_lag);
        simulators.(DoF).(type).set_controller(controllers.(DoF).(type));
        simulators.(DoF).(type).run(ts.(DoF) + extra_disturbance_sim, ts.noise);
    end
end

%% Simulation Results ----------------------------------------------------------
sim_data = utils.deepstructfun( ...
    @(x) x.result, ...
    simulators);

for DoF = ["tip", "tilt"]
    sim_data.(DoF).raw.disturbance = ts.(DoF).Data + extra_disturbance_sim.data;
    sim_data.(DoF).raw.noise = ts.noise.Data;
    sim_data.(DoF).raw.total = ts.(DoF).Data + ts.noise.Data + extra_disturbance_sim.data;
end

%% Get PSD data ----------------------------------------------------------------
N = length(ts.tip.Data);
window = hamming(N);

[psd_data, freq_data] = utils.deepstructfun(...
    @(x) pwelch(x, window, [], N, options.Fs_sim), ...
    sim_data);

% All freq_data are same
freq_data = freq_data.tip.data.disturbance;

%% RMS values of the error -----------------------------------------------------
freq_range = [0, options.Fs_sim/2];

rms_data = utils.deepstructfun(...
    @(x) sqrt(bandpower(x, freq_data, freq_range, 'psd')), ...
    psd_data);

%% Print RMS -------------------------------------------------------------------
% Clean the Command Window and print results
clc;

for DoF = ["tip", "tilt"]
    fprintf("%-46s\n", ...
        sprintf("<<-- %s -->> (Controller Order = %d)", DoF, order(controllers.(DoF).data.K)), ...
        sprintf("    Disturbance       => % 12.8f [mas]", rms_data.(DoF).raw.disturbance), ...
        sprintf("      * Integrator    => % 12.8f [mas]", rms_data.(DoF).int.disturbance), ...
        sprintf("      * Data          => % 12.8f [mas]", rms_data.(DoF).data.disturbance), ...
        sprintf("  ------------------------------------------  "), ...
        sprintf("    Flux Noise        => % 12.8f [mas]", rms_data.(DoF).raw.noise), ...
        sprintf("      * Integrator    => % 12.8f [mas]", rms_data.(DoF).int.noise), ...
        sprintf("      * Data          => % 12.8f [mas]", rms_data.(DoF).data.noise), ...
        sprintf("  ------------------------------------------  "), ...
        sprintf("    Total Noise       => % 12.8f [mas]", rms_data.(DoF).raw.total), ...
        sprintf("      * Integrator    => % 12.8f [mas]", rms_data.(DoF).int.total), ...
        sprintf("      * Data          => % 12.8f [mas]", rms_data.(DoF).data.total), ...
        sprintf("==============================================") ...
    );
end
fprintf("%-46s\n", ...
    sprintf("<<-- %s -->>", "Performance Gain/Loss"), ...
    sprintf("    * Tip             => % .2f [%%]", ...
        rms_data.tip.int.total / rms_data.tip.data.total * 100 - 100), ...
    sprintf("    * Tilt            => % .2f [%%]", ...
        rms_data.tilt.int.total / rms_data.tilt.data.total * 100 - 100), ...
    sprintf("==============================================") ...
);

if options.save_plot
    if ~isfolder(options.plot_folder)
        mkdir(options.plot_folder)
    end
    fileID = fopen(fullfile( ...
        options.plot_folder, ...
        sprintf("results_%s.tex", options.label) ...
    ), "w");


    table_base_fmt = sprintf("%s\n", ...
        "\\begin{table}[htbp]                                                               ", ...
        "    \\centering                                                                    ", ...
        "    \\caption[%s]{%s}                                                              ", ...
        "    \\label{tab:%s}                                                                ", ...
        "    \\begin{tabular}{@{}cc *3{S[table-format=2.8]} S[table-format=3.2] @{}}        ", ...
        "        \\toprule                                                                  ", ...
        "            & &                                                                    ", ...
        "            {\\multirow{3}[0]{*}{\\thead{Open-loop \\\\ RMS [mas] }}} &            ", ...
        "            \\multicolumn{2}{c}{\\thead{Closed-loop RMS [mas]}}  &                 ", ...
        "            {\\multirow{3}[0]{*}{\\thead{Performance \\\\ Gain/Loss [\\%%]}}} \\\\ ", ...
        "        \\cmidrule(lr){4-5}                                                        ", ...
        "            & & & {\\thead{Integrator \\\\ Controller}}                            ", ...
        "            & {\\thead{Data-driven \\\\ Controller}} & \\\\                        ", ...
        "        \\midrule                                                                  ", ...
        "%s                                                                                 ", ...
        "        \\bottomrule                                                               ", ...
        "    \\end{tabular}                                                                 ", ...
        "\\end{table}                                                                       ");

    table_data = struct();
    for DoF = ["tip", "tilt"]
        table_data.(DoF) = sprintf("            %s\n", ...
            sprintf( ...
                "{\\multirow{3}{*}{\\rotatebox[origin=c]{90}{%s}}}", ...
                regexprep(lower(DoF), "(^|\.)\s*.", "${upper($0)}")), ...
            sprintf( ...
                "    & Disturbance       & % 12.8f & % 12.8f & % 12.8f & % 7.2f \\\\", ...
                rms_data.(DoF).raw.disturbance, ...
                rms_data.(DoF).int.disturbance, ...
                rms_data.(DoF).data.disturbance, ...
                rms_data.(DoF).int.disturbance / rms_data.(DoF).data.disturbance * 100 - 100), ...
            sprintf( ...
                "    & Measurement Noise & % 12.8f & % 12.8f & % 12.8f & % 7.2f \\\\", ...
                rms_data.(DoF).raw.noise, ...
                rms_data.(DoF).int.noise, ...
                rms_data.(DoF).data.noise, ...
                rms_data.(DoF).int.noise / rms_data.(DoF).data.noise * 100 - 100), ...
            sprintf( ...
                "    & Total             & % 12.8f & % 12.8f & % 12.8f & % 7.2f \\\\", ...
                rms_data.(DoF).raw.disturbance, ...
                rms_data.(DoF).int.disturbance, ...
                rms_data.(DoF).data.disturbance, ...
                rms_data.(DoF).int.total / rms_data.(DoF).data.total * 100 - 100) ...
        );
    end
    
    fprintf(fileID, table_base_fmt, ...
        options.short_caption, ...
        options.caption, ...
        sprintf("result_%s", options.label), ...
        sprintf("%s\n", ...
            table_data.tip, ...
            "            \midrule", ...
            table_data.tilt));

    fclose(fileID);
end

%% Plot Bode -------------------------------------------------------------------

% Effect to consider
type = "total"; % {disturbance, noise, total}

colors = struct();
colors.raw  = "#000000";
colors.int  = "#D95319";
colors.data = "#0072BD";

fig = figure();
old_pos = fig.Position;
fig.Position = [old_pos(1:2) - 200, 660, 560];
if options.save_plot
    fig.Renderer = "painters";
    fig.Units = "centimeters";
    fig.PaperSize = fig.Position(3:4);
    fig.PaperUnits = "normalized";
    fig.PaperPosition = [0, 0, 1, 1];
end

t = tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact");
xlabel(t, "Frequency [Hz]");
ylabel(t, "PSD [mas]");
title(t, "PSD plot of closed-loop response");

for DoF = ["tip", "tilt"]
    h_plot = struct();
    ax = nexttile();    
    set(ax, 'XScale', 'log', 'YScale', 'log');
    hold on; box on; grid on;
    for controller = ["raw", "int", "data"]
        plot(freq_data, psd_data.(DoF).(controller).(type), ...
            "Color", colors.(controller), ...
            "LineStyle", "-", ...
            "LineWidth", 1 ...
        );
        h_plot.(controller) = plot([-inf, -inf], [0, 1], ...
            "Color", colors.(controller), ...
            "LineStyle", "-", ...
            "LineWidth", 2 ...
        );
    end
    xlim([1e-2, options.Fs_sim / 2]);
    ylim([10^-12, 10^4]);
    title(sprintf("%s", ...
        regexprep(lower(DoF), "(^|\.)\s*.", "${upper($0)}")));
end

legend([h_plot.raw, h_plot.int, h_plot.data], ...
    "Uncorrected", ...
    "Integrator controller", ...
    "Data-driven controller", ...
    "FontSize", 10, ...
    "Orientation", "horizontal", ...
    "Location", "northoutside");

if options.save_plot
    if ~isfolder(options.plot_folder)
        mkdir(options.plot_folder)
    end
    plot_filename = fullfile( ...
        options.plot_folder, ...
        sprintf("bode_%s", options.label) ...
    );
    print(fig, plot_filename, "-dpng", "-painters", "-r300");
    print(fig, plot_filename, "-dpdf", "-painters");

    fig.Color = "none";
    fig.InvertHardcopy = "off";
    print(fig, plot_filename, "-dsvg", "-painters");
    close(fig);
end
end