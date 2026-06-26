%% run_28_confirmatory_endpoint_tables
% Build the locked confirmatory endpoint tables for the 21-core pilot.
%
% Confirmatory scope:
%   - primary endpoint: normal-adjacent tissue cancer-like overcall rate at core level
%   - secondary support: NaT uncertain rate
%   - safeguard metric: reference conservative accuracy
%
% Locked confirmatory comparators:
%   - baseline-only
%   - locked fusion without uncertainty gate
%   - locked ARBITER 2ch
%
% Inputs:
%   00_data\outputs\reports\ARBITER_core_channel_scores_v1.csv
%
% Outputs:
%   00_data\outputs\reports\ARBITER_confirmatory_method_decisions_v1.csv
%   00_data\outputs\reports\ARBITER_confirmatory_endpoint_table_v1.csv
%   00_data\outputs\reports\ARBITER_confirmatory_endpoint_table_v1.mat
%   00_data\outputs\reports\ARBITER_confirmatory_endpoint_manifest_v1.txt

clear; clc;

%% Bootstrap paths
thisFile  = mfilename('fullpath');
runDir    = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fullfile(matlabDir, 'utils'));
cfg = arbiter_config_paths();

%% Paths
inCsv      = fullfile(cfg.report_dir, 'ARBITER_core_channel_scores_v1.csv');
outDecCsv  = fullfile(cfg.report_dir, 'ARBITER_confirmatory_method_decisions_v1.csv');
outTabCsv  = fullfile(cfg.report_dir, 'ARBITER_confirmatory_endpoint_table_v1.csv');
outTabMat  = fullfile(cfg.report_dir, 'ARBITER_confirmatory_endpoint_table_v1.mat');
outTxt     = fullfile(cfg.report_dir, 'ARBITER_confirmatory_endpoint_manifest_v1.txt');

assert(isfile(inCsv), 'Missing input file: %s', inCsv);
if ~exist(cfg.report_dir, 'dir')
    mkdir(cfg.report_dir);
end

