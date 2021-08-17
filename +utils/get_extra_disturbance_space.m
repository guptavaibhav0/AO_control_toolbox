function extra_disturbance_space = get_extra_disturbance_space(extra_type)
    switch extra_type
        case "chirp"
            extra_disturbance_space = 1:2:21;       % [mas]
            extra_disturbance_space = extra_disturbance_space(:);
        case "narrowband"
            rms_space = 1:2:21;         % [mas]
            freq_space = 40:5:50;       % [Hz]
            bandwidth_space = 6:6:30;   % [Hz]
            
            extra_grid = cell(3, 1);
            [extra_grid{:}] = ndgrid(...
                rms_space, ...
                freq_space, ...
                bandwidth_space);

            extra_disturbance_space = [...
                extra_grid{1}(:), ...
                extra_grid{2}(:), ...
                extra_grid{3}(:)  ...
            ];
        otherwise
            % Dummy value in case of no extra disturbance
            extra_disturbance_space = 0;
    end
end