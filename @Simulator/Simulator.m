 classdef Simulator < handle
    %Simulator Class for closed-loop simulations
    %
    %   Simulator Properties:
    %     * WFS        - Sensing component
    %     * DM         - Actuation component
    %     * controller - Vibration controller
    %     * result     - Structure of the simulation results
    %     * S          - Disturbance to error closed-loop transfer function
    %     * U          - Noise to error closed-loop transfer function
    % 
    %   Simulator Methods:
    %     * set_controller - Sets the vibration controller for the simulation
    %     * run            - Runs the LTI simulation of the closed loop 
    % 
    
    properties (SetAccess = private)
        WFS         % Sensing component
        DM          % Actuation component
        controller  % Vibration controller
        result      % Structure of the simulation results
        S           % Disturbance to error closed-loop transfer function
        U           % Noise to error closed-loop transfer function
    end
    
    methods
        function obj = Simulator(Fs, tau_lag)
            [obj.WFS, obj.DM] = obj.get_system_model(1/Fs, tau_lag);
        end

        function set_controller(obj, controller)
            %set_controller Sets the vibration controller for the simulation
            % 
            %   set_controller(obj, controller) sets the vibration controller
            %   and calculates the closed-loop transfer function.
            % 

            arguments
                obj
                controller (1, 1) VibrationController
            end
            obj.controller = controller;
            
            obj.S = feedback( ...
                1, ...
                series(obj.WFS, series(obj.controller.K_DAC, obj.DM)));

            obj.U = feedback( ...
                -series(obj.controller.K_DAC, obj.DM), ...
                obj.WFS, ...
                +1);
        end

    end
end