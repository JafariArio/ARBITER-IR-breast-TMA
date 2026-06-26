%% run_24_build_wave1_core_manifest
% Build the locked Wave 1 expansion manifest for 15 additional BR20832 cores.
%
% Fixed Wave 1 set:
%   A16, C14, E12, F2, F13, H3, I7, J9, J11, K6, L3, L8, L12, L16, M13
%
% Purpose:
%   - verify raw core .mat availability
%   - record preprocessed core availability
%   - record overlay inventory / overlay file availability
%   - write clean CSV manifests for downstream Wave 1 scripts
%
% Outputs (written under project_root\00_data\manifests):
%   wave1_core_list_v1.csv
%   wave1_core_metadata_v1.csv
%   wave1_label_audit_v1.csv
%   wave1_manifest_summary_v1.txt

clear; clc;

%% Bootstrap repository paths
thisFile  = mfilename('fullpath');
runDir    = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fileparts(matlabDir));
cfg = arbiter_config_paths();

%% Paths
projectRoot   = cfg.project_root;
rawCoreDir    = cfg.raw_cores_dir;
preprocDir    = cfg.interim_preproc_dir;
manifestDir   = cfg.manifest_dir;
reportDir     = cfg.report_dir;
overlayDir    = cfg.raw_overlays_dir;

if ~exist(manifestDir, 'dir')
    mkdir(manifestDir);
end

overlayInventoryCsv = fullfile(reportDir, 'overlay_inventory_v0.csv');

outListCsv   = fullfile(manifestDir, 'wave1_core_list_v1.csv');
outMetaCsv   = fullfile(manifestDir, 'wave1_core_metadata_v1.csv');
outAuditCsv  = fullfile(manifestDir, 'wave1_label_audit_v1.csv');
outTxt       = fullfile(manifestDir, 'wave1_manifest_summary_v1.txt');

%% Fixed Wave 1 IDs
core_id = string({'A16','C14','E12','F2','F13','H3','I7','J9','J11','K6','L3','L8','L12','L16','M13'})';
n = numel(core_id);

%% Preallocate
core_mat_path       = strings(n,1);
preproc_mat_path    = strings(n,1);
overlay_png_path    = strings(n,1);

available_core_mat  = strings(n,1);
available_preproc   = strings(n,1);
available_overlay   = strings(n,1);
available_he        = strings(n,1);
usable_now          = strings(n,1);

group_provisional   = repmat("unknown", n, 1);
label_source        = repmat("pending_BR20832_audit", n, 1);
notes               = strings(n,1);

overlay_pixels_any  = nan(n,1);

%% Optional overlay inventory
overlayInvCore = strings(0,1);
overlayInvAny  = [];
if isfile(overlayInventoryCsv)
    opts = detectImportOptions(overlayInventoryCsv, 'VariableNamingRule', 'preserve');
    for ii = 1:numel(opts.VariableTypes)
        opts.VariableTypes{ii} = 'string';
    end
    Tover = readtable(overlayInventoryCsv, opts);

    if ismember('coreName', Tover.Properties.VariableNames)
        overlayInvCore = upper(strtrim(string(Tover.coreName)));
    end

    if ismember('nAny', Tover.Properties.VariableNames)
        overlayInvAny = double(str2double(string(Tover.nAny)));
    end
end

%% Build rows
for i = 1:n
    cid = upper(strtrim(core_id(i)));

    thisCoreMat = fullfile(rawCoreDir, cid + ".mat");
    thisPreproc = fullfile(preprocDir, cid + "_preproc_v0.mat");
    thisOverlay = fullfile(overlayDir, cid + ".png");

    core_mat_path(i)    = thisCoreMat;
    preproc_mat_path(i) = thisPreproc;
    overlay_png_path(i) = thisOverlay;

    available_core_mat(i) = string(isfile(thisCoreMat));
    available_preproc(i)  = string(isfile(thisPreproc));

    hasOverlay = false;
    invIdx = find(overlayInvCore == cid, 1, 'first');
    if ~isempty(invIdx)
        hasOverlay = true;
        if ~isempty(overlayInvAny)
            overlay_pixels_any(i) = overlayInvAny(invIdx);
        end
    end
    if isfile(thisOverlay)
        hasOverlay = true;
    else
        overlay_png_path(i) = "";
    end
    available_overlay(i) = string(hasOverlay);

    available_he(i) = "serial-section-array-level";

    if available_core_mat(i) == "1"
        usable_now(i) = "yes";
    else
        usable_now(i) = "no";
        notes(i) = "missing raw core mat";
    end
end

available_core_mat(available_core_mat == "1") = "yes";
available_core_mat(available_core_mat ~= "yes") = "no";
available_preproc(available_preproc == "1") = "yes";
available_preproc(available_preproc ~= "yes") = "no";
available_overlay(available_overlay == "1") = "yes";
available_overlay(available_overlay ~= "yes") = "no";

%% Write outputs
Tlist = table(core_id);
writetable(Tlist, outListCsv);

Tmeta = table(core_id, core_mat_path, preproc_mat_path, overlay_png_path, ...
    available_core_mat, available_preproc, available_overlay, available_he, ...
    usable_now, overlay_pixels_any, group_provisional, label_source, notes);
writetable(Tmeta, outMetaCsv);

Taudit = table(core_id, repmat("",n,1), repmat("unknown",n,1), ...
    repmat("no",n,1), repmat("unknown",n,1), repmat("",n,1), ...
    'VariableNames', {'core_id','br20832_label','final_group', ...
                      'usable_for_confirmatory','usable_for_overlay_analysis','comments'});
writetable(Taudit, outAuditCsv);

fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open summary manifest for writing: %s', outTxt);

fprintf(fid, 'ARBITER Wave 1 manifest summary\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));
fprintf(fid, 'Project root: %s\n', projectRoot);
fprintf(fid, 'Raw core dir: %s\n', rawCoreDir);
fprintf(fid, 'Preproc dir : %s\n', preprocDir);
fprintf(fid, 'Overlay dir : %s\n\n', overlayDir);

fprintf(fid, 'Wave 1 cores (%d):\n', n);
for i = 1:n
    fprintf(fid, '  %s\n', core_id(i));
end
fprintf(fid, '\nAvailability summary:\n');
fprintf(fid, '  raw core mats available : %d/%d\n', sum(available_core_mat == "yes"), n);
fprintf(fid, '  preproc mats available  : %d/%d\n', sum(available_preproc == "yes"), n);
fprintf(fid, '  overlays available      : %d/%d\n', sum(available_overlay == "yes"), n);

fprintf(fid, '\nPer-core summary:\n');
for i = 1:n
    fprintf(fid, '  %-4s | raw=%s | preproc=%s | overlay=%s | usable=%s\n', ...
        core_id(i), available_core_mat(i), available_preproc(i), available_overlay(i), usable_now(i));
end
fclose(fid);

fprintf('\nWave 1 manifest built.\n');
fprintf('  Core list : %s\n', outListCsv);
fprintf('  Metadata  : %s\n', outMetaCsv);
fprintf('  Audit CSV : %s\n', outAuditCsv);
fprintf('  Summary   : %s\n\n', outTxt);

disp(Tmeta(:, {'core_id','available_core_mat','available_preproc','available_overlay','usable_now'}));
