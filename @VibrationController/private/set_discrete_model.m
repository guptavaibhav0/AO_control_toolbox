function set_discrete_model(obj)
    %set_discrete_model Set the discrete-time model of the system 
    % 

    % G1 (WFS + WFC)
    z = tf('z', obj.Ts);
    WFS_sensor = z^-1 * (z + 1) / 2;
    lag = z^(-ceil(obj.tau_lag / obj.Ts));
    obj.G1 = WFS_sensor * lag;

    % G2 (DM)
    HF_filter = tf(1);
    DM_mirror = tf(1);
    obj.G2 = DM_mirror * HF_filter;
end
