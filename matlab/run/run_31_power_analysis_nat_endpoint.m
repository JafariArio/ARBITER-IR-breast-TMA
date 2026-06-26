%% run_31_power_analysis_nat_endpoint
% Power analysis for the locked primary endpoint:
%   normal-adjacent tissue cancer-like overcall rate at the core level.
%
% Confirmatory test:
%   one-sided exact McNemar test (paired core-level analysis)
%
% Confirmatory comparators:
%   - baseline-only
%   - locked fusion, no gate
%
% Inputs:
%   00_data\outputs\reports\ARBITER_paired_nat_overcall_table_v1.csv
%
% Outputs:
%   00_data\outputs\reports\ARBITER_nat_endpoint_power_table_v1.csv
%   00_data\outputs\reports\ARBITER_nat_endpoint_power_table_v1.mat
%   00_data\outputs\reports\ARBITER_nat_endpoint_power_manifest_v1.txt

clear; clc;

%% Bootstrap paths
thisFile  = mfilename('fullpath');
runDir    = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fullfile(matlabDir, 'utils'));
cfg = arbiter_config_paths();

%% Paths
inCsv   = fullfile(cfg.report_dir, 'ARBITER_paired_nat_overcall_table_v1.csv');
outCsv  = fullfile(cfg.report_dir, 'ARBITER_nat_endpoint_power_table_v1.csv');
outMat  = fullfile(cfg.report_dir, 'ARBITER_nat_endpoint_power_table_v1.mat');
outTxt  = fullfile(cfg.report_dir, 'ARBITER_nat_endpoint_power_manifest_v1.txt');
assert(isfile(inCsv), 'Missing input file: %s. Run run_29_paired_nat_overcall_analysis first.', inCsv);

