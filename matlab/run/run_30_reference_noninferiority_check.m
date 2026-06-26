%% run_30_reference_noninferiority_check
% Check the locked 5-point reference conservative-accuracy safeguard for the
% confirmatory 21-core pilot.
%
% Inputs:
%   00_data\outputs\reports\ARBITER_confirmatory_endpoint_table_v1.csv
%
% Outputs:
%   00_data\outputs\reports\ARBITER_reference_noninferiority_check_v1.csv
%   00_data\outputs\reports\ARBITER_reference_noninferiority_check_v1.mat
%   00_data\outputs\reports\ARBITER_reference_noninferiority_manifest_v1.txt

clear; clc;

%% Bootstrap paths
thisFile  = mfilename('fullpath');
runDir    = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fullfile(matlabDir, 'utils'));
cfg = arbiter_config_paths();

%% Paths
inCsv    = fullfile(cfg.report_dir, 'ARBITER_confirmatory_endpoint_table_v1.csv');
outCsv   = fullfile(cfg.report_dir, 'ARBITER_reference_noninferiority_check_v1.csv');
outMat   = fullfile(cfg.report_dir, 'ARBITER_reference_noninferiority_check_v1.mat');
outTxt   = fullfile(cfg.report_dir, 'ARBITER_reference_noninferiority_manifest_v1.txt');
assert(isfile(inCsv), 'Missing input file: %s. Run run_28_confirmatory_endpoint_tables first.', inCsv);

%% Read confirmatory table
opts = detectImportOptions(inCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
T = readtable(inCsv, opts);

if ismember('ReferenceConservativeAccuracyPct', T.Properties.VariableNames)
    T.ReferenceConservativeAccuracyPct = double(str2double(string(T.ReferenceConservativeAccuracyPct)));
else
    error('Missing ReferenceConservativeAccuracyPct in %s', inCsv);
end
T.method = lower(strtrim(string(T.method)));

marginPctPt = 5.0;
idxArb = find(T.method == "locked arbiter 2ch", 1, 'first');
assert(~isempty(idxArb), 'Could not find locked ARBITER 2ch row.');
arbRefCons = T.ReferenceConservativeAccuracyPct(idxArb);

comparators = ["baseline-only"; "locked fusion, no gate"];
compRefCons = nan(2,1);
deltaArbMinusComp = nan(2,1);
passes = strings(2,1);

for i = 1:2
    idx = find(T.method == comparators(i), 1, 'first');
    assert(~isempty(idx), 'Could not find comparator row: %s', comparators(i));
    compRefCons(i) = T.ReferenceConservativeAccuracyPct(idx);
    deltaArbMinusComp(i) = arbRefCons - compRefCons(i);
    passes(i) = string(deltaArbMinusComp(i) >= -marginPctPt);
end
passes(passes=="true") = "yes";
passes(passes=="false") = "no";

Tout = table(comparators, repmat(arbRefCons,2,1), compRefCons, deltaArbMinusComp, repmat(marginPctPt,2,1), passes, ...
    'VariableNames', {'Comparator','ArbiterReferenceConservativeAccuracyPct','ComparatorReferenceConservativeAccuracyPct', ...
    'DeltaArbiterMinusComparatorPctPt','NonInferiorityMarginPctPt','PassesNonInferiority'});

writetable(Tout, outCsv);
save(outMat, 'Tout', 'marginPctPt');

fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open output text file: %s', outTxt);
fprintf(fid, 'Reference non-inferiority check (locked 21-core pilot)\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));
fprintf(fid, 'Input: %s\n\n', inCsv);
fprintf(fid, 'Locked safeguard margin: %.1f percentage points\n\n', marginPctPt);
for i = 1:height(Tout)
    fprintf(fid, '%s\n', Tout.Comparator(i));
    fprintf(fid, '  ARBITER ref conservative acc : %.1f%%\n', Tout.ArbiterReferenceConservativeAccuracyPct(i));
    fprintf(fid, '  Comparator ref conservative  : %.1f%%\n', Tout.ComparatorReferenceConservativeAccuracyPct(i));
    fprintf(fid, '  Delta (ARB - comparator)     : %.1f pct-pt\n', Tout.DeltaArbiterMinusComparatorPctPt(i));
    fprintf(fid, '  Passes margin                : %s\n\n', Tout.PassesNonInferiority(i));
end
fclose(fid);

fprintf('\nReference non-inferiority check saved:\n  %s\n', outCsv);
fprintf('Manifest saved:\n  %s\n', outTxt);
fprintf('\nReference safeguard summary:\n');
disp(Tout);
