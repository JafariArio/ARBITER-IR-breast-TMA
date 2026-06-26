# MATLAB usage

Set the private project root once per session before running scripts that require local data:

```matlab
setenv('ARBITER_PROJECT_ROOT', 'E:\path\to\your\approved\ARBITER_project_root');
run('matlab/run/run_20b_export_core_channel_scores_from_precomp.m')
```

If `ARBITER_PROJECT_ROOT` is not set, scripts fall back to the repository root. That fallback is sufficient for browsing the packaged docs, figures, and result tables, but not for rerunning analyses that depend on private `.mat` cubes or preprocessed files.