%% Read paired endpoint summary
opts = detectImportOptions(inCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
T = readtable(inCsv, opts);

numVars = {'NaTCoresEvaluated','ComparatorCancerLikeCount','ComparatorCancerLikeRatePct', ...
           'ArbiterCancerLikeCount','ArbiterCancerLikeRatePct','AbsoluteReductionPctPt', ...
           'RelativeReductionPct','ComparatorUncertainRatePct','ArbiterUncertainRatePct', ...
           'ChangeInUncertainPctPt','CancerToNonCancerSwitchCount','NonCancerToCancerSwitchCount'};
for i = 1:numel(numVars)
    if ismember(numVars{i}, T.Properties.VariableNames)
        T.(numVars{i}) = double(str2double(string(T.(numVars{i}))));
    end
end
T.Comparator = strtrim(string(T.Comparator));

%% Locked planning choices
alphaOneSided = 0.025;
targetPower = [0.80; 0.90];
attenuationFactor = 0.75;        % 25% smaller beneficial effect than observed
reverseSwitchFloor = 0.01;       % protect against optimistic zero-reverse pilot
nMax = 200;

%% Build scenario table
nRows = height(T) * 2;
Comparator = strings(nRows,1);
Scenario = strings(nRows,1);
AlphaOneSided = nan(nRows,1);
ObservedNaTCores = nan(nRows,1);
P10_ComparatorCancer_ArbiterNonCancer = nan(nRows,1);
P01_ComparatorNonCancer_ArbiterCancer = nan(nRows,1);
AttenuationFactor = nan(nRows,1);
ReverseSwitchFloor = nan(nRows,1);
MinN80 = nan(nRows,1);
MinN90 = nan(nRows,1);
PowerAtMinN80 = nan(nRows,1);
PowerAtMinN90 = nan(nRows,1);

row = 0;
for i = 1:height(T)
    nNat = T.NaTCoresEvaluated(i);
    p10_obs = T.CancerToNonCancerSwitchCount(i) / nNat;
    p01_obs = T.NonCancerToCancerSwitchCount(i) / nNat;

    % Observed scenario
    row = row + 1;
    Comparator(row) = T.Comparator(i);
    Scenario(row) = "observed";
    AlphaOneSided(row) = alphaOneSided;
    ObservedNaTCores(row) = nNat;
    P10_ComparatorCancer_ArbiterNonCancer(row) = p10_obs;
    P01_ComparatorNonCancer_ArbiterCancer(row) = p01_obs;
    AttenuationFactor(row) = 1.00;
    ReverseSwitchFloor(row) = 0.00;
    MinN80(row) = arbiter_find_min_n_exact_mcnemar_v1(p10_obs, p01_obs, alphaOneSided, targetPower(1), nMax);
    MinN90(row) = arbiter_find_min_n_exact_mcnemar_v1(p10_obs, p01_obs, alphaOneSided, targetPower(2), nMax);
    PowerAtMinN80(row) = arbiter_exact_mcnemar_power_v1(MinN80(row), p10_obs, p01_obs, alphaOneSided);
    PowerAtMinN90(row) = arbiter_exact_mcnemar_power_v1(MinN90(row), p10_obs, p01_obs, alphaOneSided);

    % Conservative scenario
    row = row + 1;
    p10_cons = p10_obs * attenuationFactor;
    p01_cons = max(p01_obs, reverseSwitchFloor);
    if (p10_cons + p01_cons) >= 1
        error('Invalid conservative planning probabilities for %s: p10+p01 >= 1', T.Comparator(i));
    end
    Comparator(row) = T.Comparator(i);
    Scenario(row) = "conservative_25pct_attenuated";
    AlphaOneSided(row) = alphaOneSided;
    ObservedNaTCores(row) = nNat;
    P10_ComparatorCancer_ArbiterNonCancer(row) = p10_cons;
    P01_ComparatorNonCancer_ArbiterCancer(row) = p01_cons;
    AttenuationFactor(row) = attenuationFactor;
    ReverseSwitchFloor(row) = reverseSwitchFloor;
    MinN80(row) = arbiter_find_min_n_exact_mcnemar_v1(p10_cons, p01_cons, alphaOneSided, targetPower(1), nMax);
    MinN90(row) = arbiter_find_min_n_exact_mcnemar_v1(p10_cons, p01_cons, alphaOneSided, targetPower(2), nMax);
    PowerAtMinN80(row) = arbiter_exact_mcnemar_power_v1(MinN80(row), p10_cons, p01_cons, alphaOneSided);
    PowerAtMinN90(row) = arbiter_exact_mcnemar_power_v1(MinN90(row), p10_cons, p01_cons, alphaOneSided);
end

Tout = table(Comparator, Scenario, AlphaOneSided, ObservedNaTCores, ...
    P10_ComparatorCancer_ArbiterNonCancer, P01_ComparatorNonCancer_ArbiterCancer, ...
    AttenuationFactor, ReverseSwitchFloor, MinN80, PowerAtMinN80, MinN90, PowerAtMinN90);

writetable(Tout, outCsv);
save(outMat, 'Tout', 'alphaOneSided', 'attenuationFactor', 'reverseSwitchFloor');

%% Manifest text
fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open output text file: %s', outTxt);
fprintf(fid, 'NaT primary-endpoint power analysis\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));
fprintf(fid, 'Input: %s\n\n', inCsv);
fprintf(fid, 'Locked confirmatory test: one-sided exact McNemar test\n');
fprintf(fid, 'Alpha (one-sided): %.3f\n', alphaOneSided);
fprintf(fid, 'Observed scenario uses pilot discordant-pair rates directly.\n');
fprintf(fid, 'Conservative scenario applies:\n');
fprintf(fid, '  beneficial effect attenuation factor = %.2f\n', attenuationFactor);
fprintf(fid, '  reverse-switch floor = %.3f\n\n', reverseSwitchFloor);

for i = 1:height(Tout)
    fprintf(fid, '%s | %s\n', Tout.Comparator(i), Tout.Scenario(i));
    fprintf(fid, '  p10 comparator-cancer -> arbiter-noncancer : %.4f\n', Tout.P10_ComparatorCancer_ArbiterNonCancer(i));
    fprintf(fid, '  p01 comparator-noncancer -> arbiter-cancer : %.4f\n', Tout.P01_ComparatorNonCancer_ArbiterCancer(i));
    fprintf(fid, '  Min N for 80%% power                        : %d (power %.3f)\n', Tout.MinN80(i), Tout.PowerAtMinN80(i));
    fprintf(fid, '  Min N for 90%% power                        : %d (power %.3f)\n\n', Tout.MinN90(i), Tout.PowerAtMinN90(i));
end
fclose(fid);

fprintf('\nNaT endpoint power table saved:\n  %s\n', outCsv);
fprintf('Manifest saved:\n  %s\n', outTxt);
fprintf('\nPower-analysis summary:\n');
disp(Tout);
