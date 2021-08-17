function ts = get_chirp_disturbance(rms, T, Fs, options)

    arguments
        rms             (1, 1) double
        T               (1, 1) double
        Fs              (1, 1) double
        options.method  (1, 1) string = "linear"   % "linear", "quadratic", "logarithmic"
    end

    %% Basic book-keeping ------------------------------------------------------
    time_data = 0:1/Fs:T;

    %% Timeseries --------------------------------------------------------------
    ts_data = sqrt(2) * rms * chirp(time_data, 0, T, Fs / 2, options.method);
    
    % Generate timeseries
    ts = timeseries(...
        ts_data.', ...
        time_data, ...
        "Name", "Chirp Disturbance" ...
    );

end