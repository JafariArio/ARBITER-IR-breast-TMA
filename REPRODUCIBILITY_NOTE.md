# Reproducibility note

This repository contains the locked MATLAB code, output tables, figures, and metadata templates for the two-channel ARBITER workflow.

## Data

The primary breast TMA dataset is available from Zenodo:

DOI: 10.5281/zenodo.808456

The repository does not include the full raw or preprocessed imaging data. Download the dataset separately and update the local paths before running the code.

## Path configuration

Edit:

```text
matlab/arbiter_config_paths.m
```

to point to the local locations of input data, intermediate files, and output folders.

## Suggested run order

The main locked-output scripts are located in:

```text
matlab/run/
```

For reproducing the manuscript-level outputs, start with the scripts that export channel scores, benchmark summaries, sensitivity analysis, spatial maps, and final article tables. Some scripts require precomputed intermediate data files derived from the Zenodo dataset.

## Included outputs

The repository includes:

- main and supporting figure files,
- tabulated result summaries,
- MATLAB run scripts,
- utility functions,
- metadata templates.

These outputs document the locked analysis state used for manuscript preparation.
