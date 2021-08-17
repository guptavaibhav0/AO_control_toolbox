function psd = get_atmospheric_psd(obj)
    %get_atmospheric_psd Converts disturbance PSD 'mas^2/Hz'
    % 
    %   psd = get_atmospheric_psd(obj) returns disturbance PSD in 'mas^2/Hz' due 
    %   to atmospheric turbulance for given telescope diameter and wavelength.
    % 
    
    D = obj.D;
    lambda = obj.lambda;

    % Tip/tilt atmospheric PSD in (radians of Zernike coefficients)^2 / Hz
    psd_rad = obj.get_TT_atmospheric_psd();

    % Convert from radians of Zernike coefficients to radians of image motion
    rad_Zernike_2_rad_image = 2 * lambda / (pi * D);
    
    % Convert from radians to mas
    rad2mas_conv_factor = rad_Zernike_2_rad_image * (180/pi * 3600 * 1e3);
    
    psd = psd_rad * rad2mas_conv_factor^2;    
end