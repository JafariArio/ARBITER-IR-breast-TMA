# MATLAB code

This directory contains the MATLAB implementation used for the locked two-channel ARBITER workflow and associated manuscript outputs.

## Structure

```text
matlab/
├─ arbiter_config_paths.m
├─ USAGE_paths.md
├─ run/
└─ utils/
```

## Main scripts

Use the following scripts for the primary analysis path:

1. `run_20b_export_core_channel_scores_from_precomp.m`
2. `run_19b_benchmark_ablation_validation_from_channel_scores.m`
3. `run_21b_true_locked_core_decision_sensitivity.m`
4. `run_22_export_final_article_package.m`
5. `run_23g_export_spatial_maps_from_preproc_article_style.m`

Additional scripts provide cohort-extension summaries, endpoint tables, power calculations, and acquisition-planning outputs.

## Utilities

Shared helper functions are stored in `matlab/utils/`.

## Local paths

Configure local paths through `arbiter_config_paths.m` or by setting the environment variable `ARBITER_PROJECT_ROOT` before running scripts that require private local spectral data.
