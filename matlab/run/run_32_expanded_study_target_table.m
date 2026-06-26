%% run_32_expanded_study_target_table
% Build the expanded-study target table from the locked endpoint power
% analysis and the current 21-core pilot composition.
%
% Inputs:
%   00_data\outputs\reports\ARBITER_nat_endpoint_power_table_v1.csv
%   00_data\outputs\reports\ARBITER_confirmatory_endpoint_table_v1.csv
%
% Outputs:
%   00_data\outputs\reports\ARBITER_expanded_study_target_table_v1.csv
%   00_data\outputs\reports\ARBITER_expanded_study_target_table_v1.mat
%   00_data\outputs\reports\ARBITER_expanded_study_target_manifest_v1.txt

clear; clc;

%% Bootstrap paths
thisFile  = mfilename('fullpath');
runDir    = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fullfile(matlabDir, 'utils'));
cfg = arbiter_config_paths();

%% Paths
powerCsv = fullfile(cfg.report_dir, 'ARBITER_nat_endpoint_power_table_v1.csv');
endptCsv = fullfile(cfg.report_dir, 'ARBITER_confirmatory_endpoint_table_v1.csv');
outCsv   = fullfile(cfg.report_dir, 'ARBITER_expanded_study_target_table_v1.csv');
outMat   = fullfile(cfg.report_dir, 'ARBITER_expanded_study_target_table_v1.mat');
outTxt   = fullfile(cfg.report_dir, 'ARBITER_expanded_study_target_manifest_v1.txt');

assert(isfile(powerCsv), 'Missing power table: %s. Run run_31_power_analysis_nat_endpoint first.', powerCsv);
assert(isfile(endptCsv), 'Missing confirmatory endpoint table: %s. Run run_28_confirmatory_endpoint_tables first.', endptCsv);

%% Read tables
optsP = detectImportOptions(powerCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(optsP.VariableTypes); optsP.VariableTypes{ii} = 'string'; end
P = readtable(powerCsv, optsP);
numP = {'AlphaOneSided','ObservedNaTCores','P10_ComparatorCancer_ArbiterNonCancer', ...
        'P01_ComparatorNonCancer_ArbiterCancer','AttenuationFactor','ReverseSwitchFloor', ...
        'MinN80','PowerAtMinN80','MinN90','PowerAtMinN90'};
for i = 1:numel(numP)
    if ismember(numP{i}, P.Properties.VariableNames)
        P.(numP{i}) = double(str2double(string(P.(numP{i}))));
    end
end
P.Comparator = strtrim(string(P.Comparator));
P.Scenario = strtrim(string(P.Scenario));

optsE = detectImportOptions(endptCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(optsE.VariableTypes); optsE.VariableTypes{ii} = 'string'; end
E = readtable(endptCsv, optsE);
numE = {'NaTCoresEvaluated','ReferenceCoresEvaluated'};
for i = 1:numel(numE)
    if ismember(numE{i}, E.Properties.VariableNames)
        E.(numE{i}) = double(str2double(string(E.(numE{i}))));
    end
end

currentNaT = E.NaTCoresEvaluated(1);
currentRef = E.ReferenceCoresEvaluated(1);

consRows = P(P.Scenario == "conservative_25pct_attenuated", :);
if isempty(consRows)
    error('Could not find conservative power-analysis rows.');
end

reqNat80 = max(consRows.MinN80);
reqNat90 = max(consRows.MinN90);

recommendedNaTTotal = max(30, ceil(reqNat90 / 5) * 5);
recommendedRefTotal = max(20, currentRef);
recommendedReserve = 1;
recommendedAdditionalTotal = (recommendedNaTTotal - currentNaT) + (recommendedRefTotal - currentRef) + recommendedReserve;

TargetComponent = ["Evaluable normal-adjacent tissue cores total"; ...
                   "Reference cores total"; ...
                   "Reserve cores"; ...
                   "Recommended additional cores total"];
CurrentCount = [currentNaT; currentRef; 0; 0];
RequirementFor80Power = [reqNat80; NaN; NaN; NaN];
RequirementFor90Power = [reqNat90; NaN; NaN; NaN];
RecommendedTotal = [recommendedNaTTotal; recommendedRefTotal; recommendedReserve; recommendedAdditionalTotal];
AdditionalNeeded = [recommendedNaTTotal - currentNaT; recommendedRefTotal - currentRef; recommendedReserve; recommendedAdditionalTotal];
Priority = ["high"; "high"; "medium"; "high"];
Rationale = ["Primary endpoint power target (conservative 90%% scenario across comparators)"; ...
             "Stabilize 5-point reference non-inferiority safeguard"; ...
             "Operational reserve for exclusions or failed audits"; ...
             "Combined acquisition recommendation"];

Tout = table(TargetComponent, CurrentCount, RequirementFor80Power, RequirementFor90Power, ...
             RecommendedTotal, AdditionalNeeded, Priority, Rationale);

writetable(Tout, outCsv);
save(outMat, 'Tout', 'P', 'E', 'currentNaT', 'currentRef', 'reqNat80', 'reqNat90', ...
    'recommendedNaTTotal', 'recommendedRefTotal', 'recommendedReserve', 'recommendedAdditionalTotal');

fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open output text file: %s', outTxt);
fprintf(fid, 'Expanded-study target table\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));
fprintf(fid, 'Current pilot composition:\n');
fprintf(fid, '  normal-adjacent tissue cores       : %d\n', currentNaT);
fprintf(fid, '  Reference cores : %d\n\n', currentRef);
fprintf(fid, 'Conservative NaT requirement across comparators:\n');
fprintf(fid, '  80%% power : %d evaluable normal-adjacent tissue cores\n', reqNat80);
fprintf(fid, '  90%% power : %d evaluable normal-adjacent tissue cores\n\n', reqNat90);
fprintf(fid, 'Recommended planning totals:\n');
fprintf(fid, '  Evaluable normal-adjacent tissue cores total : %d\n', recommendedNaTTotal);
fprintf(fid, '  Reference cores total     : %d\n', recommendedRefTotal);
fprintf(fid, '  Reserve cores             : %d\n', recommendedReserve);
fprintf(fid, '  Recommended additional    : %d\n\n', recommendedAdditionalTotal);
fprintf(fid, 'This planning recommendation is intentionally pragmatic: it rounds the NaT target to a stable\n');
fprintf(fid, 'operational number (>=30) while preserving a 20-core reference block for the 5-point safeguard.\n');
fclose(fid);

fprintf('\nExpanded-study target table saved:\n  %s\n', outCsv);
fprintf('Manifest saved:\n  %s\n', outTxt);
fprintf('\nExpanded-study target summary:\n');
disp(Tout);
