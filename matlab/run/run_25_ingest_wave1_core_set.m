%% run_25_ingest_wave1_core_set
% Inspect the 15 Wave 1 cores and record lightweight ingestion metadata.
%
% This script does NOT rerun the model. It audits file presence, preprocessed
% core structure, feature dimensionality, tissue-mask size, and variable names.
%
% Inputs:
%   00_data\manifests\wave1_core_list_v1.csv
%
% Outputs:
%   00_data\outputs\reports_wave1\wave1_core_inventory_v1.csv
%   00_data\outputs\reports_wave1\wave1_core_inventory_v1.mat
%   00_data\outputs\reports_wave1\wave1_core_ingest_manifest_v1.txt

clear; clc;

%% Bootstrap repository paths
thisFile  = mfilename('fullpath');
runDir    = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fileparts(matlabDir));
cfg = arbiter_config_paths();

%% Paths
manifestDir = cfg.manifest_dir;
rawCoreDir  = cfg.raw_cores_dir;
preprocDir  = cfg.interim_preproc_dir;
wave1ReportDir = cfg.wave1_report_dir;

if ~exist(wave1ReportDir, 'dir')
    mkdir(wave1ReportDir);
end

inListCsv = fullfile(manifestDir, 'wave1_core_list_v1.csv');
outCsv    = fullfile(wave1ReportDir, 'wave1_core_inventory_v1.csv');
outMat    = fullfile(wave1ReportDir, 'wave1_core_inventory_v1.mat');
outTxt    = fullfile(wave1ReportDir, 'wave1_core_ingest_manifest_v1.txt');

assert(isfile(inListCsv), 'Missing file: %s. Run run_24_build_wave1_core_manifest first.', inListCsv);

opts = detectImportOptions(inListCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
Tlist = readtable(inListCsv, opts);

assert(ismember('core_id', Tlist.Properties.VariableNames), 'wave1_core_list_v1.csv must contain column core_id');
core_id = upper(strtrim(string(Tlist.core_id)));
n = numel(core_id);

%% Preallocate audit columns
raw_mat_path      = strings(n,1);
raw_exists        = strings(n,1);
raw_bytes         = nan(n,1);
raw_nvars         = nan(n,1);
raw_var_names     = strings(n,1);

preproc_mat_path  = strings(n,1);
preproc_exists    = strings(n,1);
preproc_bytes     = nan(n,1);
preproc_has_core  = strings(n,1);
nPixelsKept       = nan(n,1);
nFeatures         = nan(n,1);
tissueMaskRows    = nan(n,1);
tissueMaskCols    = nan(n,1);
wnLength          = nan(n,1);
ingest_status     = strings(n,1);
comments          = strings(n,1);

%% Audit loop
for i = 1:n
    cid = core_id(i);

    thisRaw = fullfile(rawCoreDir, cid + ".mat");
    thisPre = fullfile(preprocDir, cid + "_preproc_v0.mat");

    raw_mat_path(i) = thisRaw;
    preproc_mat_path(i) = thisPre;

    if isfile(thisRaw)
        d = dir(thisRaw);
        raw_exists(i) = "yes";
        raw_bytes(i) = d.bytes;

        try
            W = whos('-file', thisRaw);
            raw_nvars(i) = numel(W);
            if ~isempty(W)
                names = strings(numel(W),1);
                for k = 1:numel(W)
                    names(k) = string(W(k).name);
                end
                raw_var_names(i) = strjoin(names, ";");
            end
        catch ME
            raw_var_names(i) = "whos_failed";
            comments(i) = append(comments(i), " raw_whos_failed:", string(ME.message));
        end
    else
        raw_exists(i) = "no";
    end

    if isfile(thisPre)
        d = dir(thisPre);
        preproc_exists(i) = "yes";
        preproc_bytes(i) = d.bytes;

        try
            W = whos('-file', thisPre);
            hasCore = any(strcmp({W.name}, 'core'));
            if hasCore
                preproc_has_core(i) = "yes";
                S = load(thisPre, 'core');

                if isfield(S, 'core')
                    core = S.core;

                    if isstruct(core)
                        if isfield(core, 'X') && isnumeric(core.X)
                            nPixelsKept(i) = size(core.X, 1);
                            nFeatures(i)   = size(core.X, 2);
                        end

                        if isfield(core, 'wn') && isnumeric(core.wn)
                            wnLength(i) = numel(core.wn);
                        end

                        if isfield(core, 'tissueMask') && isnumeric(core.tissueMask)
                            tissueMaskRows(i) = size(core.tissueMask, 1);
                            tissueMaskCols(i) = size(core.tissueMask, 2);
                        end

                        if isfield(core, 'preprocInfo') && isstruct(core.preprocInfo)
                            if isfield(core.preprocInfo, 'nPixelsKept') && isnumeric(core.preprocInfo.nPixelsKept)
                                nPixelsKept(i) = double(core.preprocInfo.nPixelsKept);
                            end
                        end
                    end
                end
            else
                preproc_has_core(i) = "no";
                comments(i) = append(comments(i), " no_core_var_in_preproc_mat");
            end
        catch ME
            preproc_has_core(i) = "unknown";
            comments(i) = append(comments(i), " preproc_load_failed:", string(ME.message));
        end
    else
        preproc_exists(i) = "no";
        preproc_has_core(i) = "no";
    end

    if raw_exists(i) == "yes"
        if preproc_exists(i) == "yes" && preproc_has_core(i) == "yes"
            ingest_status(i) = "ready_for_locked_rerun";
        elseif preproc_exists(i) == "no"
            ingest_status(i) = "needs_preprocessing";
        else
            ingest_status(i) = "preproc_needs_manual_check";
        end
    else
        ingest_status(i) = "missing_raw_core";
    end
end

%% Write outputs
Tinv = table(core_id, raw_mat_path, raw_exists, raw_bytes, raw_nvars, raw_var_names, ...
    preproc_mat_path, preproc_exists, preproc_bytes, preproc_has_core, ...
    nPixelsKept, nFeatures, wnLength, tissueMaskRows, tissueMaskCols, ...
    ingest_status, comments);

writetable(Tinv, outCsv);
save(outMat, 'Tinv');

fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open ingest manifest for writing: %s', outTxt);
fprintf(fid, 'ARBITER Wave 1 ingest manifest\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));
fprintf(fid, 'Rows: %d\n\n', height(Tinv));
fprintf(fid, 'Status summary:\n');

uStatus = unique(Tinv.ingest_status);
for i = 1:numel(uStatus)
    fprintf(fid, '  %-28s : %d\n', uStatus(i), sum(Tinv.ingest_status == uStatus(i)));
end

fprintf(fid, '\nPer-core summary:\n');
for i = 1:height(Tinv)
    fprintf(fid, '  %-4s | raw=%s | preproc=%s | status=%s | nPix=%g | nFeat=%g\n', ...
        Tinv.core_id(i), Tinv.raw_exists(i), Tinv.preproc_exists(i), Tinv.ingest_status(i), ...
        Tinv.nPixelsKept(i), Tinv.nFeatures(i));
end
fclose(fid);

fprintf('\nWave 1 ingestion audit complete.\n');
fprintf('  CSV : %s\n', outCsv);
fprintf('  MAT : %s\n', outMat);
fprintf('  TXT : %s\n\n', outTxt);

disp(Tinv(:, {'core_id','raw_exists','preproc_exists','ingest_status','nPixelsKept','nFeatures'}));