%% Read clean core table
opts = detectImportOptions(inCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
T = readtable(inCsv, opts);

numVars = {'meanPBaseline','meanPPrototype','meanPEqualWeight','meanPLockedAlphaNoGate', ...
           'meanPFuse','meanUncFuse','fracLikelyCancer','fracLikelyHealthy','fracUncertain'};
for i = 1:numel(numVars)
    if ismember(numVars{i}, T.Properties.VariableNames)
        T.(numVars{i}) = double(str2double(string(T.(numVars{i}))));
    end
end

if ~ismember('subset', T.Properties.VariableNames)
    T.subset = repmat("", height(T), 1);
end
if ~ismember('group', T.Properties.VariableNames)
    T.group = repmat("", height(T), 1);
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

T.coreId = upper(strtrim(string(T.coreId)));
T.group = strtrim(string(T.group));
T.subset = strtrim(string(T.subset));
T.trueLabel = lower(strtrim(string(T.trueLabel)));
T.useForValidation = lower(strtrim(string(T.useForValidation)));
T.coreDecision = lower(strtrim(string(T.coreDecision)));
T.coreDecision = replace(T.coreDecision, '_', '-');

keep = ~ismissing(T.coreId) & strlength(T.coreId) > 0 & ~isnan(T.meanPFuse);
T = T(keep, :);

%% Locked thresholds and masks
cancerThr = 0.60;
healthyThr = 0.40;
marginPctPt = 5.0;

isNaT = lower(T.subset) == "nat";
if ~any(isNaT)
    isNaT = startsWith(lower(T.group), "nat");
end
isRef = lower(T.subset) == "reference";
useVal = T.useForValidation == "1" | T.useForValidation == "true" | T.useForValidation == "yes";
refVal = isRef & useVal & (T.trueLabel == "cancer" | T.trueLabel == "healthy");

%% Build decisions for locked confirmatory methods
D = table();
D.coreId = T.coreId;
D.group = T.group;
D.subset = T.subset;
D.trueLabel = T.trueLabel;
D.useForValidation = T.useForValidation;
D.isNaT = string(isNaT);
D.isReferenceValidation = string(refVal);

% baseline-only
baseDec = repmat("uncertain", height(T), 1);
baseDec(T.meanPBaseline >= cancerThr) = "cancer-like";
baseDec(T.meanPBaseline <= healthyThr) = "healthy-like";

% no-gate locked fusion
nogateDec = repmat("uncertain", height(T), 1);
nogateDec(T.meanPLockedAlphaNoGate >= cancerThr) = "cancer-like";
nogateDec(T.meanPLockedAlphaNoGate <= healthyThr) = "healthy-like";

% locked arbiter
arbDec = T.coreDecision;
arbDec(arbDec == "") = "missing";

D.decision_baseline_only = baseDec;
D.decision_locked_fusion_no_unc_gate = nogateDec;
D.decision_locked_arbiter_2ch = arbDec;

writetable(D, outDecCsv);

%% Method-level confirmatory table
method = ["baseline-only"; "locked fusion, no gate"; "locked ARBITER 2ch"];
methodKey = ["baseline"; "nogate"; "arbiter"];

nNaT = repmat(sum(isNaT), 3, 1);
nRef = repmat(sum(refVal), 3, 1);

natCancerCount = zeros(3,1);
natCancerRate = nan(3,1);
natUncertainCount = zeros(3,1);
natUncertainRate = nan(3,1);
meanNaTUncertainPixels = nan(3,1);
refCoverage = nan(3,1);
refSelectiveAccuracy = nan(3,1);
refConservativeAccuracy = nan(3,1);

allDecisions = {baseDec, nogateDec, arbDec};
for i = 1:3
    dec = allDecisions{i};

    natCancerCount(i) = sum(dec(isNaT) == "cancer-like");
    natUncertainCount(i) = sum(dec(isNaT) == "uncertain");
    if any(isNaT)
        natCancerRate(i) = 100 * mean(dec(isNaT) == "cancer-like");
        natUncertainRate(i) = 100 * mean(dec(isNaT) == "uncertain");
    end

    if i == 1
        meanNaTUncertainPixels(i) = 100 * mean(1 - T.meanPBaseline(isNaT), 'omitnan');
    elseif i == 2
        meanNaTUncertainPixels(i) = 100 * mean(abs(0.5 - T.meanPLockedAlphaNoGate(isNaT)) < 0.10, 'omitnan');
    else
        meanNaTUncertainPixels(i) = 100 * mean(T.fracUncertain(isNaT), 'omitnan');
    end

    dref = dec(refVal);
    yref = T.trueLabel(refVal);
    called = dref ~= "uncertain" & dref ~= "missing" & dref ~= "";
    if any(refVal)
        refCoverage(i) = 100 * mean(called);
        if any(called)
            pred = repmat("", sum(called), 1);
            pred(dref(called) == "cancer-like") = "cancer";
            pred(dref(called) == "healthy-like") = "healthy";
            refSelectiveAccuracy(i) = 100 * mean(pred == yref(called));
        end
        correctCons = zeros(sum(refVal),1);
        correctCons((dref == "cancer-like") & (yref == "cancer")) = 1;
        correctCons((dref == "healthy-like") & (yref == "healthy")) = 1;
        refConservativeAccuracy(i) = 100 * mean(correctCons);
    end
end

passSafeguardVsArbiter = repmat("n/a",3,1);
passSafeguardVsArbiter(1) = string(refConservativeAccuracy(3) >= refConservativeAccuracy(1) - marginPctPt);
passSafeguardVsArbiter(2) = string(refConservativeAccuracy(3) >= refConservativeAccuracy(2) - marginPctPt);
passSafeguardVsArbiter(3) = "n/a";
passSafeguardVsArbiter(passSafeguardVsArbiter=="true") = "yes";
passSafeguardVsArbiter(passSafeguardVsArbiter=="false") = "no";

Tend = table(method, methodKey, nNaT, natCancerCount, natCancerRate, natUncertainCount, natUncertainRate, ...
    meanNaTUncertainPixels, nRef, refCoverage, refSelectiveAccuracy, refConservativeAccuracy, ...
    passSafeguardVsArbiter, ...
    'VariableNames', {'method','methodKey','NaTCoresEvaluated','NaTCancerLikeCount','NaTCancerLikeRatePct', ...
    'NaTUncertainCount','NaTUncertainRatePct','MeanNaTUncertainSupportPct','ReferenceCoresEvaluated', ...
    'ReferenceCoveragePct','ReferenceSelectiveAccuracyPct','ReferenceConservativeAccuracyPct', ...
    'Passes5PtReferenceSafeguardVsArbiter'});

writetable(Tend, outTabCsv);
save(outTabMat, 'Tend', 'D', 'marginPctPt', 'cancerThr', 'healthyThr');

%% Manifest text
fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open output text file: %s', outTxt);
fprintf(fid, 'ARBITER confirmatory endpoint table (locked 21-core pilot)\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));
fprintf(fid, 'Input: %s\n\n', inCsv);
fprintf(fid, 'Locked primary endpoint:\n');
fprintf(fid, '  normal-adjacent tissue cancer-like overcall rate at core level (lower is better)\n\n');
fprintf(fid, 'Locked safeguard rule:\n');
fprintf(fid, '  Reference conservative accuracy for ARBITER must not be worse by more than %.1f percentage points\n', marginPctPt);
fprintf(fid, '  versus each confirmatory comparator.\n\n');
for i = 1:height(Tend)
    fprintf(fid, '%s\n', Tend.method(i));
    fprintf(fid, '  normal-adjacent tissue cancer-like   : %d / %d (%.1f%%)\n', Tend.NaTCancerLikeCount(i), Tend.NaTCoresEvaluated(i), Tend.NaTCancerLikeRatePct(i));
    fprintf(fid, '  NaT uncertain     : %d / %d (%.1f%%)\n', Tend.NaTUncertainCount(i), Tend.NaTCoresEvaluated(i), Tend.NaTUncertainRatePct(i));
    fprintf(fid, '  Ref conservative  : %.1f%%\n', Tend.ReferenceConservativeAccuracyPct(i));
    fprintf(fid, '  Safeguard vs ARB  : %s\n\n', Tend.Passes5PtReferenceSafeguardVsArbiter(i));
end
fclose(fid);

%% Console summary
fprintf('\nConfirmatory endpoint table saved:\n  %s\n', outTabCsv);
fprintf('Method decisions saved:\n  %s\n', outDecCsv);
fprintf('Manifest saved:\n  %s\n', outTxt);
fprintf('\nLocked confirmatory summary:\n');
disp(Tend(:, {'method','NaTCancerLikeCount','NaTCancerLikeRatePct','NaTUncertainCount','NaTUncertainRatePct','ReferenceConservativeAccuracyPct','Passes5PtReferenceSafeguardVsArbiter'}));
