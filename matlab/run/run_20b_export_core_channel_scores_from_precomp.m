%% run_20b_export_core_channel_scores_from_precomp
% Recover the real 21-core channel-level score table from fusion_precompute_v1.mat
% and merge it with the locked 2-channel fused summary.
%
% This script intentionally avoids over-merging downstream report files.
% It uses only:
%   1) fusion_precompute_v1.mat  -> per-core pBase / pProto vectors
%   2) ARBITER_best_setting_summary_v1.mat -> locked fused summary
%   3) ARBITER_core_truth_template_v1.csv  -> group/subset/truth metadata (if present)
%
% Outputs:
%   00_data\outputs\reports\ARBITER_core_channel_scores_v1.mat
%   00_data\outputs\reports\ARBITER_core_channel_scores_v1.csv
%   00_data\outputs\reports\ARBITER_core_channel_scores_manifest_v1.txt

clear; clc;

%% Bootstrap repository paths
thisFile = mfilename('fullpath');
runDir   = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fullfile(matlabDir, 'utils'));
cfg = arbiter_config_paths();

rootDir    = cfg.project_root;
reportDir  = fullfile(rootDir, '00_data', 'outputs', 'reports');

precompMat = fullfile(reportDir, 'fusion_precompute_v1.mat');
bestMat    = fullfile(reportDir, 'ARBITER_best_setting_summary_v1.mat');
truthCsv   = fullfile(reportDir, 'ARBITER_core_truth_template_v1.csv');

outMat     = fullfile(reportDir, 'ARBITER_core_channel_scores_v1.mat');
outCsv     = fullfile(reportDir, 'ARBITER_core_channel_scores_v1.csv');
outTxt     = fullfile(reportDir, 'ARBITER_core_channel_scores_manifest_v1.txt');

assert(isfile(precompMat), 'Missing file: %s', precompMat);
assert(isfile(bestMat),    'Missing file: %s', bestMat);

%% Load precomputed channel evidence
S = load(precompMat);
assert(isfield(S, 'precomp'), 'fusion_precompute_v1.mat does not contain variable "precomp".');
precomp = S.precomp;
coreIds = string(fieldnames(precomp));
nCores  = numel(coreIds);

meanPBaseline  = nan(nCores,1);
meanPPrototype = nan(nCores,1);
nPixBase       = zeros(nCores,1);
nPixProto      = zeros(nCores,1);

for i = 1:nCores
    cid = coreIds(i);
    entry = precomp.(char(cid));

    if isfield(entry, 'pBase') && isnumeric(entry.pBase)
        v = double(entry.pBase(:));
        meanPBaseline(i) = mean(v, 'omitnan');
        nPixBase(i)      = sum(~isnan(v));
    end

    if isfield(entry, 'pProto') && isnumeric(entry.pProto)
        v = double(entry.pProto(:));
        meanPPrototype(i) = mean(v, 'omitnan');
        nPixProto(i)      = sum(~isnan(v));
    end
end

Tpre = table(coreIds, meanPBaseline, meanPPrototype, nPixBase, nPixProto, ...
    'VariableNames', {'coreId','meanPBaseline','meanPPrototype','nPixBase','nPixProto'});

%% Load locked fused summary
B = load(bestMat);
assert(isfield(B, 'Tbest'), 'ARBITER_best_setting_summary_v1.mat does not contain variable "Tbest".');
Tbest = B.Tbest;
assert(istable(Tbest), 'Tbest must be a table.');

% Normalize names
vn = string(Tbest.Properties.VariableNames);

mapOld = ["coreName","groupName","meanPFuse","meanUncFuse","fracLikelyCancer", ...
          "fracLikelyHealthy","fracUncertain","coreDecision"];
mapNew = ["coreId","group","meanPFuse","meanUncFuse","fracLikelyCancer", ...
          "fracLikelyHealthy","fracUncertain","coreDecision"];

for k = 1:numel(mapOld)
    hit = find(strcmpi(vn, mapOld(k)), 1, 'first');
    if ~isempty(hit)
        vn(hit) = mapNew(k);
    end
end
Tbest.Properties.VariableNames = cellstr(vn);

