# Data-driven Vibration Control for AO Systems

This toolbox gives a vibration controller for a given atmospheric disturbance PSD as an IIR filter.

--------------------------------------------------------------------------------
## Required Softwares
- **MATLAB** (2019b or newer)
    - Control System Toolbox
    - Signal Processing Toolbox
    - Statistics and Machine Learning Toolbox
- **Toolbox manager** (`tbxmanager`) for MATLAB
    - yalmip
    - sedumi
- **MOSEK** version 9.2 (not necessary but recommended)

### Installation Instructions

#### Toolbox manager
- Run script [`install_tbxmanager.m`](install_tbxmanager.m) to install Toolbox manager with all required modules.

#### Mosek
- Download appropiate installer from [MOSEK](https://www.mosek.com/downloads/) website and install the software.
- For academic uses, a [free license](https://www.mosek.com/products/academic-licenses/) could be requested. For commercial purposes, a 30-day [trial license](https://www.mosek.com/products/trial/) is also available.

--------------------------------------------------------------------------------
## Basic Usage Instructions

Class [`VibrationController`](@VibrationController/VibrationController.m) is the main class used for designing the vibration controller.

Code snippet for designing a data-driven controller:
```matlab
datadriven_controller = VibrationController("data", ...
    "Fs"     , Fs     , ...
    "tau_lag", tau_lag, ...
    "solver" , solver   ...
);
datadriven_controller.set_disturbance_frd(frd_model);
datadriven_controller.set_flux_noise_rms(flux_noise_rms);
datadriven_controller.update_parameter(...
    "gain"      , controller_gain     , ...
    "order"     , controller_order    , ...
    "bandwidth" , controller_bandwidth, ...
    "alpha"     , controller_alpha    );
datadriven_controller.design();
```
--------------------------------------------------------------------------------
## Example Scripts Usage Instructions

### Data for NFIRAOS simulations
- Download the zip file from https://drive.google.com/file/d/1xdgeeRBSaC-Su6anWAzlzDQ36rKvfqc2/view?usp=sharing
- Extract the zip file to `data` folder

### Other READMEs
* Refer to [this README](+utility_functions/README.md) for usage instructions on the utility functions.
* Refer to [this README](example_scripts/README.md) for usage instructions on the example scripts.

--------------------------------------------------------------------------------
## Authors
- [Vaibhav Gupta](https://github.com/guptavaibhav0)