function set_continuous_model(obj)
    %set_continuous_model Set the continuous-time model of the system 
    % 

    % G1 (WFS + WFC)
    s = tf('s');
    WFS_sensor = (1 - exp(-obj.Ts * s)) / (obj.Ts * s);
    WFC = exp(-obj.tau_lag * s);
    obj.G1 = WFS_sensor * WFC;

    % G2 (DM)
    HF_filter = tf(1);
    DM_mirror = tf(1);
    obj.G2 = DM_mirror * HF_filter;
end