neededBest = {'coreId','group','meanPFuse','meanUncFuse','fracLikelyCancer','fracLikelyHealthy','fracUncertain','coreDecision'};
for k = 1:numel(neededBest)
    assert(ismember(neededBest{k}, Tbest.Properties.VariableNames), ...
        'Missing required variable "%s" in Tbest.', neededBest{k});
end

if iscell(Tbest.coreId),       Tbest.coreId = string(Tbest.coreId); end
if ischar(Tbest.coreId),       Tbest.coreId = string(cellstr(Tbest.coreId)); end
if iscell(Tbest.group),        Tbest.group = string(Tbest.group); end
if ischar(Tbest.group),        Tbest.group = string(cellstr(Tbest.group)); end
if iscell(Tbest.coreDecision), Tbest.coreDecision = string(Tbest.coreDecision); end
if ischar(Tbest.coreDecision), Tbest.coreDecision = string(cellstr(Tbest.coreDecision)); end

Tbest = Tbest(:, neededBest);

%% Merge precomp with locked summary
T = outerjoin(Tbest, Tpre, ...
    'Keys', 'coreId', ...
    'MergeKeys', true, ...
    'Type', 'left');

%% Merge truth template if available
if isfile(truthCsv)
    opts = detectImportOptions(truthCsv, 'VariableNamingRule', 'preserve');
    for ii = 1:numel(opts.VariableTypes)
        opts.VariableTypes{ii} = 'string';
    end
    Ttruth = readtable(truthCsv, opts);

    % Normalize names
    vnt = string(Ttruth.Properties.VariableNames);
    hit = find(strcmpi(vnt, "CoreID"), 1, 'first');           if ~isempty(hit), vnt(hit) = "coreId"; end
    hit = find(strcmpi(vnt, "Group"), 1, 'first');            if ~isempty(hit), vnt(hit) = "truthGroup"; end
    hit = find(strcmpi(vnt, "Subset"), 1, 'first');           if ~isempty(hit), vnt(hit) = "subset"; end
    hit = find(strcmpi(vnt, "TrueLabel"), 1, 'first');        if ~isempty(hit), vnt(hit) = "trueLabel"; end
    hit = find(strcmpi(vnt, "UseForValidation"), 1, 'first'); if ~isempty(hit), vnt(hit) = "useForValidation"; end
    Ttruth.Properties.VariableNames = cellstr(vnt);

    if ismember('coreId', Ttruth.Properties.VariableNames)
        if iscell(Ttruth.coreId), Ttruth.coreId = string(Ttruth.coreId); end
        if ischar(Ttruth.coreId), Ttruth.coreId = string(cellstr(Ttruth.coreId)); end

        keepTruth = intersect({'coreId','truthGroup','subset','trueLabel','useForValidation'}, Ttruth.Properties.VariableNames, 'stable');
        Ttruth = Ttruth(:, keepTruth);

        T = outerjoin(T, Ttruth, ...
            'Keys', 'coreId', ...
            'MergeKeys', true, ...
            'Type', 'left');
    end
end

%% Final normalization and derived columns
if ~ismember('subset', T.Properties.VariableNames)
    T.subset = repmat("", height(T), 1);
end
if ~ismember('trueLabel', T.Properties.VariableNames)
    T.trueLabel = repmat("", height(T), 1);
end
if ~ismember('useForValidation', T.Properties.VariableNames)
    T.useForValidation = repmat("", height(T), 1);
end

if iscell(T.subset),            T.subset = string(T.subset); end
if iscell(T.trueLabel),         T.trueLabel = string(T.trueLabel); end
if iscell(T.useForValidation),  T.useForValidation = string(T.useForValidation); end

T.coreId            = string(T.coreId);
T.group             = string(T.group);
T.subset            = string(T.subset);
T.trueLabel         = string(T.trueLabel);
T.useForValidation  = string(T.useForValidation);
T.coreDecision      = string(T.coreDecision);

% Standardize subset labels if missing
missingSubset = strlength(strtrim(T.subset)) == 0;
T.subset(missingSubset & startsWith(T.group, "NAT", 'IgnoreCase', true)) = "NaT";
T.subset(missingSubset & ~startsWith(T.group, "NAT", 'IgnoreCase', true)) = "Reference";

