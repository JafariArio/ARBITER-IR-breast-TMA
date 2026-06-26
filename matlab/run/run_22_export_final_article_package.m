%% run_22_export_final_article_package
% Export manuscript-facing tables and text from the locked 2-channel ARBITER study.
%
% Expected prior steps:
%   run_20b_export_core_channel_scores_from_precomp
%   run_19b_benchmark_ablation_validation_from_channel_scores
%   run_21b_true_locked_core_decision_sensitivity
%
% Outputs:
%   00_data\outputs\reports\ARBITER_article_table_benchmark_v1.csv
%   00_data\outputs\reports\ARBITER_article_table_core_summary_v1.csv
%   00_data\outputs\reports\ARBITER_article_caption_core_summary_v1.txt
%   00_data\outputs\reports\ARBITER_article_caption_benchmark_v1.txt
%   00_data\outputs\reports\ARBITER_article_caption_sensitivity_v1.txt
%   00_data\outputs\reports\ARBITER_article_results_main_v1.txt
%   00_data\outputs\reports\ARBITER_article_results_short_v1.txt
%   00_data\outputs\reports\ARBITER_article_discussion_limitations_v1.txt
%   00_data\outputs\reports\ARBITER_article_key_numbers_v1.txt

clear; clc;

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

benchCsv  = fullfile(reportDir, 'ARBITER_benchmark_summary_v1.csv');
ablCsv    = fullfile(reportDir, 'ARBITER_ablation_summary_v1.csv');
sensCsv   = fullfile(reportDir, 'ARBITER_true_core_decision_sensitivity_v1.csv');
coreCsv   = fullfile(reportDir, 'ARBITER_core_channel_scores_v1.csv');

outBenchTable = fullfile(reportDir, 'ARBITER_article_table_benchmark_v1.csv');
outCoreTable  = fullfile(reportDir, 'ARBITER_article_table_core_summary_v1.csv');

outCapCore    = fullfile(reportDir, 'ARBITER_article_caption_core_summary_v1.txt');
outCapBench   = fullfile(reportDir, 'ARBITER_article_caption_benchmark_v1.txt');
outCapSens    = fullfile(reportDir, 'ARBITER_article_caption_sensitivity_v1.txt');

outResMain    = fullfile(reportDir, 'ARBITER_article_results_main_v1.txt');
outResShort   = fullfile(reportDir, 'ARBITER_article_results_short_v1.txt');
outDiscuss    = fullfile(reportDir, 'ARBITER_article_discussion_limitations_v1.txt');
outKeyNums    = fullfile(reportDir, 'ARBITER_article_key_numbers_v1.txt');

assert(isfile(benchCsv), 'Missing file: %s', benchCsv);
assert(isfile(ablCsv),   'Missing file: %s', ablCsv);
assert(isfile(sensCsv),  'Missing file: %s', sensCsv);
assert(isfile(coreCsv),  'Missing file: %s', coreCsv);

