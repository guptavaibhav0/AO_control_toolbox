function ts = get_narrowband_disturbance(rms, freq, bw, T, Fs, options)
%% TODO
    arguments
        rms             (1, 1) double
        freq            (1, 1) double
        bw              (1, 1) double
        T               (1, 1) double
        Fs              (1, 1) double
        options.method  (1, 1) string = "linear"   % "linear", "quadratic", "logarithmic"
    end

    %% Basic book-keeping ------------------------------------------------------
    time_data = 0:1/Fs:T;

    %% Timeseries --------------------------------------------------------------
    f_range = min([freq - bw/2, freq + bw/2], Fs / 2);

    ts_data = sqrt(2) * rms * chirp(time_data, ...
        f_range(1), T, f_range(2), options.method);
    
    % Generate timeseries
    ts = timeseries(...
        ts_data.', ...
        time_data, ...
        "Name", "Narrowband Disturbance" ...
    );


end