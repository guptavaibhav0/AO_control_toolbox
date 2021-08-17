function ts = get_ts_from_psd(f, psd, T, Fs)
    %get_ts_from_psd Generates a random timesseries from a one-sided PSD
    % 
    %   ts = get_ts_from_psd(f, psd, T, Fs) generates a random timeseries from
    %   the one-sided PSD `psd`. Timeseries has a sampling frequency of Fs Hz
    %   and maximum time of T seconds.
    % 

    %%% Basic book-keeping -----------------------------------------------------
    % Select appropiate freq. range
    if f(end) < Fs / 2 - 1e-6
        % Raise error if 
        error("TMT_disturbance_model:get_ts_from_psd:not_implemented", ...
            "Not implemented!");
    end
    % Cut the PSD to Nyquist frequency
    psd = psd(f < Fs/2);
    f = f(f < Fs/2);

    % Resample from log to linear frequency vector assuming single-sided psd
    psd = resample(psd, f, T + 1/Fs, 1, 1);
    
    % Convert from single-sided PSD to double-sided PSD
    double_sided_psd = single_to_double_sided_psd(psd, f(1) == 0);

    % Ensure that end time is correct
    T = length(double_sided_psd) / Fs;
    N = round(Fs * T);

    %%% White Noise ------------------------------------------------------------
    % Generate 'Perfect' white noise in the frequency domain
    if mod(N, 2) ~= 0
        Nhalf = (N - 1) / 2;
    else
        Nhalf = N / 2 - 1;
    end

    rms_level = 1;
    randnums = rand(1, Nhalf) * 2 * pi;     % Random phase between 0 and 2pi
    randvalues = rms_level * exp(1i * randnums);

    % Create linear spectrum for white noise
    if mod(N, 2) == 0
        linspecPositiveFreq = [rms_level, randvalues, rms_level]; % + Freqs
    else
        linspecPositiveFreq = [rms_level, randvalues];   % + Freqs
    end
    linspecNegativeFreq = flip(conj(randvalues));        % - Freqs

    % Need this order for IFFT in MATLAB
    noiseLinSpec = [linspecPositiveFreq, linspecNegativeFreq];

    %%% Signal Linear Spectrum -------------------------------------------------
    % Magnitude of Linear Spectrum [unit * sec]
    Xm_mag = sqrt(double_sided_psd .* T);

    % Multiply noise and double-sided signal linear spectra in frequency-domain
    totalWaveLinSpec = Xm_mag .* noiseLinSpec;  % [unit]

    %%% Timeseries -------------------------------------------------------------
    % Convert double-sided PSD to timeseries in time domain via IFFT and math
    % Ensure that there is no imaginary part (should be all real anyway)
    ts_data = real(ifft(totalWaveLinSpec) * N / T); % [unit]
    
    % Generate timeseries
    ts = timeseries(...
        ts_data.', ...
        0:1/Fs:(T - 1/Fs), ...
        "Name", "Disturbance" ...
    );
end