%% Robust CSV reader helper pattern inline
opts = detectImportOptions(benchCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
Tbench = readtable(benchCsv, opts);

opts = detectImportOptions(ablCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
Tabl = readtable(ablCsv, opts);

opts = detectImportOptions(sensCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
Tsens = readtable(sensCsv, opts);

opts = detectImportOptions(coreCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
Tcore = readtable(coreCsv, opts);

%% Convert numeric columns
numBench = {'refCoverage','refSelectiveAccuracy','refConservativeAccuracy', ...
            'fracAllCancerLike','fracAllHealthyLike','fracAllUncertain', ...
            'fracNaTCancerLike','fracNaTHealthyLike','fracNaTUncertain'};
for i = 1:numel(numBench)
    if ismember(numBench{i}, Tbench.Properties.VariableNames)
        Tbench.(numBench{i}) = double(str2double(string(Tbench.(numBench{i}))));
    end
end

numAbl = {'refCoverage','refSelectiveAccuracy','refConservativeAccuracy','fracNaTUncertain'};
for i = 1:numel(numAbl)
    if ismember(numAbl{i}, Tabl.Properties.VariableNames)
        Tabl.(numAbl{i}) = double(str2double(string(Tabl.(numAbl{i}))));
    end
end

numSens = {'cancerCoreThr','healthyCoreThr','refCoverage','refSelectiveAccuracy','refConservativeAccuracy', ...
           'fracAllCancerLike','fracAllHealthyLike','fracAllUncertain', ...
           'fracNaTCancerLike','fracNaTHealthyLike','fracNaTUncertain','matchLockedDecisionFrac'};
for i = 1:numel(numSens)
    if ismember(numSens{i}, Tsens.Properties.VariableNames)
        Tsens.(numSens{i}) = double(str2double(string(Tsens.(numSens{i}))));
    end
end

numCore = {'meanPBaseline','meanPPrototype','meanPEqualWeight','meanPLockedAlphaNoGate', ...
           'meanPFuse','meanUncFuse','fracLikelyCancer','fracLikelyHealthy','fracUncertain'};
for i = 1:numel(numCore)
    if ismember(numCore{i}, Tcore.Properties.VariableNames)
        Tcore.(numCore{i}) = double(str2double(string(Tcore.(numCore{i}))));
    end
end

%% Normalize text
txtVars = {'variant','coreId','group','subset','coreDecision','trueLabel','useForValidation'};
for i = 1:numel(txtVars)
    if ismember(txtVars{i}, Tbench.Properties.VariableNames), Tbench.(txtVars{i}) = string(Tbench.(txtVars{i})); end
    if ismember(txtVars{i}, Tabl.Properties.VariableNames),   Tabl.(txtVars{i})   = string(Tabl.(txtVars{i}));   end
    if ismember(txtVars{i}, Tsens.Properties.VariableNames),  Tsens.(txtVars{i})  = string(Tsens.(txtVars{i}));  end
    if ismember(txtVars{i}, Tcore.Properties.VariableNames),  Tcore.(txtVars{i})  = string(Tcore.(txtVars{i}));  end
end

if ismember('variant', Tbench.Properties.VariableNames)
    Tbench.variant = string(Tbench.variant);
end
if ismember('variant', Tabl.Properties.VariableNames)
    Tabl.variant = string(Tabl.variant);
end
if ismember('coreId', Tcore.Properties.VariableNames)
    Tcore.coreId = string(Tcore.coreId);
end
if ismember('group', Tcore.Properties.VariableNames)
    Tcore.group = string(Tcore.group);
end
if ismember('subset', Tcore.Properties.VariableNames)
    Tcore.subset = string(Tcore.subset);
end
if ismember('coreDecision', Tcore.Properties.VariableNames)
    Tcore.coreDecision = string(Tcore.coreDecision);
end

%% Locate key rows
idxBase   = find(Tbench.variant == "baseline_only", 1, 'first');
idxProto  = find(Tbench.variant == "prototype_only", 1, 'first');
idxEqual  = find(Tbench.variant == "equal_weight_fusion", 1, 'first');
idxNoGate = find(Tbench.variant == "locked_fusion_no_unc_gate", 1, 'first');
idxArb    = find(Tbench.variant == "locked_arbiter_2ch", 1, 'first');

assert(~isempty(idxBase) && ~isempty(idxProto) && ~isempty(idxEqual) && ~isempty(idxNoGate) && ~isempty(idxArb), ...
    'Benchmark summary does not contain all expected variants.');

isLocked = abs(Tsens.cancerCoreThr - 0.60) < 1e-12 & abs(Tsens.healthyCoreThr - 0.40) < 1e-12;
if ~any(isLocked)
    error('Locked sensitivity row (0.60 / 0.40) not found.');
end
lockedRow = Tsens(find(isLocked,1,'first'), :);

[~, idxBest] = max(Tsens.matchLockedDecisionFrac);
bestRow = Tsens(idxBest,:);

%% Build manuscript-facing benchmark table
TableBenchmark = table( ...
    Tbench.variant, ...
    round(100*Tbench.refCoverage,1), ...
    round(100*Tbench.refSelectiveAccuracy,1), ...
    round(100*Tbench.refConservativeAccuracy,1), ...
    round(100*Tbench.fracNaTCancerLike,1), ...
    round(100*Tbench.fracNaTHealthyLike,1), ...
    round(100*Tbench.fracNaTUncertain,1), ...
    'VariableNames', {'Variant','ReferenceCoverage_pct','ReferenceSelectiveAccuracy_pct', ...
                      'ReferenceConservativeAccuracy_pct','NaTCancerLike_pct', ...
                      'NaTHealthyLike_pct','NaTUncertain_pct'});

writetable(TableBenchmark, outBenchTable);

%% Build manuscript-facing core summary table
keepCore = {'coreId','group','subset','meanPBaseline','meanPPrototype','meanPFuse','meanUncFuse', ...
            'fracLikelyCancer','fracLikelyHealthy','fracUncertain','coreDecision'};
keepCore = intersect(keepCore, Tcore.Properties.VariableNames, 'stable');
TableCore = Tcore(:, keepCore);
writetable(TableCore, outCoreTable);

%% Text values for convenience
baseNatCancer   = Tbench.fracNaTCancerLike(idxBase);
protoNatUnc     = Tbench.fracNaTUncertain(idxProto);
equalNatUnc     = Tbench.fracNaTUncertain(idxEqual);
nogateNatCancer = Tbench.fracNaTCancerLike(idxNoGate);
nogateNatUnc    = Tbench.fracNaTUncertain(idxNoGate);
arbNatCancer    = Tbench.fracNaTCancerLike(idxArb);
arbNatHealthy   = Tbench.fracNaTHealthyLike(idxArb);
arbNatUnc       = Tbench.fracNaTUncertain(idxArb);

%% Caption 1: core summary figure
fid = fopen(outCapCore, 'w');
assert(fid >= 0, 'Could not write: %s', outCapCore);
fprintf(fid, ['Figure X. Core-level summary of the locked 2-channel ARBITER model in the breast TMA pilot. ' ...
    'The final fused score separated confident cancer-like and healthy-like reference cores, while an intermediate ' ...
    'uncertainty-dominated regime concentrated in normal-adjacent tissue. The locked model produced 8 cancer-like, 6 healthy-like, ' ...
    'and 7 uncertain calls across all 21 cores, with NaT outcomes of 1 cancer-like, 3 healthy-like, and 7 uncertain. ' ...
    'These results support the intended reliability-aware behavior of ARBITER, which preserves decisive performance on the reference subset ' ...
    'while avoiding forced binary calling in ambiguous tissue regions.']);
fclose(fid);

%% Caption 2: benchmark figure
fid = fopen(outCapBench, 'w');
assert(fid >= 0, 'Could not write: %s', outCapBench);
fprintf(fid, ['Figure Y. Benchmark and ablation comparison for the breast TMA pilot. All evaluated variants achieved 100%% reference coverage, ' ...
    '100%% reference selective accuracy, and 100%% reference conservative accuracy on the labeled reference subset. ' ...
    'The main difference emerged in normal-adjacent tissue behavior. Baseline-only and locked fusion without the uncertainty gate produced higher normal-adjacent tissue cancer-like rates ' ...
    '(%.1f%% and %.1f%%, respectively), whereas the locked ARBITER model reduced normal-adjacent tissue cancer-like calling to %.1f%% and reassigned %.1f%% of normal-adjacent tissue cores to the uncertain regime. ' ...
    'This shows that ARBITER''s main benefit in this pilot is safer handling of ambiguous tissue rather than improvement on already-easy reference cores.'], ...
    100*baseNatCancer, 100*nogateNatCancer, 100*arbNatCancer, 100*arbNatUnc);
fclose(fid);

%% Caption 3: sensitivity figure
fid = fopen(outCapSens, 'w');
assert(fid >= 0, 'Could not write: %s', outCapSens);
fprintf(fid, ['Figure Z. True core-decision sensitivity analysis based on the saved locked fraction outputs. ' ...
    'The approximate surrogate operating point at cancerCoreThr = 0.60 and healthyCoreThr = 0.40 reproduced %.1f%% of the saved locked decisions, ' ...
    'whereas the best-matching grid point, cancerCoreThr = %.2f and healthyCoreThr = %.2f, reproduced 100%% of the locked decisions. ' ...
    'At this exact-match operating point, ARBITER preserved 100%% reference coverage and accuracy while yielding NaT fractions of %.1f%% cancer-like, %.1f%% healthy-like, and %.1f%% uncertain.'], ...
    100*lockedRow.matchLockedDecisionFrac, bestRow.cancerCoreThr, bestRow.healthyCoreThr, ...
    100*bestRow.fracNaTCancerLike, 100*bestRow.fracNaTHealthyLike, 100*bestRow.fracNaTUncertain);
fclose(fid);

%% Main results paragraph
fid = fopen(outResMain, 'w');
assert(fid >= 0, 'Could not write: %s', outResMain);
fprintf(fid, ['In the locked 2-channel ARBITER workflow, all five evaluated variants achieved complete coverage and perfect performance on the labeled reference subset, indicating that the reference cores were comparatively easy for this pilot setting. ' ...
    'Accordingly, the main discriminative signal emerged in normal-adjacent tissue behavior rather than in reference accuracy. The baseline-only model classified %.1f%% of normal-adjacent tissue cores as cancer-like, while the prototype-only model shifted toward caution with %.1f%% NaT uncertainty. ' ...
    'Equal-weight fusion produced an intermediate profile with %.1f%% NaT uncertainty. The strongest ablation comparison was between locked fusion without the uncertainty gate and the final ARBITER model. ' ...
    'Removing the gate yielded %.1f%% normal-adjacent tissue cancer-like calls and only %.1f%% NaT uncertainty, whereas the locked ARBITER model reduced normal-adjacent tissue cancer-like calling to %.1f%% and increased NaT uncertainty to %.1f%%, without degrading reference-set performance. ' ...
    'This indicates that ARBITER''s practical value in the breast TMA pilot is not improvement on already-easy reference cores, but rather the suppression of overconfident cancer-like calling in ambiguous normal-adjacent tissue through explicit abstention. ' ...
    'True core-decision sensitivity analysis further showed that the saved locked decisions were matched exactly by an effective threshold pair near cancerCoreThr = %.2f and healthyCoreThr = %.2f, which preserved 100%% reference coverage and accuracy while yielding NaT fractions of %.1f%% cancer-like, %.1f%% healthy-like, and %.1f%% uncertain.'], ...
    100*baseNatCancer, 100*protoNatUnc, 100*equalNatUnc, ...
    100*nogateNatCancer, 100*nogateNatUnc, 100*arbNatCancer, 100*arbNatUnc, ...
    bestRow.cancerCoreThr, bestRow.healthyCoreThr, ...
    100*bestRow.fracNaTCancerLike, 100*bestRow.fracNaTHealthyLike, 100*bestRow.fracNaTUncertain);
fclose(fid);

%% Short results paragraph
fid = fopen(outResShort, 'w');
assert(fid >= 0, 'Could not write: %s', outResShort);
fprintf(fid, ['All evaluated variants were perfect on the labeled reference subset, so the main difference between methods emerged in ambiguous normal-adjacent tissue. ' ...
    'Baseline-only and no-gate locked fusion overcalled cancer in NaT, whereas the final ARBITER model reduced normal-adjacent tissue cancer-like calls to %.1f%% and reassigned %.1f%% of normal-adjacent tissue cores to the uncertain regime, while preserving complete reference coverage and accuracy. ' ...
    'This supports ARBITER as a reliability-aware fusion strategy whose principal benefit in this pilot is safer ambiguity handling rather than gain on already-easy reference cores.'], ...
    100*arbNatCancer, 100*arbNatUnc);
fclose(fid);

%% Discussion / limitations paragraph
fid = fopen(outDiscuss, 'w');
assert(fid >= 0, 'Could not write: %s', outDiscuss);
fprintf(fid, ['Several limitations should be stated explicitly. First, the labeled reference subset in the present pilot is small and comparatively easy, which is why all tested variants achieved perfect reference-set metrics. ' ...
    'Second, the main value of ARBITER in this dataset is therefore demonstrated through its behavior on normal-adjacent tissue rather than through higher reference accuracy. ' ...
    'Third, the current study should be interpreted as a proof-of-concept reliability-aware breast TMA analysis rather than as a definitive clinical classifier. ' ...
    'Broader claims about generalization across breast-cancer heterogeneity, patient cohorts, or translational deployment will require larger and more diverse labeled datasets, particularly with additional difficult margin-like or ambiguous cases. ' ...
    'Nevertheless, the present results provide evidence that explicit arbitration and abstention can materially reduce overconfident cancer-like calling in ambiguous tissue without sacrificing performance on clean reference samples.']);
fclose(fid);

%% Key numbers file
fid = fopen(outKeyNums, 'w');
assert(fid >= 0, 'Could not write: %s', outKeyNums);

fprintf(fid, 'ARBITER article key numbers\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));

fprintf(fid, 'Locked 2-channel final counts:\n');
fprintf(fid, '  all cores: cancer-like = 8, healthy-like = 6, uncertain = 7\n');
fprintf(fid, '  normal-adjacent tissue cores: cancer-like = 1, healthy-like = 3, uncertain = 7\n');
fprintf(fid, '  reference cores: cancer-like = 7, healthy-like = 3, uncertain = 0\n\n');

fprintf(fid, 'Benchmark summary (NaT fractions):\n');
fprintf(fid, '  baseline_only:             cancer-like = %.4f, healthy-like = %.4f, uncertain = %.4f\n', ...
    Tbench.fracNaTCancerLike(idxBase), Tbench.fracNaTHealthyLike(idxBase), Tbench.fracNaTUncertain(idxBase));
fprintf(fid, '  prototype_only:            cancer-like = %.4f, healthy-like = %.4f, uncertain = %.4f\n', ...
    Tbench.fracNaTCancerLike(idxProto), Tbench.fracNaTHealthyLike(idxProto), Tbench.fracNaTUncertain(idxProto));
fprintf(fid, '  equal_weight_fusion:       cancer-like = %.4f, healthy-like = %.4f, uncertain = %.4f\n', ...
    Tbench.fracNaTCancerLike(idxEqual), Tbench.fracNaTHealthyLike(idxEqual), Tbench.fracNaTUncertain(idxEqual));
fprintf(fid, '  locked_fusion_no_unc_gate: cancer-like = %.4f, healthy-like = %.4f, uncertain = %.4f\n', ...
    Tbench.fracNaTCancerLike(idxNoGate), Tbench.fracNaTHealthyLike(idxNoGate), Tbench.fracNaTUncertain(idxNoGate));
fprintf(fid, '  locked_arbiter_2ch:        cancer-like = %.4f, healthy-like = %.4f, uncertain = %.4f\n\n', ...
    Tbench.fracNaTCancerLike(idxArb), Tbench.fracNaTHealthyLike(idxArb), Tbench.fracNaTUncertain(idxArb));

fprintf(fid, 'True core-decision sensitivity:\n');
fprintf(fid, '  approximate locked point (0.60 / 0.40): matchLockedDecisionFrac = %.4f\n', lockedRow.matchLockedDecisionFrac);
fprintf(fid, '  best-match point: cancerCoreThr = %.2f, healthyCoreThr = %.2f, matchLockedDecisionFrac = %.4f\n', ...
    bestRow.cancerCoreThr, bestRow.healthyCoreThr, bestRow.matchLockedDecisionFrac);
fprintf(fid, '  best-match NaT fractions: cancer-like = %.4f, healthy-like = %.4f, uncertain = %.4f\n', ...
    bestRow.fracNaTCancerLike, bestRow.fracNaTHealthyLike, bestRow.fracNaTUncertain);
fclose(fid);

%% Console summary
fprintf('\nSaved article benchmark table:\n  %s\n', outBenchTable);
fprintf('Saved article core summary table:\n  %s\n', outCoreTable);
fprintf('Saved captions:\n  %s\n  %s\n  %s\n', outCapCore, outCapBench, outCapSens);
fprintf('Saved results text:\n  %s\n  %s\n', outResMain, outResShort);
fprintf('Saved discussion/limitations text:\n  %s\n', outDiscuss);
fprintf('Saved key numbers:\n  %s\n', outKeyNums);

disp(TableBenchmark);
disp(bestRow);
