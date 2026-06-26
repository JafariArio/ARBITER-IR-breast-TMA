%% run_21b_true_locked_core_decision_sensitivity
% Exact sensitivity analysis using the TRUE locked per-core fraction outputs.
%
% This script does NOT use the simplified mean-score/mean-uncertainty surrogate.
% Instead, it uses the stored locked fractions:
%   fracLikelyCancer
%   fracLikelyHealthy
%   fracUncertain
%
% It therefore analyzes sensitivity of the TRUE core-decision rule:
%   cancer-like  if fracLikelyCancer  >= cancerCoreThr
%   healthy-like if fracLikelyHealthy >= healthyCoreThr
%   uncertain    otherwise
%
% Pixel-level classification remains exactly as saved in the locked output.
%
% Outputs:
%   00_data\outputs\reports\ARBITER_true_core_decision_sensitivity_v1.csv
%   00_data\outputs\reports\ARBITER_true_core_decision_sensitivity_v1.mat
%   00_data\outputs\reports\ARBITER_true_core_decision_sensitivity_summary_v1.txt
%   00_data\outputs\figures\ARBITER_true_core_decision_sensitivity_v1.png
%   00_data\outputs\figures\ARBITER_true_core_decision_sensitivity_v1.fig

clear; clc; close all;

%% Bootstrap repository paths
thisFile = mfilename('fullpath');
runDir   = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fullfile(matlabDir, 'utils'));
cfg = arbiter_config_paths();

%% Paths
rootDir   = cfg.project_root;
reportDir = fullfile(rootDir, '00_data', 'outputs', 'reports');
figDir    = fullfile(rootDir, '00_data', 'outputs', 'figures');

inCsv   = fullfile(reportDir, 'ARBITER_core_channel_scores_v1.csv');

outCsv  = fullfile(reportDir, 'ARBITER_true_core_decision_sensitivity_v1.csv');
outMat  = fullfile(reportDir, 'ARBITER_true_core_decision_sensitivity_v1.mat');
outTxt  = fullfile(reportDir, 'ARBITER_true_core_decision_sensitivity_summary_v1.txt');

outPng  = fullfile(figDir, 'ARBITER_true_core_decision_sensitivity_v1.png');
outFig  = fullfile(figDir, 'ARBITER_true_core_decision_sensitivity_v1.fig');

if ~exist(figDir, 'dir')
    mkdir(figDir);
end

assert(isfile(inCsv), 'Missing file: %s. Run run_20b_export_core_channel_scores_from_precomp first.', inCsv);

