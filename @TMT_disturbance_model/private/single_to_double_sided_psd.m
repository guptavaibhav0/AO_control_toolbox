function double_sided_psd = single_to_double_sided_psd(single_sided_psd, dc_power_available)
    %single_to_double_sided_psd Convert from single-sided PSD to double-sided PSD
    % 
    %   double_sided_psd = single_to_double_sided_psd(single_sided_psd) returns
    %   double-sided PSD assuming that the DC power is available in the PSD.
    % 
    %   double_sided_psd = single_to_double_sided_psd(___, false) returns 
    %   double-sided PSD assuming that the DC power is 0.
    % 

    arguments
        single_sided_psd (1, :)
        dc_power_available (1, 1) logical = true
    end

    if ~dc_power_available
        single_sided_psd = [0, single_sided_psd];
    end

    positive_freq_psd = single_sided_psd / 2;
    negative_freq_psd = flip(conj(positive_freq_psd(2:end-1)));

    double_sided_psd = [positive_freq_psd, negative_freq_psd];

end