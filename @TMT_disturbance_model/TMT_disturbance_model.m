classdef TMT_disturbance_model < handle
    %TMT_disturbance_model Class for disturbance of TMT
    %
    %   TMT_disturbance_model Properties:
    %     * Fs_sim          - Simulation sampling frequency [Hz]
    %     * w               - Frequency vector [rad]
    %     * D               - Telescope diameter [m]
    %     * lambda          - Light wavelength [m]
    %     * instrument_gain - Gain for instrument disturbance
    %     * r0              - Fried's parameter
    %     * v               - Wind Speed [m/s]
    %     * L0              - External scale of turbulance [m]
    %     * percentile      - Scale of windshake for TMT
    %
    %   TMT_disturbance_model Read-only Properties:
    %     * psd                 - 
    %     * psd_tip             - Net disturbance in tip
    %     * psd_tilt            - Net disturbance in tilt
    %     * psd_atmospheric     - Atmospheric disturbance
    %     * psd_windshake       - Windshake disturbance
    %     * psd_instrument_tip  - Instrument disturbance in tip
    %     * psd_instrument_tilt - Instrument disturbance in tilt
    % 
    %   TMT_disturbance_model Methods:
    %     * add_instrument_disturbance - Add instrument PSD from a FITS file
    %     * get_frd_model              - Get FRD model
    %     * get_ts                     - Get timeseries data
    % 

    properties (Access = public)
        Fs_sim          (1, 1) double = NaN    % Simulation sampling frequency [Hz]
        w               (1, :) double          % Frequency vector [rad]
        D               (1, 1) double = 30     % Telescope diameter [m]
        lambda          (1, 1) double = 0.5e-6 % Light wavelength [m]
        instrument_gain (1, 1) double = 1      % Gain for instrument disturbance

        % r0 - Fried's parameter
        %   Some expected values are:
        %     * 0.08 - bad atmospheric condition
        %     * 0.15 - ok atmospheric condition
        %     * 0.30 - good atmospheric condition
        r0 (1, 1) double = 0.15

        % v - Wind Speed [m/s]
        %   Nominal range of values are in the range [5, 50].
        v (1, 1) double = 10
        
        % L0 - External scale of turbulance [m]
        %   Nominal range of value are in range [15, 40]
        L0 (1, 1) double = 30   

        % percentile - Scale of windshake for TMT
        %   Must be a member of set {50, 75, 85, 95}
        percentile (1, 1) double {mustBeMember(percentile, [50, 75, 85, 95])} = 50
    end
    
    properties (SetAccess = private)
        psd                 (1, :) double   % 
        psd_tip             (1, :) double   % Net disturbance in tip
        psd_tilt            (1, :) double   % Net disturbance in tilt
        psd_atmospheric     (1, :) double   % Atmospheric disturbance
        psd_windshake       (1, :) double   % Windshake disturbance
        psd_instrument_tip  (1, :) double   % Instrument disturbance in tip
        psd_instrument_tilt (1, :) double   % Instrument disturbance in tilt
    end
    
    properties (Access = private)
        Fs_instrument                (1, 1) double = NaN % Instrument sampling frequency
        psd_instrument_tip_unscaled  (1, :) double       % Raw instrument disturbance in tip
        psd_instrument_tilt_unscaled (1, :) double       % Raw instrument disturbance in tilt
    end
    
    %%% Set methods ------------------------------------------------------------
    methods
        function set.instrument_gain(obj, instrument_gain)
            obj.instrument_gain = instrument_gain;
            obj.reset_psd(false);
        end
        
        function set.percentile(obj, percentile)
            obj.percentile = percentile;
            obj.reset_psd();
        end
        
        function set.v(obj, v)
            obj.v = v;
            obj.reset_psd();
        end
        
        function set.r0(obj, r0)
            obj.r0 = r0;
            obj.reset_psd();
        end
        
        function set.L0(obj, L0)
            obj.L0 = L0;
            obj.reset_psd();
        end

        function set.Fs_sim(obj, Fs)
            %set.Fs_sim Set simulation frequency used for generating FRD models
            % and timeseries from PSD.
            obj.Fs_sim = Fs;
            obj.verify_simulation_frequecy();
        end
    end

    %%% Get methods ------------------------------------------------------------
    methods
        function psd = get.psd(obj)
            if isempty(obj.psd)
                obj.psd = obj.psd_atmospheric + obj.psd_windshake;
            end
            psd = obj.psd;
        end

        function psd_tip = get.psd_tip(obj)
            if isempty(obj.psd_tip)
                if isempty(obj.psd_instrument_tip)
                    obj.psd_tip = obj.psd;
                else
                    obj.psd_tip = obj.psd + obj.psd_instrument_tip;
                end
            end
            psd_tip = obj.psd_tip;
        end

        function psd_tilt = get.psd_tilt(obj)
            if isempty(obj.psd_tilt)
                if isempty(obj.psd_instrument_tilt)
                    obj.psd_tilt = obj.psd;
                else
                    obj.psd_tilt = obj.psd + obj.psd_instrument_tilt;
                end
            end
            psd_tilt = obj.psd_tilt;
        end

        function psd_atmospheric = get.psd_atmospheric(obj)
            if isempty(obj.psd_atmospheric)
                obj.psd_atmospheric = obj.get_atmospheric_psd();
            end
            psd_atmospheric = obj.psd_atmospheric;
        end

        function psd_windshake = get.psd_windshake(obj)
            if isempty(obj.psd_windshake)
                obj.psd_windshake = obj.get_windshake_psd();
            end
            psd_windshake = obj.psd_windshake;
        end
        
        function psd_instrument_tip = get.psd_instrument_tip(obj)
            if isempty(obj.psd_instrument_tip)
                obj.psd_instrument_tip = ...
                    obj.psd_instrument_tip_unscaled * obj.instrument_gain;
            end
            psd_instrument_tip = obj.psd_instrument_tip;
        end
        
        function psd_instrument_tilt = get.psd_instrument_tilt(obj)
            if isempty(obj.psd_instrument_tilt)
                obj.psd_instrument_tilt = ...
                    obj.psd_instrument_tilt_unscaled * obj.instrument_gain;
            end
            psd_instrument_tilt = obj.psd_instrument_tilt;
        end

    end

    %%% Public method ----------------------------------------------------------
    methods (Access = public)
        function add_instrument_disturbance(obj, fits_filename, Fs)
            %add_instrument_disturbance Add instrument PSD from a FITS file.
            % 
            %   add_instrument_disturbance(obj, fits_filename, Fs) reads
            %   timeseries data from `fits_filename` sampled at Fs, and saves
            %   disturbance PSD in mas^2/Hz.
            % 
            
            % Load FITS to timeseries
            data = fitsread(fits_filename);
            data = data(:, 1:end-1).';  % Remove ending 0 from the time series
            tip  = data(:, 1);
            tilt = data(:, 2);
            
            % Instrument disturbance PSD
            obj.Fs_instrument = Fs;
            [obj.psd_instrument_tip_unscaled, ~] = ...
                pwelch(tip, [], [], obj.w / 2 / pi, obj.Fs_instrument);

            [obj.psd_instrument_tilt_unscaled, ~] = ...
                pwelch(tilt, [], [], obj.w / 2 / pi, obj.Fs_instrument);
            
            % Convert from 'nm^2/Hz' to 'mas^2/Hz'
            obj.psd_instrument_tip_unscaled  = ...
                obj.psd_instrument_tip_unscaled  * (1000 / 36)^2;
            obj.psd_instrument_tilt_unscaled = ...
                obj.psd_instrument_tilt_unscaled * (1000 / 36)^2;
            
            % Verify simulation sampling frequency
            obj.verify_simulation_frequecy();
        end

        function frd_model = get_frd_model(obj, DoF)
            %get_frd_model Get FRD model of desired degree of freedom.
            % 
            %   frd_model = get_frd_model(obj, DoF) returns FRD model of desired
            %   degree of freedom (DoF). Accepted DoF are:
            %     * "tip"   : atmospheric + instrument tip
            %     * "tilt"  : atmospheric + instrument tilt
            %     * "atm"   : atmospheric only
            % 

            arguments
                obj
                DoF string
            end
            
            switch lower(DoF)
                case "tip"
                    frd_model = frd(sqrt(obj.psd_tip) , obj.w, 1 / obj.Fs_sim);
                case "tilt"
                    frd_model = frd(sqrt(obj.psd_tilt), obj.w, 1 / obj.Fs_sim);
                otherwise
                    frd_model = frd(sqrt(obj.psd)     , obj.w, 1 / obj.Fs_sim);
            end
        end
        
        function ts = get_ts(obj, DoF, T)
            %get_ts Get timeseries data for desired degree of freedom.
            % 
            %   ts = get_ts(obj, DoF, T) returns timeseries of desired degree of
            %   freedom (DoF) for T seconds. Accepted DoF are:
            %     * "tip"   : atmospheric + instrument tip
            %     * "tilt"  : atmospheric + instrument tilt
            %     * "atm"   : atmospheric only
            % 

            arguments
                obj
                DoF string
                T (1, 1) double = 100   % Max time of signal [s] 
            end
            
            switch lower(DoF)
                case "tip"
                    ts = get_ts_from_psd(obj.w/2/pi, obj.psd_tip, T, obj.Fs_sim);
                case "tilt"
                    ts = get_ts_from_psd(obj.w/2/pi, obj.psd_tilt, T, obj.Fs_sim);
                otherwise
                    ts = get_ts_from_psd(obj.w/2/pi, obj.psd, T, obj.Fs_sim);
            end            
        end
    end
    
    %%% Helper Functions -------------------------------------------------------
    methods (Access = private)
        function reset_psd(obj, complete_reset)
            %reset_psd Clears stored PSDs
            %
            %   reset_psd(obj) clears all PSDs.
            % 
            %   reset_psd(obj, false) clears only insturment disturbance PSDs.
            % 

            arguments
                obj
                complete_reset (1, 1) logical = true
            end
            
            obj.psd_tip = [];
            obj.psd_tilt = [];
            obj.psd_instrument_tip = [];
            obj.psd_instrument_tilt = [];
            if complete_reset
                obj.psd = [];
                obj.psd_atmospheric = [];
                obj.psd_windshake = [];
            end
        end

        function verify_simulation_frequecy(obj)
            %verify_simulation_frequecy Verifies simulation frequency
            % 

            if ~isnan(obj.Fs_instrument) && isnan(obj.Fs_sim)
                obj.Fs_sim = obj.Fs_instrument;
            elseif ~isnan(obj.Fs_instrument) && (obj.Fs_instrument < obj.Fs_sim)
                warning("TMT_disturbance_model:add_instrument_disturbance:verify_simulation_frequecy", ...
                "Desired simulation frequency is more than maximum possible simulation frequency. Setting simulation frequency to maximum possible simulation frequency.");
                obj.Fs_sim = obj.Fs_instrument;
            end
        end
    end
end