classdef VibrationController < handle
    %VibrationController Class for vibration controller
    %
    %   VibrationController Properties:
    %     * solver          - Solver for data-driven design
    %     * controller_type - Controller type to design
    %     * Ts              - Sampling Time of the controller
    %     * tau_lag         - WFC lag in AO system
    %     * flux_noise_rms  - RMS value of expected flux noise
    %     * parameters      - Controller hyper-parameters
    %     * K               - Designed 	
    %     * K_DAC           - Designed continuous-time controller
    %     * G1              - Transfer function of WFS + WFC
    %     * G2              - Transfer function of DM
    %     * disturbance_frd - FRD model of the disturbance
    % 
    %   VibrationController Methods:
    %     * set_disturbance_frd - Set FRD model of disturbance
    %     * update_parameter    - Set controller hyper-parameters
    %     * design              - Design vibration controller
    %     * save_to_fits        - Save vibration controller to a `.fits` file
    %
    
    properties (SetAccess = private)
        solver          (1, 1) string % Solver for data-driven design
        controller_type (1, 1) string % Controller type to design
        Ts              (1, 1) double % Sampling Time of the controller
        tau_lag         (1, 1) double % WFC lag in AO system
        flux_noise_rms  (1, 1) double % RMS value of expected flux noise
        parameters      (1, 1) struct % Controller hyper-parameters
        K                             % Designed discrete-time controller
        K_DAC                         % Designed continuous-time controller
        G1                            % Transfer function of WFS + WFC
        G2                            % Transfer function of DM
        disturbance_frd = []          % FRD model of the disturbance
    end
    
    methods
        function obj = VibrationController(controller_type, options)
            %VibrationController Initialise vibration controller class
            %   
            %   obj = VibrationController(controller_type) return the class
            %   object of specified controller type. Supported controller
            %   types are: 
            %     * "integrator", "int", or "type_1"
            %     * "type_2"
            %     * "data", or "datadriven"
            %   
            %   obj = VibrationController(___, Name, Value) return the class
            %   object of specified controller type.
            %
            %   Name-Value Pair Arguments:
            %     |---------|--------------------------------------------------|
            %     | Name    | Description                                      |
            %     |---------|--------------------------------------------------|
            %     | Fs      | Sampling frequency of the controller in Hz       |
            %     |         |   Default: 1                                     |
            %     |---------|--------------------------------------------------|
            %     | tau_lag | WFC lag in AO system in seconds                  |
            %     |         |   Default: 1                                     |
            %     |---------|--------------------------------------------------|
            %     | solver  | Solver for data-driven design                    |
            %     |         |   Default: "mosek"                               |
            %     |---------|--------------------------------------------------|
            % 

            arguments
                controller_type (1, 1) string
                options.Fs      (1, 1) double = 1
                options.tau_lag (1, 1) double = 1
                options.solver  (1, 1) string = "mosek"
            end
            obj.Ts = 1 / options.Fs;
            obj.tau_lag = options.tau_lag;
            obj.solver = options.solver;
            
            
            obj.flux_noise_rms = 0; % No flux noise by default
            
            switch lower(controller_type)
                case {"int", "integrator", "type_1"}
                    obj.controller_type = "integrator";
                    obj.set_continuous_model();
                case {"type_2"}
                    obj.controller_type = "type_2";
                    obj.set_continuous_model();
                case {"data", "datadriven"}
                    obj.controller_type = "datadriven";
                    obj.set_discrete_model();
                otherwise
                    error("Unknown Controller Type!");
            end
            
            obj.set_default_parameters();
        end
        
        function set_disturbance_frd(obj, disturbance_frd)
            %set_disturbance_frd Set FRD model of disturbance
            %
            %   set_disturbance_frd(obj, disturbance_frd) sets FRD model of the
            %   disturbance.
            %

            if isa(disturbance_frd, 'lti')
                obj.disturbance_frd = disturbance_frd;
            else
                error("Disturbance FRD must be a `frd` or equivalent class");
            end
        end
        
        function set_flux_noise_rms(obj, flux_noise_rms)
            %set_flux_noise_rms Set RMS value of flux noise
            %
            %   set_flux_noise_rms(obj, flux_noise_rms) sets RMS value of the
            %   expected flux noise.
            %

            arguments
                obj
                flux_noise_rms (1, 1) double
            end
            
            obj.flux_noise_rms = flux_noise_rms;
        end
        
        function update_parameter(obj, parameter_name, parameter_value)
            %update_parameter Set controller hyper-parameters
            %
            %   update_parameter(obj, parameter_name, parameter_value) sets 
            %   value of the hyper-parameters of the controller.
            % 
            %   Valid parameter names:
            %     |-----------------|----------------|------------|
            %     | Controller type | Parameter name | Value type |
            %     |-----------------|----------------|------------|
            %     | Integrator      | gain           | double     |
            %     |-----------------|----------------|------------|
            %     | Type_2          | gain           | double     |
            %     |-----------------|----------------|------------|
            %     | Datadriven      | gain           | double     |
            %     |                 | order          | double     |
            %     |                 | bandwidth      | double     |
            %     |                 | alpha          | double     |
            %     |-----------------|----------------|------------|
            %

            arguments
                obj
            end
            arguments (Repeating)
                parameter_name  (1, 1) string
                parameter_value (1, 1) double
            end
            
            for i = 1:length(parameter_name)
                if isfield(obj.parameters, parameter_name{i})
                    obj.parameters.(parameter_name{i}) = parameter_value{i};
                else
                    % Skip any invalid parameter name
                    warning(...
                        "VibrationController:update_parameter:invalid_parameter", ...
                        "Parameter name '%s' is invalid for controller type '%s'", ...
                        parameter_name{i}, obj.controller_type);
                end
            end
            
        end
    end
    
    methods (Access = private)
        function set_default_parameters(obj)
            %set_default_parameters Set default controller hyper-parameters
            % 

            switch obj.controller_type
                %----------------------------------------------------------
                case "integrator"
                    obj.parameters = struct("gain", 0.63);
                %----------------------------------------------------------
                case "type_2"
                    obj.parameters = struct("gain", 0.63);
                %----------------------------------------------------------
                case "datadriven"
                    obj.parameters = struct( ...
                        "gain"      , 0.63  , ...
                        "order"     , 10    , ...
                        "bandwidth" , 50    , ...
                        "alpha"     , 40    );
                %----------------------------------------------------------
                otherwise
                    error("Unknown Controller Type!");
            end
        end        
    end
end

