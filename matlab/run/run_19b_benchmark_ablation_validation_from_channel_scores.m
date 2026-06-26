%% run_19b_benchmark_ablation_validation_from_channel_scores
% Benchmark + ablation + validation using the clean 21-core channel score table
% exported by:
%   run_20b_export_core_channel_scores_from_precomp
%
% No helper/local functions required.

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

inCsv     = fullfile(reportDir, 'ARBITER_core_channel_scores_v1.csv');

outCoreCsv = fullfile(reportDir, 'ARBITER_benchmark_core_table_v1.csv');
outCoreMat = fullfile(reportDir, 'ARBITER_benchmark_core_table_v1.mat');

outSumCsv  = fullfile(reportDir, 'ARBITER_benchmark_summary_v1.csv');
outSumMat  = fullfile(reportDir, 'ARBITER_benchmark_summary_v1.mat');

outAblCsv  = fullfile(reportDir, 'ARBITER_ablation_summary_v1.csv');
outAblMat  = fullfile(reportDir, 'ARBITER_ablation_summary_v1.mat');

outTxt     = fullfile(reportDir, 'ARBITER_validation_summary_v1.txt');

outPng     = fullfile(figDir, 'ARBITER_benchmark_validation_v1.png');
outFig     = fullfile(figDir, 'ARBITER_benchmark_validation_v1.fig');

if ~exist(figDir, 'dir')
    mkdir(figDir);
end

assert(isfile(inCsv), 'Missing file: %s. Run run_20b_export_core_channel_scores_from_precomp first.', inCsv);

