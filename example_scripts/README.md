# Example Scripts

Before proceding, perform one of the following:
* Add this folder to the MATLAB path
* Copy the scripts to the base folder of the toolbox

--------------------------------------------------------------------------------
## MATLAB environment setup
Update [`MATLAB_environment_setup.m`](MATLAB_environment_setup.m) to refer to environment conditions on your PC. 

**Note** For HPC (non-interactive sessions), always add path but for interactive sessions, adding only once should be enough.

--------------------------------------------------------------------------------
## Integrator optimisation
Files [`search_integrator_env_hpc.m`](search_integrator_env_hpc.m) and [`search_integrator_env.m`](search_integrator_env.m) perform grid search on integrator parameters for all desired environments (controller frequency and photon flux). Use '*_hpc' version to perform parallel search on HPC or in non-interactive sessions.

Once, search has been done for all environments. Use following command to generate optimised paramter values.
```matlab
    utils.save_optimised_integrator_params()
```

--------------------------------------------------------------------------------
## Datadriven controller optimisation
Files [`search_datadriven_env_hpc.m`](search_datadriven_env_hpc.m) and [`search_datadriven_env.m`](search_datadriven_env.m) perform grid search on datadriven controller parameters for all desired environments (controller frequency and photon flux). Use '*_hpc' version to perform parallel search on HPC or in non-interactive sessions.

Once, search has been done for all environments. Use following command to generate optimised paramter values.
```matlab
    utils.save_optimised_datadriven_params()
```

**Note** For this, optimisation for parameters of integrator controller should have been performed.

--------------------------------------------------------------------------------
## Compare controllers
Use script [`compare_controllers.m`](compare_controllers.m) for quick comparison between integrator and datadriven controller under different simulation conditions.

**Note** For this, optimisation for parameters of both integrator and data-driven controller should have been performed.

--------------------------------------------------------------------------------
## Varying atmospheric study
Use script [`plot_varying_atmospheric_study.m`](plot_varying_atmospheric_study.m) to perform and plot results for effect of atmospheric variations on controller performance.

**Note** For this, optimisation for parameters of both integrator and data-driven controller should have been performed.

--------------------------------------------------------------------------------
## Authors
- [Vaibhav Gupta](https://github.com/guptavaibhav0)