%% Read table robustly
opts = detectImportOptions(inCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
T = readtable(inCsv, opts);

numVars = {'meanPBaseline','meanPPrototype','meanPEqualWeight','meanPLockedAlphaNoGate', ...
           'meanPFuse','meanUncFuse','fracLikelyCancer','fracLikelyHealthy','fracUncertain', ...
           'nPixBase','nPixProto'};
for i = 1:numel(numVars)
    if ismember(numVars{i}, T.Properties.VariableNames)
        T.(numVars{i}) = double(str2double(string(T.(numVars{i}))));
    end
end

txtVars = {'coreId','group','subset','coreDecision','trueLabel','useForValidation'};
for i = 1:numel(txtVars)
    if ismember(txtVars{i}, T.Properties.VariableNames)
        T.(txtVars{i}) = string(T.(txtVars{i}));
    end
end

required = {'coreId','group','subset','fracLikelyCancer','fracLikelyHealthy','fracUncertain'};
for i = 1:numel(required)
    assert(ismember(required{i}, T.Properties.VariableNames), 'Missing required column: %s', required{i});
end

if ~ismember('trueLabel', T.Properties.VariableNames)
    T.trueLabel = repmat("", height(T), 1);
end
if ~ismember('useForValidation', T.Properties.VariableNames)
    T.useForValidation = repmat("", height(T), 1);
end
if ~ismember('coreDecision', T.Properties.VariableNames)
    T.coreDecision = repmat("", height(T), 1);
end

%% Normalize text and keep real rows
T.coreId = strtrim(T.coreId);
T.group = strtrim(T.group);
T.subset = lower(strtrim(T.subset));
T.coreDecision = lower(strtrim(T.coreDecision));
T.trueLabel = lower(strtrim(T.trueLabel));
T.useForValidation = lower(strtrim(T.useForValidation));

keepRows = ~ismissing(T.coreId) & strlength(T.coreId) > 0 & ...
           ~isnan(T.fracLikelyCancer) & ~isnan(T.fracLikelyHealthy) & ~isnan(T.fracUncertain);
T = T(keepRows, :);

%% Masks
isReference = T.subset == "reference";
isNaT = T.subset == "nat";
if ~any(isNaT)
    isNaT = startsWith(lower(strtrim(T.group)), "nat");
end

useVal = T.useForValidation == "1" | T.useForValidation == "true" | T.useForValidation == "yes";
refVal = isReference & useVal & (T.trueLabel == "cancer" | T.trueLabel == "healthy");

%% Locked operating point
lockedCancerCoreThr  = 0.60;
lockedHealthyCoreThr = 0.40;

%% Grids
cancerCoreThrList  = (0.50:0.05:0.70)';
healthyCoreThrList = (0.30:0.05:0.50)';

nC = numel(cancerCoreThrList);
nH = numel(healthyCoreThrList);

%% Preallocate grid outputs
rows = nC * nH;
cancerCoreThr          = nan(rows,1);
healthyCoreThr         = nan(rows,1);

refCoverage            = nan(rows,1);
refSelectiveAccuracy   = nan(rows,1);
refConservativeAccuracy= nan(rows,1);

fracAllCancerLike      = nan(rows,1);
fracAllHealthyLike     = nan(rows,1);
fracAllUncertain       = nan(rows,1);

fracNaTCancerLike      = nan(rows,1);
fracNaTHealthyLike     = nan(rows,1);
fracNaTUncertain       = nan(rows,1);

matchLockedDecisionFrac = nan(rows,1);

row = 0;
for i = 1:nC
    cThr = cancerCoreThrList(i);
    for j = 1:nH
        hThr = healthyCoreThrList(j);
        row = row + 1;

        cancerCoreThr(row)  = cThr;
        healthyCoreThr(row) = hThr;

        dec = strings(height(T),1);
        dec(:) = "uncertain";
        dec(T.fracLikelyCancer  >= cThr) = "cancer-like";
        undec = dec == "uncertain";
        dec(undec & T.fracLikelyHealthy >= hThr) = "healthy-like";

        % All-core fractions
        fracAllCancerLike(row)  = mean(dec == "cancer-like");
        fracAllHealthyLike(row) = mean(dec == "healthy-like");
        fracAllUncertain(row)   = mean(dec == "uncertain");

        % NaT fractions
        if any(isNaT)
            fracNaTCancerLike(row)  = mean(dec(isNaT) == "cancer-like");
            fracNaTHealthyLike(row) = mean(dec(isNaT) == "healthy-like");
            fracNaTUncertain(row)   = mean(dec(isNaT) == "uncertain");
        end

        % Reference validation
        if any(refVal)
            dref = dec(refVal);
            yref = T.trueLabel(refVal);

            called = dref ~= "uncertain";
            refCoverage(row) = mean(called);

            if any(called)
                pred = strings(sum(called),1);
                pred(dref(called) == "cancer-like")  = "cancer";
                pred(dref(called) == "healthy-like") = "healthy";
                refSelectiveAccuracy(row) = mean(pred == yref(called));
            else
                refSelectiveAccuracy(row) = NaN;
            end

            correctCons = zeros(sum(refVal),1);
            correctCons((dref == "cancer-like")  & (yref == "cancer"))  = 1;
            correctCons((dref == "healthy-like") & (yref == "healthy")) = 1;
            refConservativeAccuracy(row) = mean(correctCons);
        end

        if any(strlength(T.coreDecision) > 0)
            matchLockedDecisionFrac(row) = mean(dec == T.coreDecision);
        end
    end
end

Tsens = table(cancerCoreThr, healthyCoreThr, ...
    refCoverage, refSelectiveAccuracy, refConservativeAccuracy, ...
    fracAllCancerLike, fracAllHealthyLike, fracAllUncertain, ...
    fracNaTCancerLike, fracNaTHealthyLike, fracNaTUncertain, ...
    matchLockedDecisionFrac, ...
    'VariableNames', {'cancerCoreThr','healthyCoreThr', ...
                      'refCoverage','refSelectiveAccuracy','refConservativeAccuracy', ...
                      'fracAllCancerLike','fracAllHealthyLike','fracAllUncertain', ...
                      'fracNaTCancerLike','fracNaTHealthyLike','fracNaTUncertain', ...
                      'matchLockedDecisionFrac'});

%% Save table
writetable(Tsens, outCsv);
save(outMat, 'Tsens');

%% Find locked point and best-match point
isLocked = abs(Tsens.cancerCoreThr - lockedCancerCoreThr) < 1e-12 & ...
           abs(Tsens.healthyCoreThr - lockedHealthyCoreThr) < 1e-12;

if any(isLocked)
    lockedRow = Tsens(isLocked, :);
else
    lockedRow = Tsens(1,:);
end

[~, idxBestMatch] = max(Tsens.matchLockedDecisionFrac);
bestMatchRow = Tsens(idxBestMatch,:);

%% Write summary text
fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open summary text for writing: %s', outTxt);

fprintf(fid, 'ARBITER true core-decision sensitivity analysis\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));

fprintf(fid, 'This analysis uses the TRUE stored locked fractions:\n');
fprintf(fid, '  fracLikelyCancer\n');
fprintf(fid, '  fracLikelyHealthy\n');
fprintf(fid, '  fracUncertain\n\n');

fprintf(fid, 'Reference labeled cores used for validation: %d\n', sum(refVal));
fprintf(fid, 'normal-adjacent tissue cores detected: %d\n\n', sum(isNaT));

fprintf(fid, 'Locked point evaluated:\n');
fprintf(fid, '  cancerCoreThr  = %.2f\n', lockedRow.cancerCoreThr);
fprintf(fid, '  healthyCoreThr = %.2f\n', lockedRow.healthyCoreThr);
fprintf(fid, '  refCoverage             = %.4f\n', lockedRow.refCoverage);
fprintf(fid, '  refSelectiveAccuracy    = %.4f\n', lockedRow.refSelectiveAccuracy);
fprintf(fid, '  refConservativeAccuracy = %.4f\n', lockedRow.refConservativeAccuracy);
fprintf(fid, '  fracNaTCancerLike       = %.4f\n', lockedRow.fracNaTCancerLike);
fprintf(fid, '  fracNaTHealthyLike      = %.4f\n', lockedRow.fracNaTHealthyLike);
fprintf(fid, '  fracNaTUncertain        = %.4f\n', lockedRow.fracNaTUncertain);
fprintf(fid, '  matchLockedDecisionFrac = %.4f\n\n', lockedRow.matchLockedDecisionFrac);

fprintf(fid, 'Best grid point by matchLockedDecisionFrac:\n');
fprintf(fid, '  cancerCoreThr  = %.2f\n', bestMatchRow.cancerCoreThr);
fprintf(fid, '  healthyCoreThr = %.2f\n', bestMatchRow.healthyCoreThr);
fprintf(fid, '  refCoverage             = %.4f\n', bestMatchRow.refCoverage);
fprintf(fid, '  refSelectiveAccuracy    = %.4f\n', bestMatchRow.refSelectiveAccuracy);
fprintf(fid, '  refConservativeAccuracy = %.4f\n', bestMatchRow.refConservativeAccuracy);
fprintf(fid, '  fracNaTCancerLike       = %.4f\n', bestMatchRow.fracNaTCancerLike);
fprintf(fid, '  fracNaTHealthyLike      = %.4f\n', bestMatchRow.fracNaTHealthyLike);
fprintf(fid, '  fracNaTUncertain        = %.4f\n', bestMatchRow.fracNaTUncertain);
fprintf(fid, '  matchLockedDecisionFrac = %.4f\n', bestMatchRow.matchLockedDecisionFrac);
fclose(fid);

%% Heatmap matrices
RefCovMat   = nan(nH, nC);
NaTUncMat   = nan(nH, nC);
NaTCancerMat= nan(nH, nC);
MatchMat    = nan(nH, nC);

for i = 1:nC
    for j = 1:nH
        idx = find(abs(Tsens.cancerCoreThr - cancerCoreThrList(i)) < 1e-12 & ...
                   abs(Tsens.healthyCoreThr - healthyCoreThrList(j)) < 1e-12, 1, 'first');
        RefCovMat(j,i)    = Tsens.refCoverage(idx);
        NaTUncMat(j,i)    = Tsens.fracNaTUncertain(idx);
        NaTCancerMat(j,i) = Tsens.fracNaTCancerLike(idx);
        MatchMat(j,i)     = Tsens.matchLockedDecisionFrac(idx);
    end
end

%% Figure
fig = figure('Color', 'w', 'Position', [80 60 1500 900]);
tiledlayout(2,2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Panel A
nexttile;
imagesc(cancerCoreThrList, healthyCoreThrList, RefCovMat);
set(gca, 'YDir', 'normal');
xlabel('cancerCoreThr', 'FontWeight', 'bold');
ylabel('healthyCoreThr', 'FontWeight', 'bold');
title('Reference coverage', 'FontWeight', 'bold');
colorbar;
hold on;
plot(lockedCancerCoreThr, lockedHealthyCoreThr, 'kp', 'MarkerFaceColor', 'w', 'MarkerSize', 12);
hold off;

% Panel B
nexttile;
imagesc(cancerCoreThrList, healthyCoreThrList, NaTUncMat);
set(gca, 'YDir', 'normal');
xlabel('cancerCoreThr', 'FontWeight', 'bold');
ylabel('healthyCoreThr', 'FontWeight', 'bold');
title('NaT uncertain fraction', 'FontWeight', 'bold');
colorbar;
hold on;
plot(lockedCancerCoreThr, lockedHealthyCoreThr, 'kp', 'MarkerFaceColor', 'w', 'MarkerSize', 12);
hold off;

% Panel C
nexttile;
imagesc(cancerCoreThrList, healthyCoreThrList, NaTCancerMat);
set(gca, 'YDir', 'normal');
xlabel('cancerCoreThr', 'FontWeight', 'bold');
ylabel('healthyCoreThr', 'FontWeight', 'bold');
title('normal-adjacent tissue cancer-like fraction', 'FontWeight', 'bold');
colorbar;
hold on;
plot(lockedCancerCoreThr, lockedHealthyCoreThr, 'kp', 'MarkerFaceColor', 'w', 'MarkerSize', 12);
hold off;

% Panel D
nexttile;
imagesc(cancerCoreThrList, healthyCoreThrList, MatchMat);
set(gca, 'YDir', 'normal');
xlabel('cancerCoreThr', 'FontWeight', 'bold');
ylabel('healthyCoreThr', 'FontWeight', 'bold');
title('Match to locked decisions', 'FontWeight', 'bold');
colorbar;
hold on;
plot(lockedCancerCoreThr, lockedHealthyCoreThr, 'kp', 'MarkerFaceColor', 'w', 'MarkerSize', 12);
hold off;

sgtitle('ARBITER true core-decision sensitivity analysis', 'FontWeight', 'bold', 'FontSize', 20);

exportgraphics(fig, outPng, 'Resolution', 300);
savefig(fig, outFig);

%% Console summary
fprintf('\nSaved sensitivity table:\n  %s\n', outCsv);
fprintf('Saved summary text:\n  %s\n', outTxt);
fprintf('Saved figure:\n  %s\n', outPng);

fprintf('\nLocked point:\n');
disp(lockedRow);

fprintf('\nBest match point:\n');
disp(bestMatchRow);