%% Read clean channel score table as strings first, then convert numeric columns
opts = detectImportOptions(inCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
T = readtable(inCsv, opts);

% Normalize variable names if needed
vn = string(T.Properties.VariableNames);

% Convert selected numeric columns if present
numVars = {'meanPBaseline','meanPPrototype','meanPEqualWeight','meanPLockedAlphaNoGate', ...
           'meanPFuse','meanUncFuse','fracLikelyCancer','fracLikelyHealthy','fracUncertain', ...
           'nPixBase','nPixProto'};

for i = 1:numel(numVars)
    if ismember(numVars{i}, T.Properties.VariableNames)
        T.(numVars{i}) = double(str2double(string(T.(numVars{i}))));
    end
end

% Ensure key text columns are strings
txtVars = {'coreId','group','subset','coreDecision','trueLabel','useForValidation'};
for i = 1:numel(txtVars)
    if ismember(txtVars{i}, T.Properties.VariableNames)
        T.(txtVars{i}) = string(T.(txtVars{i}));
    end
end

required = {'coreId','group','subset','meanPBaseline','meanPPrototype','meanPEqualWeight', ...
            'meanPLockedAlphaNoGate','meanPFuse','meanUncFuse','coreDecision'};
for i = 1:numel(required)
    assert(ismember(required{i}, T.Properties.VariableNames), 'Missing required column: %s', required{i});
end

if ~ismember('trueLabel', T.Properties.VariableNames)
    T.trueLabel = repmat("", height(T), 1);
end
if ~ismember('useForValidation', T.Properties.VariableNames)
    T.useForValidation = repmat("", height(T), 1);
end

%% Standardize text
T.coreId = strtrim(T.coreId);
T.group = strtrim(T.group);
T.subset = strtrim(T.subset);
T.coreDecision = lower(strtrim(T.coreDecision));
T.coreDecision = replace(T.coreDecision, "_", "-");
T.trueLabel = lower(strtrim(T.trueLabel));
T.useForValidation = lower(strtrim(T.useForValidation));

% Keep only real biological cores with fused score coverage
keepRows = ~ismissing(T.coreId) & strlength(T.coreId) > 0 & ~isnan(T.meanPFuse);
T = T(keepRows, :);

%% Thresholds
cancerThr  = 0.60;
healthyThr = 0.40;
uncThr     = 0.45;

%% Variant availability
avail_baseline  = all(~isnan(T.meanPBaseline));
avail_prototype = all(~isnan(T.meanPPrototype));
avail_equal     = all(~isnan(T.meanPEqualWeight));
avail_nogate    = all(~isnan(T.meanPLockedAlphaNoGate));
avail_arbiter   = all(~isnan(T.meanPFuse));

fprintf('\nAvailable variants:\n');
fprintf('  baseline_only             : %d\n', avail_baseline);
fprintf('  prototype_only            : %d\n', avail_prototype);
fprintf('  equal_weight_fusion       : %d\n', avail_equal);
fprintf('  locked_fusion_no_unc_gate : %d\n', avail_nogate);
fprintf('  locked_arbiter_2ch        : %d\n', avail_arbiter);

%% Build per-core decision table
Tcore = T(:, {'coreId','group','subset','trueLabel','useForValidation', ...
              'meanPBaseline','meanPPrototype','meanPEqualWeight','meanPLockedAlphaNoGate', ...
              'meanPFuse','meanUncFuse','fracLikelyCancer','fracLikelyHealthy','fracUncertain'});

% baseline_only
dec = strings(height(T),1);
score = T.meanPBaseline;
dec(score >= cancerThr) = "cancer-like";
dec(score <= healthyThr) = "healthy-like";
mid = dec == "";
dec(mid) = "uncertain";
Tcore.decision_baseline_only = dec;

% prototype_only
dec = strings(height(T),1);
score = T.meanPPrototype;
dec(score >= cancerThr) = "cancer-like";
dec(score <= healthyThr) = "healthy-like";
mid = dec == "";
dec(mid) = "uncertain";
Tcore.decision_prototype_only = dec;

% equal_weight_fusion
dec = strings(height(T),1);
score = T.meanPEqualWeight;
dec(score >= cancerThr) = "cancer-like";
dec(score <= healthyThr) = "healthy-like";
mid = dec == "";
dec(mid) = "uncertain";
Tcore.decision_equal_weight_fusion = dec;

% locked_fusion_no_unc_gate
dec = strings(height(T),1);
score = T.meanPLockedAlphaNoGate;
dec(score >= cancerThr) = "cancer-like";
dec(score <= healthyThr) = "healthy-like";
mid = dec == "";
dec(mid) = "uncertain";
Tcore.decision_locked_fusion_no_unc_gate = dec;

% locked_arbiter_2ch
Tcore.decision_locked_arbiter_2ch = T.coreDecision;
Tcore.decision_locked_arbiter_2ch(Tcore.decision_locked_arbiter_2ch == "") = "missing";

%% Reference/NaT masks
isReference = lower(strtrim(T.subset)) == "reference";
isNaT       = lower(strtrim(T.subset)) == "nat";
if ~any(isNaT)
    isNaT = startsWith(lower(strtrim(T.group)), "nat");
end

useVal = lower(strtrim(T.useForValidation));
useVal = useVal == "1" | useVal == "true" | useVal == "yes";
refVal = isReference & useVal & (T.trueLabel == "cancer" | T.trueLabel == "healthy");

fprintf('Reference labeled cores used for validation: %d\n', sum(refVal));
fprintf('normal-adjacent tissue cores detected: %d\n', sum(isNaT));

%% Summary table across variants
variantNames = ["baseline_only","prototype_only","equal_weight_fusion","locked_fusion_no_unc_gate","locked_arbiter_2ch"]';
decisionCols = ["decision_baseline_only","decision_prototype_only","decision_equal_weight_fusion", ...
                "decision_locked_fusion_no_unc_gate","decision_locked_arbiter_2ch"]';

nVar = numel(variantNames);
coverage_ref = nan(nVar,1);
selective_acc_ref = nan(nVar,1);
conservative_acc_ref = nan(nVar,1);

frac_all_cancer = nan(nVar,1);
frac_all_healthy = nan(nVar,1);
frac_all_uncertain = nan(nVar,1);

frac_nat_cancer = nan(nVar,1);
frac_nat_healthy = nan(nVar,1);
frac_nat_uncertain = nan(nVar,1);

for i = 1:nVar
    dec = string(Tcore.(decisionCols(i)));

    % All-core fractions
    frac_all_cancer(i)    = mean(dec == "cancer-like");
    frac_all_healthy(i)   = mean(dec == "healthy-like");
    frac_all_uncertain(i) = mean(dec == "uncertain");

    % NaT fractions
    if any(isNaT)
        frac_nat_cancer(i)    = mean(dec(isNaT) == "cancer-like");
        frac_nat_healthy(i)   = mean(dec(isNaT) == "healthy-like");
        frac_nat_uncertain(i) = mean(dec(isNaT) == "uncertain");
    end

    % Reference validation
    if any(refVal)
        dref = dec(refVal);
        yref = T.trueLabel(refVal);

        called = dref ~= "uncertain" & dref ~= "missing" & dref ~= "";
        coverage_ref(i) = mean(called);

        if any(called)
            pred = strings(sum(called),1);
            pred(dref(called) == "cancer-like") = "cancer";
            pred(dref(called) == "healthy-like") = "healthy";
            selective_acc_ref(i) = mean(pred == yref(called));
        else
            selective_acc_ref(i) = NaN;
        end

        correct_cons = zeros(sum(refVal),1);
        correct_cons((dref == "cancer-like") & (yref == "cancer")) = 1;
        correct_cons((dref == "healthy-like") & (yref == "healthy")) = 1;
        conservative_acc_ref(i) = mean(correct_cons);
    end
end

Tsummary = table(variantNames, coverage_ref, selective_acc_ref, conservative_acc_ref, ...
    frac_all_cancer, frac_all_healthy, frac_all_uncertain, ...
    frac_nat_cancer, frac_nat_healthy, frac_nat_uncertain, ...
    'VariableNames', {'variant','refCoverage','refSelectiveAccuracy','refConservativeAccuracy', ...
                      'fracAllCancerLike','fracAllHealthyLike','fracAllUncertain', ...
                      'fracNaTCancerLike','fracNaTHealthyLike','fracNaTUncertain'});

%% Ablation table
ablationName = ["locked_fusion_no_unc_gate"; "locked_arbiter_2ch"];
ab_refCoverage = nan(2,1);
ab_refSelectiveAccuracy = nan(2,1);
ab_refConservativeAccuracy = nan(2,1);
ab_fracNaTUncertain = nan(2,1);

for j = 1:2
    idx = find(variantNames == ablationName(j), 1, 'first');
    ab_refCoverage(j) = coverage_ref(idx);
    ab_refSelectiveAccuracy(j) = selective_acc_ref(idx);
    ab_refConservativeAccuracy(j) = conservative_acc_ref(idx);
    ab_fracNaTUncertain(j) = frac_nat_uncertain(idx);
end

Tabl = table(ablationName, ab_refCoverage, ab_refSelectiveAccuracy, ...
    ab_refConservativeAccuracy, ab_fracNaTUncertain, ...
    'VariableNames', {'variant','refCoverage','refSelectiveAccuracy', ...
                      'refConservativeAccuracy','fracNaTUncertain'});

%% Save tables
writetable(Tcore, outCoreCsv);
save(outCoreMat, 'Tcore');

writetable(Tsummary, outSumCsv);
save(outSumMat, 'Tsummary');

writetable(Tabl, outAblCsv);
save(outAblMat, 'Tabl');

%% Write validation summary text
fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open validation summary for writing.');

fprintf(fid, 'ARBITER benchmark + ablation + validation summary\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));

fprintf(fid, 'Reference labeled cores used for validation: %d\n', sum(refVal));
fprintf(fid, 'normal-adjacent tissue cores detected: %d\n\n', sum(isNaT));

fprintf(fid, 'Available variants:\n');
fprintf(fid, '  baseline_only             : %d\n', avail_baseline);
fprintf(fid, '  prototype_only            : %d\n', avail_prototype);
fprintf(fid, '  equal_weight_fusion       : %d\n', avail_equal);
fprintf(fid, '  locked_fusion_no_unc_gate : %d\n', avail_nogate);
fprintf(fid, '  locked_arbiter_2ch        : %d\n\n', avail_arbiter);

fprintf(fid, 'Benchmark summary:\n');
for i = 1:height(Tsummary)
    fprintf(fid, '  %s\n', Tsummary.variant(i));
    fprintf(fid, '    refCoverage             = %.4f\n', Tsummary.refCoverage(i));
    fprintf(fid, '    refSelectiveAccuracy    = %.4f\n', Tsummary.refSelectiveAccuracy(i));
    fprintf(fid, '    refConservativeAccuracy = %.4f\n', Tsummary.refConservativeAccuracy(i));
    fprintf(fid, '    fracAllCancerLike       = %.4f\n', Tsummary.fracAllCancerLike(i));
    fprintf(fid, '    fracAllHealthyLike      = %.4f\n', Tsummary.fracAllHealthyLike(i));
    fprintf(fid, '    fracAllUncertain        = %.4f\n', Tsummary.fracAllUncertain(i));
    fprintf(fid, '    fracNaTCancerLike       = %.4f\n', Tsummary.fracNaTCancerLike(i));
    fprintf(fid, '    fracNaTHealthyLike      = %.4f\n', Tsummary.fracNaTHealthyLike(i));
    fprintf(fid, '    fracNaTUncertain        = %.4f\n\n', Tsummary.fracNaTUncertain(i));
end
fclose(fid);

%% Figure
fig = figure('Color', 'w', 'Position', [80 60 1500 900]);
tiledlayout(2,2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Panel A: all-core decision fractions
nexttile;
XA = [Tsummary.fracAllCancerLike, Tsummary.fracAllHealthyLike, Tsummary.fracAllUncertain];
ax = gca;
colororder(ax, [0.85 0.20 0.20; 0.20 0.65 0.25; 0.55 0.55 0.55]);
bar(XA, 'stacked', 'BarWidth', 0.82);
ylim([0 1]);
ylabel('Fraction of cores', 'FontWeight', 'bold');
title('All-core decision fractions', 'FontWeight', 'bold');
xticks(1:nVar);
xticklabels(strrep(cellstr(variantNames), '_', '\_'));
xtickangle(25);
legend({'cancer-like','healthy-like','uncertain'}, 'Location', 'northwest');
grid on; box on;

% Panel B: reference-set validation
nexttile;
XB = [Tsummary.refCoverage, Tsummary.refSelectiveAccuracy, Tsummary.refConservativeAccuracy];
ax = gca;
colororder(ax, [0.20 0.45 0.75; 0.25 0.65 0.30; 0.55 0.55 0.55]);
bar(XB, 'grouped', 'BarWidth', 0.82);
ylim([0 1]);
ylabel('Metric value', 'FontWeight', 'bold');
title('Reference-set validation', 'FontWeight', 'bold');
xticks(1:nVar);
xticklabels(strrep(cellstr(variantNames), '_', '\_'));
xtickangle(25);
legend({'coverage','selective accuracy','conservative accuracy'}, 'Location', 'southeast');
grid on; box on;

% Panel C: NaT decision fractions
nexttile;
XC = [Tsummary.fracNaTCancerLike, Tsummary.fracNaTHealthyLike, Tsummary.fracNaTUncertain];
ax = gca;
colororder(ax, [0.85 0.20 0.20; 0.20 0.65 0.25; 0.55 0.55 0.55]);
bar(XC, 'stacked', 'BarWidth', 0.82);
ylim([0 1]);
ylabel('Fraction of normal-adjacent tissue cores', 'FontWeight', 'bold');
title('NaT decision fractions', 'FontWeight', 'bold');
xticks(1:nVar);
xticklabels(strrep(cellstr(variantNames), '_', '\_'));
xtickangle(25);
legend({'cancer-like','healthy-like','uncertain'}, 'Location', 'northwest');
grid on; box on;

% Panel D: ablation
nexttile;
XD = [Tabl.refCoverage, Tabl.refSelectiveAccuracy, Tabl.refConservativeAccuracy, Tabl.fracNaTUncertain];
ax = gca;
colororder(ax, [0.20 0.45 0.75; 0.25 0.65 0.30; 0.55 0.55 0.55; 0.85 0.60 0.10]);
bar(XD, 'grouped', 'BarWidth', 0.82);
ylim([0 1]);
ylabel('Metric value', 'FontWeight', 'bold');
title('Ablation: uncertainty gate effect', 'FontWeight', 'bold');
xticks(1:height(Tabl));
xticklabels(strrep(cellstr(Tabl.variant), '_', '\_'));
xtickangle(25);
legend({'reference coverage','selective accuracy','conservative accuracy','NaT uncertain fraction'}, ...
    'Location', 'southeast');
grid on; box on;

sgtitle('ARBITER benchmark + ablation + validation', 'FontWeight', 'bold', 'FontSize', 20);

exportgraphics(fig, outPng, 'Resolution', 300);
savefig(fig, outFig);

%% Console summary
fprintf('\nSaved benchmark core table:\n  %s\n', outCoreCsv);
fprintf('Saved benchmark summary:\n  %s\n', outSumCsv);
fprintf('Saved ablation summary:\n  %s\n', outAblCsv);
fprintf('Saved validation summary:\n  %s\n', outTxt);
fprintf('Saved figure:\n  %s\n', outPng);

disp(Tsummary);
disp(Tabl);
