function ts = get_white_noise(rms, T, Fs)
    %get_white_noise Generates a white noise timeseries
    % 
    %   ts = get_white_noise(rms, T, Fs) generates a white noise timeseries with
    %   `rms` value for T seconds. Timeseries has a sampling frequency of Fs Hz.
    % 

    arguments
        rms (1, 1) double
        T   (1, 1) double
        Fs  (1, 1) double
    end

    %% Basic book-keeping ------------------------------------------------------
    time_data = 0:1/Fs:T;
    N = length(time_data);

    %% White Noise -------------------------------------------------------------
    % Generate 'Perfect' white noise in the frequency domain
    if mod(N, 2) ~= 0
        Nhalf = (N - 1) / 2;
    else
        Nhalf = N / 2 - 1;
    end

    rms_level = rms;
    randnums = rand(1, Nhalf) * 2 * pi;     % Random phase between 0 and 2pi
    randvalues = rms_level * exp(1i * randnums);

    % Create linear spectrum for white noise
    if mod(N, 2) == 0
        linspecPositiveFreq = [rms_level, randvalues, rms_level]; % + Freqs
    else
        linspecPositiveFreq = [rms_level, randvalues];   % + Freqs
    end
    linspecNegativeFreq = flip(conj(randvalues));        % - Freqs

    % Need this order for IFFT in MATLAB:
    noiseLinSpec = [linspecPositiveFreq, linspecNegativeFreq];

    %% Timeseries --------------------------------------------------------------
    % Convert double-sided PSD to timeseries in time domain via IFFT and math
    % Ensure that there is no imaginary part (should be all real anyway)
    ts_data = real(ifft(noiseLinSpec) * sqrt(N));
    
    % Generate timeseries
    ts = timeseries(...
        ts_data.', ...
        time_data, ...
        "Name", "White Noise" ...
    );
end