%% run_33_acquisition_quota_manifest
% Build the operational acquisition quota manifest for the expanded study.
%
% Inputs:
%   00_data\outputs\reports\ARBITER_expanded_study_target_table_v1.csv
%
% Outputs:
%   00_data\manifests\ARBITER_acquisition_quota_manifest_v1.csv
%   00_data\manifests\ARBITER_acquisition_quota_manifest_v1.mat
%   00_data\manifests\ARBITER_acquisition_quota_manifest_v1.txt

clear; clc;

%% Bootstrap paths
thisFile  = mfilename('fullpath');
runDir    = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fullfile(matlabDir, 'utils'));
cfg = arbiter_config_paths();

%% Paths
inCsv  = fullfile(cfg.report_dir, 'ARBITER_expanded_study_target_table_v1.csv');
outCsv = fullfile(cfg.manifest_dir, 'ARBITER_acquisition_quota_manifest_v1.csv');
outMat = fullfile(cfg.manifest_dir, 'ARBITER_acquisition_quota_manifest_v1.mat');
outTxt = fullfile(cfg.manifest_dir, 'ARBITER_acquisition_quota_manifest_v1.txt');

assert(isfile(inCsv), 'Missing target table: %s. Run run_32_expanded_study_target_table first.', inCsv);
if ~exist(cfg.manifest_dir, 'dir')
    mkdir(cfg.manifest_dir);
end

%% Read target table
opts = detectImportOptions(inCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes); opts.VariableTypes{ii} = 'string'; end
T = readtable(inCsv, opts);
numVars = {'CurrentCount','RequirementFor80Power','RequirementFor90Power','RecommendedTotal','AdditionalNeeded'};
for i = 1:numel(numVars)
    if ismember(numVars{i}, T.Properties.VariableNames)
        T.(numVars{i}) = double(str2double(string(T.(numVars{i}))));
    end
end
T.TargetComponent = strtrim(string(T.TargetComponent));

idxNat = find(T.TargetComponent == "Evaluable normal-adjacent tissue cores total", 1, 'first');
idxRef = find(T.TargetComponent == "Reference cores total", 1, 'first');
idxReserve = find(T.TargetComponent == "Reserve cores", 1, 'first');
assert(~isempty(idxNat) && ~isempty(idxRef) && ~isempty(idxReserve), 'Target table missing required rows.');

addNat = T.AdditionalNeeded(idxNat);
addRef = T.AdditionalNeeded(idxRef);
addReserve = T.AdditionalNeeded(idxReserve);

tumorRefAdd = floor(addRef / 2);
healthyRefAdd = addRef - tumorRefAdd;

QuotaID = ["Q1"; "Q2"; "Q3"; "Q4"];
AcquisitionCategory = ["ambiguous_NaT_or_margin_like"; ...
                       "additional_tumor_reference"; ...
                       "additional_healthy_reference"; ...
                       "reserve_label_audited_core"];
TargetAdditionalCores = [addNat; tumorRefAdd; healthyRefAdd; addReserve];
Priority = ["high"; "high"; "high"; "medium"];
AnalysisRole = ["confirmatory"; "confirmatory"; "confirmatory"; "operational"];
Rationale = ["Power the primary endpoint on evaluable normal-adjacent tissue cores"; ...
             "Stabilize reference conservative-accuracy safeguard"; ...
             "Stabilize reference conservative-accuracy safeguard"; ...
             "Buffer for exclusions, failed registration, or pathology audit changes"];
PreferredCharacteristics = ["NaT, margin-like, heterogeneous, ambiguous, transitional"; ...
                            "clean tumor-reference cores with strong pathology confidence"; ...
                            "clean healthy/benign reference cores with strong pathology confidence"; ...
                            "any audited backup core"];
Status = repmat("planned", 4, 1);

Q = table(QuotaID, AcquisitionCategory, TargetAdditionalCores, Priority, AnalysisRole, ...
          Rationale, PreferredCharacteristics, Status);

writetable(Q, outCsv);
save(outMat, 'Q', 'T', 'addNat', 'addRef', 'addReserve', 'tumorRefAdd', 'healthyRefAdd');

fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open output text file: %s', outTxt);
fprintf(fid, 'ARBITER expanded-study acquisition quota manifest\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));
fprintf(fid, 'This manifest operationalizes the locked acquisition-planning outputs.\n\n');
for i = 1:height(Q)
    fprintf(fid, '%s | %s\n', Q.QuotaID(i), Q.AcquisitionCategory(i));
    fprintf(fid, '  Target additional cores : %d\n', Q.TargetAdditionalCores(i));
    fprintf(fid, '  Priority                : %s\n', Q.Priority(i));
    fprintf(fid, '  Analysis role           : %s\n', Q.AnalysisRole(i));
    fprintf(fid, '  Preferred characteristics: %s\n', Q.PreferredCharacteristics(i));
    fprintf(fid, '  Rationale               : %s\n\n', Q.Rationale(i));
end
fprintf(fid, 'Recommended total expansion implied by this manifest: %d cores.\n', sum(Q.TargetAdditionalCores));
fclose(fid);

fprintf('\nAcquisition quota manifest saved:\n  %s\n', outCsv);
fprintf('Manifest text saved:\n  %s\n', outTxt);
fprintf('\nAcquisition quota summary:\n');
disp(Q);
