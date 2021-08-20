function save_to_fits(obj, filename)

    arguments
        obj
        filename (1, 1) string;
    end

    % Discrete_time controller
    [num, den] = tfdata(obj.K);

    switch obj.controller_type
        case "datadriven"
            order = obj.parameters.order;
            num = [num{1}, zeros(1, order - length(num{1}) + 1)];
            den = [den{1}, zeros(1, order - length(den{1}) + 1)];
        otherwise
            num = num{1};
            den = den{1};
    end

    filename = strcat(filename, ".fits");
    fitswrite([num; den], filename)

end