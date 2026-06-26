%% run_29_paired_nat_overcall_analysis
% Paired NaT overcall analysis for the locked 21-core pilot.
%
% Confirmatory paired comparisons:
%   - locked ARBITER 2ch vs baseline-only
%   - locked ARBITER 2ch vs locked fusion without uncertainty gate
%
% Inputs:
%   00_data\outputs\reports\ARBITER_confirmatory_method_decisions_v1.csv
%
% Outputs:
%   00_data\outputs\reports\ARBITER_paired_nat_overcall_table_v1.csv
%   00_data\outputs\reports\ARBITER_paired_nat_overcall_per_core_v1.csv
%   00_data\outputs\reports\ARBITER_paired_nat_overcall_manifest_v1.txt

clear; clc;

%% Bootstrap paths
thisFile  = mfilename('fullpath');
runDir    = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fullfile(matlabDir, 'utils'));
cfg = arbiter_config_paths();

%% Paths
inCsv       = fullfile(cfg.report_dir, 'ARBITER_confirmatory_method_decisions_v1.csv');
outSumCsv   = fullfile(cfg.report_dir, 'ARBITER_paired_nat_overcall_table_v1.csv');
outCoreCsv  = fullfile(cfg.report_dir, 'ARBITER_paired_nat_overcall_per_core_v1.csv');
outTxt      = fullfile(cfg.report_dir, 'ARBITER_paired_nat_overcall_manifest_v1.txt');
assert(isfile(inCsv), 'Missing input file: %s. Run run_28_confirmatory_endpoint_tables first.', inCsv);

