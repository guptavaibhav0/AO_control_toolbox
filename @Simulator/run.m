function run(obj, ts_disturbance, ts_noise)
    %run Runs the LTI simulation of the closed loop 
    % 
    %   run(obj, ts_disturbance, ts_noise) simulates the closed loop with given
    %   disturbance and noise timeseries.
    % 

    arguments
        obj
        ts_disturbance  (1, 1) timeseries
        ts_noise        (1, 1) timeseries
    end
    
    obj.result = struct();

    obj.result.disturbance = lsim(obj.S, ...
        ts_disturbance.Data, ...
        ts_disturbance.Time);
        
    obj.result.noise = lsim(obj.U, ts_noise.Data, ts_noise.Time);

    obj.result.total = obj.result.disturbance + obj.result.noise;
end

