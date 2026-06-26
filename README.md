# ARBITER

Two-channel uncertainty-aware infrared spectral arbitration workflow for breast tissue microarray analysis.

This repository contains the MATLAB code, configuration files, figure outputs, tabulated results, and data-template files used for the locked two-channel ARBITER workflow described in the associated manuscript.

## Overview

ARBITER combines two cancer-oriented evidence channels for each valid tissue pixel:

1. a spectral baseline score derived from the preprocessed infrared spectrum, and
2. a prototype-derived score based on comparison with cancer-like and healthy-like reference spectral prototypes.

The two scores are fused and passed through an uncertainty-aware arbitration rule. Pixel-level outputs are reported as cancer-like, uncertain, or healthy-like. Core-level summaries are then obtained from the within-core fractions of these three decision classes.

## Repository structure

```text
ARBITER/
├── data/
│   ├── README_data_availability.md
│   └── templates/
├── figures/
│   ├── main/
│   └── supporting_information/
├── matlab/
│   ├── arbiter_config_paths.m
│   ├── README.md
│   ├── USAGE_paths.md
│   ├── run/
│   └── utils/
├── results/
│   └── reports/
│       └── tables/
├── CITATION.cff
├── LICENSE
├── README.md
└── REPRODUCIBILITY_NOTE.md
```

## Data availability

The primary breast tissue microarray dataset is publicly available from Zenodo:

**DOI:** 10.5281/zenodo.808456

Large raw and preprocessed imaging datasets are not included in this repository. Template files are provided under `data/templates/` to document the expected metadata structure.

## Requirements

The analysis scripts are written for MATLAB. The exact MATLAB release and installed toolboxes may affect plotting and table-export behavior. Update local paths in:

```text
matlab/arbiter_config_paths.m
```

before running the scripts.

## Main workflow scripts

The locked two-channel workflow and associated manuscript outputs are organized under `matlab/run/`. Key scripts include:

```text
run_19b_benchmark_ablation_validation_from_channel_scores.m
run_20b_export_core_channel_scores_from_precomp.m
run_21b_true_locked_core_decision_sensitivity.m
run_22_export_final_article_package.m
run_23g_export_spatial_maps_from_preproc_article_style.m
```

Additional scripts support expansion-cohort summaries, endpoint tables, power analysis, and acquisition-planning outputs.

## Results included

The repository includes tabulated outputs under:

```text
results/reports/tables/
```

and figure files under:

```text
figures/
```

These files are included to document the locked output state used for manuscript preparation.

## Reproducibility note

The public dataset should be downloaded separately from Zenodo. After downloading the data, edit `matlab/arbiter_config_paths.m` to match the local directory structure and run the scripts from the `matlab/run/` directory.

See `REPRODUCIBILITY_NOTE.md` for additional details.

## Citation

If you use this repository, please cite the associated manuscript and this repository. Citation metadata are provided in `CITATION.cff`.

## License

This repository is released under the MIT License. See `LICENSE`.
