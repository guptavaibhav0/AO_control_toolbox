function rms = get_flux_noise_rms(n_photons, options)
%get_flux_noise_rms Estimates RMS of flux noise
% 
%  rms = get_flux_noise_rms() estimates RMS of the flux noise for the spot size
%  of 8 mas and 16 photons per timestep.
% 
%  rms = get_flux_noise_rms(n_photons) estimates RMS of the flux noise for 
%  the given number of photons recieved per timestep, assuming spot size of
%  8 mas.
% 
%  Notes:
%    * Unit of `rms` is same as the unit of `spot_size`
% 

    arguments
        n_photons                 (1, :) double  = 16
        options.readout_noise     (1, 1) logical = false
        options.spot_size         (1, 1) double  = 8     % [mas]
        options.readout_noise_lvl (1, 1) double  = 3     % [electrons per pixel]  
    end

    % Photon Noise
    var_photon = n_photons;
    
    if options.readout_noise        
        % Assuming 4 pixels are involved in calculation of image position
        var_detector = 4 * options.readout_noise_lvl^2;
    else
        % Assume no detector noise
        var_detector = 0;
    end
    
    % Signal to Noise Ratio
    SNR = n_photons ./ sqrt(var_photon + var_detector);
    
    % RMS Calculation
    rms = 0.5 * options.spot_size ./ SNR;
end

