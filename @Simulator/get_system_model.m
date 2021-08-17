function [WFS, DM] = get_system_model(~, Ts, tau_lag)
    %get_system_model Returns system model for simulations
    % 
    %   [WFS, DM] = get_system_model(~, Ts, tau_lag) returns the sensing
    %   component (WFS) and actuator component (DM).
    % 

    s = tf('s');

    WFS_sensor = (1 - exp(-Ts * s)) / (Ts * s);
    WFC = exp(-tau_lag * s);    % computation lag

    HF_filter = tf(1);
    DM_mirror = tf(1);

    WFS = WFC * WFS_sensor;
    DM = DM_mirror * HF_filter;
end