%% Read method decisions
opts = detectImportOptions(inCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
D = readtable(inCsv, opts);

D.coreId = upper(strtrim(string(D.coreId)));
D.group = strtrim(string(D.group));
D.subset = strtrim(string(D.subset));
D.trueLabel = lower(strtrim(string(D.trueLabel)));
D.isNaT = lower(strtrim(string(D.isNaT)));
D.decision_baseline_only = lower(strtrim(string(D.decision_baseline_only)));
D.decision_locked_fusion_no_unc_gate = lower(strtrim(string(D.decision_locked_fusion_no_unc_gate)));
D.decision_locked_arbiter_2ch = lower(strtrim(string(D.decision_locked_arbiter_2ch)));

isNaT = D.isNaT == "true" | D.isNaT == "1" | lower(strtrim(string(D.subset))) == "nat";
N = sum(isNaT);
assert(N > 0, 'No normal-adjacent tissue cores detected in method decision table.');

Nat = D(isNaT, :);

%% Per-core paired comparison table
P = table();
P.coreId = Nat.coreId;
P.group = Nat.group;
P.arbiter = Nat.decision_locked_arbiter_2ch;
P.baseline_only = Nat.decision_baseline_only;
P.locked_no_gate = Nat.decision_locked_fusion_no_unc_gate;
P.baseline_cancer_to_noncancer = string((P.baseline_only == "cancer-like") & (P.arbiter ~= "cancer-like"));
P.nogate_cancer_to_noncancer = string((P.locked_no_gate == "cancer-like") & (P.arbiter ~= "cancer-like"));
P.arbiter_more_uncertain_than_baseline = string((P.arbiter == "uncertain") & (P.baseline_only ~= "uncertain"));
P.arbiter_more_uncertain_than_nogate = string((P.arbiter == "uncertain") & (P.locked_no_gate ~= "uncertain"));
P.baseline_cancer_to_noncancer(P.baseline_cancer_to_noncancer=="true") = "yes";
P.baseline_cancer_to_noncancer(P.baseline_cancer_to_noncancer=="false") = "no";
P.nogate_cancer_to_noncancer(P.nogate_cancer_to_noncancer=="true") = "yes";
P.nogate_cancer_to_noncancer(P.nogate_cancer_to_noncancer=="false") = "no";
P.arbiter_more_uncertain_than_baseline(P.arbiter_more_uncertain_than_baseline=="true") = "yes";
P.arbiter_more_uncertain_than_baseline(P.arbiter_more_uncertain_than_baseline=="false") = "no";
P.arbiter_more_uncertain_than_nogate(P.arbiter_more_uncertain_than_nogate=="true") = "yes";
P.arbiter_more_uncertain_than_nogate(P.arbiter_more_uncertain_than_nogate=="false") = "no";

writetable(P, outCoreCsv);

%% Summary comparisons
comp = ["baseline-only"; "locked fusion, no gate"];
comparatorCancerCount = [sum(Nat.decision_baseline_only == "cancer-like"); sum(Nat.decision_locked_fusion_no_unc_gate == "cancer-like")];
arbiterCancerCount = [sum(Nat.decision_locked_arbiter_2ch == "cancer-like"); sum(Nat.decision_locked_arbiter_2ch == "cancer-like")];
comparatorCancerRate = 100 * comparatorCancerCount / N;
arbiterCancerRate = 100 * arbiterCancerCount / N;
absoluteReductionPctPt = comparatorCancerRate - arbiterCancerRate;
relativeReductionPct = 100 * absoluteReductionPctPt ./ comparatorCancerRate;
relativeReductionPct(comparatorCancerRate == 0) = NaN;

comparatorUncCount = [sum(Nat.decision_baseline_only == "uncertain"); sum(Nat.decision_locked_fusion_no_unc_gate == "uncertain")];
arbiterUncCount = [sum(Nat.decision_locked_arbiter_2ch == "uncertain"); sum(Nat.decision_locked_arbiter_2ch == "uncertain")];
comparatorUncRate = 100 * comparatorUncCount / N;
arbiterUncRate = 100 * arbiterUncCount / N;
changeInUncertainPctPt = arbiterUncRate - comparatorUncRate;

switchCancerToNonCancer = [sum((Nat.decision_baseline_only == "cancer-like") & (Nat.decision_locked_arbiter_2ch ~= "cancer-like")); ...
                           sum((Nat.decision_locked_fusion_no_unc_gate == "cancer-like") & (Nat.decision_locked_arbiter_2ch ~= "cancer-like"))];
switchNonCancerToCancer = [sum((Nat.decision_baseline_only ~= "cancer-like") & (Nat.decision_locked_arbiter_2ch == "cancer-like")); ...
                           sum((Nat.decision_locked_fusion_no_unc_gate ~= "cancer-like") & (Nat.decision_locked_arbiter_2ch == "cancer-like"))];

successPrimary = string(absoluteReductionPctPt > 0);
successPrimary(successPrimary=="true") = "yes";
successPrimary(successPrimary=="false") = "no";

Tpair = table(comp, repmat(N,2,1), comparatorCancerCount, comparatorCancerRate, arbiterCancerCount, arbiterCancerRate, ...
    absoluteReductionPctPt, relativeReductionPct, comparatorUncRate, arbiterUncRate, changeInUncertainPctPt, ...
    switchCancerToNonCancer, switchNonCancerToCancer, successPrimary, ...
    'VariableNames', {'Comparator','NaTCoresEvaluated','ComparatorCancerLikeCount','ComparatorCancerLikeRatePct', ...
    'ArbiterCancerLikeCount','ArbiterCancerLikeRatePct','AbsoluteReductionPctPt','RelativeReductionPct', ...
    'ComparatorUncertainRatePct','ArbiterUncertainRatePct','ChangeInUncertainPctPt', ...
    'CancerToNonCancerSwitchCount','NonCancerToCancerSwitchCount','PrimarySuccess'});

writetable(Tpair, outSumCsv);

%% Manifest text
fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open output text file: %s', outTxt);
fprintf(fid, 'Paired NaT overcall analysis (locked 21-core pilot)\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));
fprintf(fid, 'Input: %s\n\n', inCsv);
fprintf(fid, 'normal-adjacent tissue cores evaluated: %d\n\n', N);
for i = 1:height(Tpair)
    fprintf(fid, '%s\n', Tpair.Comparator(i));
    fprintf(fid, '  Comparator cancer-like : %d / %d (%.1f%%)\n', Tpair.ComparatorCancerLikeCount(i), N, Tpair.ComparatorCancerLikeRatePct(i));
    fprintf(fid, '  ARBITER cancer-like    : %d / %d (%.1f%%)\n', Tpair.ArbiterCancerLikeCount(i), N, Tpair.ArbiterCancerLikeRatePct(i));
    fprintf(fid, '  Absolute reduction     : %.1f pct-pt\n', Tpair.AbsoluteReductionPctPt(i));
    fprintf(fid, '  Relative reduction     : %.1f%%\n', Tpair.RelativeReductionPct(i));
    fprintf(fid, '  Uncertain change       : %.1f pct-pt\n', Tpair.ChangeInUncertainPctPt(i));
    fprintf(fid, '  Primary success        : %s\n\n', Tpair.PrimarySuccess(i));
end
fclose(fid);

%% Console summary
fprintf('\nPaired NaT overcall table saved:\n  %s\n', outSumCsv);
fprintf('Per-core NaT comparison saved:\n  %s\n', outCoreCsv);
fprintf('Manifest saved:\n  %s\n', outTxt);
fprintf('\nPaired NaT comparison summary:\n');
disp(Tpair);