% Add simple benchmark-friendly fused variants from recovered channels
T.meanPEqualWeight       = mean([T.meanPBaseline, T.meanPPrototype], 2, 'omitnan');
T.meanPLockedAlphaNoGate = 0.90 .* T.meanPBaseline + 0.10 .* T.meanPPrototype;

% Sort in a stable biological order
ord = strings(height(T),1);
for i = 1:height(T)
    c = T.coreId(i);
    if startsWith(c, "L")
        ord(i) = "1_" + c;
    elseif startsWith(c, "E")
        ord(i) = "2_" + c;
    elseif startsWith(c, "M")
        ord(i) = "3_" + c;
    else
        ord(i) = "9_" + c;
    end
end
[~, idx] = sort(ord);
T = T(idx, :);

%% Write outputs
save(outMat, 'T');
writetable(T, outCsv);

fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open manifest for writing: %s', outTxt);

fprintf(fid, 'ARBITER core channel score export from fusion_precompute_v1.mat\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));
fprintf(fid, 'Rows exported: %d\n', height(T));
fprintf(fid, 'Unique core IDs: %d\n\n', numel(unique(T.coreId)));

fprintf(fid, 'Coverage summary:\n');
fprintf(fid, '  meanPBaseline          : %d/%d\n', sum(~isnan(T.meanPBaseline)), height(T));
fprintf(fid, '  meanPPrototype         : %d/%d\n', sum(~isnan(T.meanPPrototype)), height(T));
fprintf(fid, '  meanPEqualWeight       : %d/%d\n', sum(~isnan(T.meanPEqualWeight)), height(T));
fprintf(fid, '  meanPLockedAlphaNoGate : %d/%d\n', sum(~isnan(T.meanPLockedAlphaNoGate)), height(T));
fprintf(fid, '  meanPFuse              : %d/%d\n', sum(~isnan(T.meanPFuse)), height(T));
fprintf(fid, '  meanUncFuse            : %d/%d\n', sum(~isnan(T.meanUncFuse)), height(T));
fprintf(fid, '  fracLikelyCancer       : %d/%d\n', sum(~isnan(T.fracLikelyCancer)), height(T));
fprintf(fid, '  fracLikelyHealthy      : %d/%d\n', sum(~isnan(T.fracLikelyHealthy)), height(T));
fprintf(fid, '  fracUncertain          : %d/%d\n\n', sum(~isnan(T.fracUncertain)), height(T));

fprintf(fid, 'Sources used:\n');
fprintf(fid, '  %s [precomp]\n', precompMat);
fprintf(fid, '  %s [Tbest]\n', bestMat);
if isfile(truthCsv)
    fprintf(fid, '  %s [truth template]\n', truthCsv);
end
fclose(fid);

%% Console summary
fprintf('\nSaved core channel score table:\n  %s\n', outCsv);
fprintf('Saved manifest:\n  %s\n', outTxt);

fprintf('\nRows exported: %d\n', height(T));
fprintf('\nCoverage summary:\n');
fprintf('  meanPBaseline          : %d/%d\n', sum(~isnan(T.meanPBaseline)), height(T));
fprintf('  meanPPrototype         : %d/%d\n', sum(~isnan(T.meanPPrototype)), height(T));
fprintf('  meanPEqualWeight       : %d/%d\n', sum(~isnan(T.meanPEqualWeight)), height(T));
fprintf('  meanPLockedAlphaNoGate : %d/%d\n', sum(~isnan(T.meanPLockedAlphaNoGate)), height(T));
fprintf('  meanPFuse              : %d/%d\n', sum(~isnan(T.meanPFuse)), height(T));
fprintf('  meanUncFuse            : %d/%d\n', sum(~isnan(T.meanUncFuse)), height(T));

fprintf('\nPreview:\n');
disp(T(:, {'coreId','group','subset','meanPBaseline','meanPPrototype','meanPEqualWeight', ...
           'meanPLockedAlphaNoGate','meanPFuse','meanUncFuse','coreDecision'}));
