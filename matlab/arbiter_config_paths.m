function cfg = arbiter_config_paths(project_root_override)
%ARBITER_CONFIG_PATHS Central path configuration for the locked 2-channel
% breast-TMA pilot repository.
%
% Usage:
%   cfg = arbiter_config_paths();
%   cfg = arbiter_config_paths('E:\MyProject\ARBITER_V0_MATLAB');
%
% Priority for project_root:
%   1) explicit function input
%   2) environment variable ARBITER_PROJECT_ROOT
%   3) repository root (allows browsing packaged docs/results only)

if nargin < 1
    project_root_override = '';
end

thisFile = mfilename('fullpath');
matlabDir = fileparts(thisFile);
repoRoot = fileparts(matlabDir);

envRoot = getenv('ARBITER_PROJECT_ROOT');
if ~isempty(project_root_override)
    projectRoot = project_root_override;
elseif ~isempty(envRoot)
    projectRoot = envRoot;
else
    projectRoot = repoRoot;
end

cfg = struct();
cfg.repo_root = repoRoot;
cfg.matlab_root = matlabDir;
cfg.project_root = projectRoot;

% Private / local project tree expected for full reruns
cfg.raw_cores_dir = fullfile(projectRoot, '00_data', 'raw', 'cores');
cfg.outputs_root = fullfile(projectRoot, '00_data', 'outputs');
cfg.report_dir = fullfile(cfg.outputs_root, 'reports');
cfg.figure_dir = fullfile(cfg.outputs_root, 'figures');

cfg.raw_overlays_dir = fullfile(projectRoot, '00_data', 'raw', 'overlays');
cfg.raw_he_dir = fullfile(projectRoot, '00_data', 'raw', 'he');
cfg.interim_root = fullfile(projectRoot, '00_data', 'interim');
cfg.interim_preproc_dir = fullfile(cfg.interim_root, 'preproc');
cfg.manifest_dir = fullfile(projectRoot, '00_data', 'manifests');
cfg.model_dir = fullfile(cfg.outputs_root, 'models');
cfg.maps_dir = fullfile(cfg.outputs_root, 'maps');
cfg.wave1_maps_dir = fullfile(cfg.outputs_root, 'maps_wave1');
cfg.wave1_figure_dir = fullfile(cfg.outputs_root, 'figures_wave1');
cfg.wave1_report_dir = fullfile(cfg.outputs_root, 'reports_wave1');

% Packaged repository-facing material
cfg.docs_manuscript_dir = fullfile(repoRoot, 'docs', 'manuscript');
cfg.docs_si_dir = fullfile(repoRoot, 'docs', 'supporting_information');
cfg.repo_main_fig_dir = fullfile(repoRoot, 'figures', 'main');
cfg.repo_si_fig_dir = fullfile(repoRoot, 'figures', 'supporting_information');
cfg.repo_results_dir = fullfile(repoRoot, 'results', 'reports');
end
