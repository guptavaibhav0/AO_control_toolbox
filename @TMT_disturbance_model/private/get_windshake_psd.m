function psd = get_windshake_psd(obj)
    %get_windshake_psd Computes TMT Windshake PSD for the given percentile
    % 
    %   psd = get_windshake_psd(obj) computes the PSD of due to windshake in the
    %   direction of the wind causing the telescope to shake in mas^2 / Hz.
    % 

    f = obj.w / 2 / pi;
    percentile = obj.percentile;

    % RMS Map for the different percentiles
    allowed_percentile = [50, 75, 85, 95];
    rms_map = [8.5, 20, 35, 75];

    % Select appropiate rms based on percentile
    rms = rms_map(percentile == allowed_percentile);

    % PSD function
    f0 = 0.08;
    f1 = 0.65;
    xi = 0.25;
    den = (1 + (f ./ f0).^2).^2 .* abs(1 + 1j * xi * f ./ f1 - (f ./ f1).^2).^2;
    num = f .^ 2;
    psd = num ./ den;

    % Normalize
    df = diff([0, f]);
    ms0 = sum(psd .* df);
    psd = psd ./ ms0 * rms^2;
end