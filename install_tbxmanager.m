%%install_tbxmanager Installation of tbxmanager with all the required submodules
% 

clearvars; close all; clc;

fprintf("%-80s\n", ...
    sprintf("%s", repmat("-", 80, 1)), ...
    "Installation of the Toolbox manager (`tbxmanager`)", ...
    sprintf("%s", repmat("-", 80, 1)), ...
    "Choose the installation directory where to install the Toolbox manager.", ...
    "A new folder 'tbxmanager' is going to be created in the specified location.", ...
    "If you do not specify the folder, the Toolbox manager will be installed in", ...
    "the current directory." ...
);

% Get the desired installation folder
current_dir = pwd;
c = uigetdir(userpath);
if isequal(c, 0)
    fprintf("%-80s\n", ...
        "No directory has been provided.", ... 
        "Installing the toolbox manager in the default user directory", ...
        sprintf("`%s`.", userpath) ...
    );
    c = userpath;
end
 
% Create a new directory in that folder
d = fullfile(c, "tbxmanager");
if isequal(exist(d, "dir"), 7)
    warning("install_tbxmanager:directory_exists", "%s\n", ...
        sprintf("The installation directory '%s' already exists.", d), ...
        "Please, remove or rename the folder or change the installation path.", ...
        "Assuming that toolbox is already installed.");
    return;
end

fprintf("Creating the directory 'tbxmanager'.");
out = mkdir(d);
if ~out
    error("install_tbxmanager:mkdir_error", "%s\n", ...
        sprintf("An error appear when trying to create the folder '%s'.", d), ...
        "Please, install the Toolbox manager manually.");
end

% Enter that directory
cd(d);

% Remove MPT2 or YALMIP (if exists)
fprintf("\nRemoving toolboxes that may conflict with MPT from the Matlab path.\n");
rmpath(genpath(fileparts(which('mpt_init'))));
rmpath(genpath(fileparts(which('yalmipdemo'))));

% Download tbxmanager
fprintf("\nDownloading the Toolbox manager from the internet.\n");
f = websave("tbxmanager.m", "http://www.tbxmanager.com/tbxmanager.m");

% Install all required modules
tbxmanager install sedumi yalmip 

% Get back to the original directory
cd(current_dir);

% add path to tbxmanager
fprintf("\nAdding path to Matlab.\n");
addpath(d);

% save path for future
fprintf("\nSaving path for future sessions.\n");
status = savepath;

if status
    fprintf("%s\n", ...
        "Could not save the path to a default location,", ...
        "please provide a location where you want to save the path.");
    cn = uigetdir(pwd);
    if isequal(cn,0)
        fprintf("\nNo directory specified, saving the path to the current directory '%s'.\n", ...
            current_dir);
        cn = current_dir;
    end
    sn = savepath(fullfile(cn, "pathdef.m"));
    if sn
        error("install_tbxmanager:path_not_set", "%s\n", ...
            "Could not save the path automatically.",...
            "Please, open the 'Set Path' button in the Matlab menu and", ...
            "save the path manually to some location.");
    end
end

fprintf("\nInstallation finished!!!\n");
