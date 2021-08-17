function psd = get_TT_atmospheric_psd(obj)
    %get_TT_atmospheric_psd Calculates tip/tilt disturbance PSD due to
    %atmospheric turbulance.
    % 
    %   psd = get_TT_atmospheric_psd(obj) returns ons-sided disturbance PSD of
    %   tip/tilt Zernike coefficients in 'radian^2 / Hz' of Zernike coefficient
    %   due to atmospheric turbulance for given telescope diameter and light
    %   wavelength.
    % 
    %   Notes:
    %     * Calculation based on `TMT.AOS.TEC.05.008.REL01`
    %     * If L0 >= 1000, then L0 is assumed to be infinite.
    %

    f  = obj.w/2/pi;
    D  = obj.D;
    r0 = obj.r0;
    v  = obj.v;
    L0 = obj.L0;

    if L0 < 1000
        varDL0 = D / L0;
    else
        varDL0 = 0;
    end

    int_fn = @(s, x) besselj(2, s*pi./cos(x)).^2 .* (s^2./cos(x).^2 + varDL0^2).^(-11/6);
    fn_G = @(s) 0.074/s * integral(@(x) int_fn(s, x), 0, pi/2);

    % PSD
    psd = (D/r0)^(5/3) .* D/v .* arrayfun(fn_G, f*D/v);
    psd = abs(psd); % Ensure positive psd
end