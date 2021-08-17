function design(obj, verbose)
    %design Design vibration controller
    %
    %   design(obj) designs the controller in verbose mode.
    %
    %   design(___, false) designs the controller in silent mode.
    %

    arguments
        obj
        verbose (1, 1) logical = true;
    end
   
    z = tf('z', obj.Ts);

    switch obj.controller_type
        %-----------------------------------------------------------------------
        case "integrator"
            G_int = 1 / (1 - z^-1);
            obj.K = obj.parameters.gain * G_int;
            obj.K_DAC = d2c(obj.K, 'tustin');
        %-----------------------------------------------------------------------
        case "type_2"
            % Double Integrator
            G_int = d2c(1 / (1 - z^-1), 'tustin');
            K_temp = obj.parameters.gain * G_int * G_int;
            [~, phase_margin, ~, crossover_freq] = margin(...
                obj.G2 * K_temp * obj.G1 ...
            );
            phase_lead = 45 - phase_margin; % [deg]
            a = (1 - sind(phase_lead)) / (1 + sind(phase_lead));
            Tl = 1 / (crossover_freq * sqrt(a));
            G_lead = sqrt(a) * (1 + Tl * s) / (1 + a * Tl * s);

            obj.K_DAC = K_temp * G_lead;
            obj.K = c2d(obj.K_DAC, obj.Ts, 'tustin');
        %-----------------------------------------------------------------------
        case "datadriven"
            obj.K = obj.design_datadriven(verbose);
            obj.K_DAC = d2c(obj.K, 'tustin');
        %-----------------------------------------------------------------------
        otherwise
            error("Unknown Controller Type!");
    end

end