function K = design_datadriven(obj, verbose)
    %design_datadriven Data-driven vibration controller design
    %
    %   design_datadriven(obj) designs the controller in verbose mode.
    %
    %   design_datadriven(___, false) designs the controller in silent mode.
    %

    arguments
        obj
        verbose (1, 1) logical = true;
    end
    
    if isempty(obj.disturbance_frd)
        warning("VibrationController:design:disturbance_psd", "\n\t%s", ...
            "Disturbance FRD object is not defined.", ...
            "Assuming band-limited white noise with rms of 1 [mas]." ...
        );
        obj.disturbance_frd = tf(1 * 2 * obj.Ts);
    end

    if obj.flux_noise_rms == 0
        warning("VibrationController:design:flux_noise_rms", "\n\t%s", ...
            "RMS value of expected flux noise is set to 0.", ...
            "Ignoring effects of flux noise." ...
        );
    end
    
    z = tf('z', obj.Ts);
    plant_model = obj.G1 * obj.G2;

    %% Initial Controller
    G_int = 1 / (1 - z^-1);
    K_init = obj.parameters.gain * G_int;

    CL = 1 / (1 + K_init * plant_model);
    if any(abs(pole(CL)) > 1)
        error("Unstabilizing Initial Controller!");        
    end

    %% Data driven Controller
    omega_b = obj.parameters.bandwidth*2*pi;   % bandwidth
    
    W1 = obj.disturbance_frd;
    val = freqresp(W1, omega_b);
    W1 = W1 / abs(val) / obj.parameters.alpha / obj.flux_noise_rms / 1.1;
    
    % omega_W3 = (1/obj.Ts)*pi;   % Low freq noise suppresion
    % W3 = get_weight(1.1, omega_W3, 0.9, obj.Ts);
    W3 = tf(1, 1, obj.Ts);

    [num, den] = tfdata(K_init, 'v');
    den(obj.parameters.order + 1) = 0; % zero padding
    num(obj.parameters.order + 1) = 0; % zero padding
    
    Fx = 1;
    Fy = [1, -1];
    
    num_new = deconv(num, Fx);
    den_new = deconv(den, Fy);
    
    [SYS, OBJ, CON, PAR] = datadriven.utils.emptyStruct(); % load empty structure
    ctrl = struct( ...
        'num', num_new, ...
        'den', den_new, ...
        'Ts', obj.Ts, ...
        'Fx', Fx, ...
        'Fy', Fy); % assemble controller
    
    SYS.controller = ctrl;
    SYS.model = plant_model;
    SYS.W = logspace(0.1, log10(pi / obj.Ts), 1e2);
    
    OBJ.o2.W1 = W1;
    OBJ.o2.W3 = W3;
        
    tic
    [controller, ~] = datadriven.datadriven(SYS, OBJ, CON, PAR, verbose, obj.solver);
    elapsedTime = toc;
    
    if verbose
        fprintf("Controller found in %.6f seconds.\n", elapsedTime)
    end

    K = datadriven.utils.toTF(controller);
    K = minreal(K, 1e-3);
    
    CL = 1 / (1 + K * plant_model);
    if any(abs(pole(CL)) > 1)
        error("Unstabilizing Controller!");        
    end

end

%--------------------------------------------------------------------------
% Helper Functions
%-------------------------------------------------------------------------
function W = get_weight(DC, MID, HF, Ts)
    % Order (N) = 1
    if isscalar(MID)
       freq = MID;   mag = 1;
    else
       freq = MID(1);  mag = MID(2);
    end
    p = freq * sqrt(((HF/mag)^2-1)/(1-(DC/mag)^2)); % pole
    if Ts==0
        W = tf([HF DC*p],[1 p]);
    else
        % Apply bilinear transform to continuous-time solution 
        bt = freq*sin(freq*Ts)/(cos(freq*Ts)-1);
        W = tf([DC*p-HF*bt DC*p+HF*bt],[p-bt p+bt],Ts);
    end
    W = ss(W);
end

