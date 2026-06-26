%% run_26_run_locked2ch_on_wave1
% Apply the SAME locked 2-channel ARBITER model to the 15 Wave 1 cores.
%
% This script does not retune the model.
% It reuses the locked 2-channel package:
%   alpha      = 0.90
%   cancerThr  = 0.60
%   healthyThr = 0.40
%   uncThr     = 0.45
%
% For core-level final calls, it uses the exact-match effective thresholds:
%   tauC = 0.65
%   tauH = 0.35
%
% Inputs required under project_root:
%   00_data\manifests\wave1_core_list_v1.csv
%   00_data\outputs\models\baseline_logreg_v1_cleanNormal.mat
%   00_data\outputs\models\prototype_bank_v1.mat
%   00_data\outputs\models\ARBITER_2ch_final_package_v1.mat
%   00_data\interim\preproc\<core>_preproc_v0.mat
%
% Outputs:
%   00_data\outputs\reports_wave1\ARBITER_wave1_core_channel_scores_v1.csv
%   00_data\outputs\reports_wave1\ARBITER_wave1_core_channel_scores_v1.mat
%   00_data\outputs\reports_wave1\ARBITER_wave1_locked_manifest_v1.txt
%   00_data\outputs\maps_wave1\<core>_wave1_bestFused_triplet.mat

clear; clc;

%% Bootstrap repository paths
thisFile  = mfilename('fullpath');
runDir    = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fileparts(matlabDir));
cfg = arbiter_config_paths();

%% Paths
manifestDir    = cfg.manifest_dir;
preprocDir     = cfg.interim_preproc_dir;
modelDir       = cfg.model_dir;
wave1ReportDir = cfg.wave1_report_dir;
wave1MapsDir   = cfg.wave1_maps_dir;

if ~exist(wave1ReportDir, 'dir')
    mkdir(wave1ReportDir);
end
if ~exist(wave1MapsDir, 'dir')
    mkdir(wave1MapsDir);
end

inListCsv    = fullfile(manifestDir, 'wave1_core_list_v1.csv');
baselineFile = fullfile(modelDir, 'baseline_logreg_v1_cleanNormal.mat');
protoFile    = fullfile(modelDir, 'prototype_bank_v1.mat');
finalPkgFile = fullfile(modelDir, 'ARBITER_2ch_final_package_v1.mat');

outCsv       = fullfile(wave1ReportDir, 'ARBITER_wave1_core_channel_scores_v1.csv');
outMat       = fullfile(wave1ReportDir, 'ARBITER_wave1_core_channel_scores_v1.mat');
outTxt       = fullfile(wave1ReportDir, 'ARBITER_wave1_locked_manifest_v1.txt');

assert(isfile(inListCsv),    'Missing file: %s. Run run_24_build_wave1_core_manifest first.', inListCsv);
assert(isfile(baselineFile), 'Missing baseline model: %s', baselineFile);
assert(isfile(protoFile),    'Missing prototype bank: %s', protoFile);
assert(isfile(finalPkgFile), 'Missing final locked package: %s', finalPkgFile);

%% Read Wave 1 list
opts = detectImportOptions(inListCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
Tlist = readtable(inListCsv, opts);
assert(ismember('core_id', Tlist.Properties.VariableNames), 'wave1_core_list_v1.csv must contain core_id');
coreId = upper(strtrim(string(Tlist.core_id)));
n = numel(coreId);

%% Load locked final package
Spkg = load(finalPkgFile);
alpha = 0.90;
cancerThr = 0.60;
healthyThr = 0.40;
uncThr = 0.45;
tauC = 0.65;
tauH = 0.35;

if isfield(Spkg, 'final2ch') && isstruct(Spkg.final2ch)
    final2ch = Spkg.final2ch;
    if isfield(final2ch, 'design') && isstruct(final2ch.design)
        if isfield(final2ch.design, 'alpha'),      alpha = double(final2ch.design.alpha); end
        if isfield(final2ch.design, 'cancerThr'),  cancerThr = double(final2ch.design.cancerThr); end
        if isfield(final2ch.design, 'healthyThr'), healthyThr = double(final2ch.design.healthyThr); end
        if isfield(final2ch.design, 'uncThr'),     uncThr = double(final2ch.design.uncThr); end
    end
end

%% Load baseline model package
Smdl = load(baselineFile);
assert(isfield(Smdl, 'mu'),    'baseline_logreg_v1_cleanNormal.mat missing mu');
assert(isfield(Smdl, 'sigma'), 'baseline_logreg_v1_cleanNormal.mat missing sigma');
mu = double(Smdl.mu(:))';
sigma = double(Smdl.sigma(:))';
sigma(sigma < 1e-12) = 1;

mdlCandidates = fieldnames(Smdl);
mdlField = "";
for i = 1:numel(mdlCandidates)
    nm = string(mdlCandidates{i});
    if contains(lower(nm), "mdl")
        mdlField = nm;
        break;
    end
end
assert(strlength(mdlField) > 0, 'Could not find baseline model object field in %s', baselineFile);
mdl = Smdl.(char(mdlField));

%% Load prototype bank
Sproto = load(protoFile);
assert(isfield(Sproto, 'protoTumor'),   'prototype_bank_v1.mat missing protoTumor');
assert(isfield(Sproto, 'protoHealthy'), 'prototype_bank_v1.mat missing protoHealthy');
protoTumor   = double(Sproto.protoTumor);
protoHealthy = double(Sproto.protoHealthy);

%% Preallocate outputs
group = repmat("Wave1_Unknown", n, 1);
subset = repmat("Wave1", n, 1);
meanPBaseline          = nan(n,1);
meanPPrototype         = nan(n,1);
meanPEqualWeight       = nan(n,1);
meanPLockedAlphaNoGate = nan(n,1);
meanPFuse              = nan(n,1);
meanUncFuse            = nan(n,1);
fracLikelyCancer       = nan(n,1);
fracLikelyHealthy      = nan(n,1);
fracUncertain          = nan(n,1);
coreDecision_tau065_035= strings(n,1);
nPixelsUsed            = nan(n,1);
status                 = strings(n,1);
comments               = strings(n,1);

%% Main loop
for i = 1:n
    cid = coreId(i);
    preprocFile = fullfile(preprocDir, cid + "_preproc_v0.mat");

    fprintf('[%d/%d] Wave 1 locked rerun for %s\n', i, n, cid);

    if ~isfile(preprocFile)
        status(i) = "missing_preproc";
        comments(i) = "Preprocessed core file not found";
        fprintf('  SKIP | missing preproc: %s\n', preprocFile);
        continue;
    end

    try
        S = load(preprocFile, 'core');
        assert(isfield(S, 'core'), 'Variable "core" missing in %s', preprocFile);
        core = S.core;

        assert(isfield(core, 'X') && isnumeric(core.X), 'core.X missing or invalid for %s', cid);
        X = double(core.X);
        Xz = (X - mu) ./ sigma;
        nPixelsUsed(i) = size(Xz, 1);

        [~, score] = predict(mdl, Xz);
        if size(score,2) >= 2
            pBase = double(score(:,2));
        else
            pBase = double(score(:,1));
        end

        dTum = pdist2(Xz, protoTumor, 'squaredeuclidean');
        dHea = pdist2(Xz, protoHealthy, 'squaredeuclidean');
        dTumMin = min(dTum, [], 2);
        dHeaMin = min(dHea, [], 2);

        margin = dHeaMin - dTumMin;
        scale = median(abs(margin), 'omitnan') + eps;
        pProto = 1 ./ (1 + exp(-margin ./ scale));

        pFuse = alpha .* pBase + (1 - alpha) .* pProto;
        uncCentral  = 1 - abs(2 .* pFuse - 1);
        uncDisagree = abs(pBase - pProto);
        uncFuse = 0.7 .* uncCentral + 0.3 .* uncDisagree;

        idxC = pFuse >= cancerThr  & uncFuse < uncThr;
        idxH = pFuse <= healthyThr & uncFuse < uncThr;
        idxU = ~(idxC | idxH);

        fracC = mean(idxC);
        fracH = mean(idxH);
        fracU = mean(idxU);

        if fracC >= tauC
            decCore = "cancer-like";
        elseif fracH >= tauH
            decCore = "healthy-like";
        else
            decCore = "uncertain";
        end

        meanPBaseline(i)          = mean(pBase, 'omitnan');
        meanPPrototype(i)         = mean(pProto, 'omitnan');
        meanPEqualWeight(i)       = mean((pBase + pProto) ./ 2, 'omitnan');
        meanPLockedAlphaNoGate(i) = mean(alpha .* pBase + (1 - alpha) .* pProto, 'omitnan');
        meanPFuse(i)              = mean(pFuse, 'omitnan');
        meanUncFuse(i)            = mean(uncFuse, 'omitnan');
        fracLikelyCancer(i)       = fracC;
        fracLikelyHealthy(i)      = fracH;
        fracUncertain(i)          = fracU;
        coreDecision_tau065_035(i)= decCore;
        status(i)                 = "ok";

        if isfield(core, 'tissueMask') && isnumeric(core.tissueMask)
            H = size(core.tissueMask,1);
            W = size(core.tissueMask,2);
            linIdx = find(core.tissueMask);

            pBaseMap = nan(H,W);
            pProtoMap = nan(H,W);
            pFuseMap = nan(H,W);
            uncFuseMap = nan(H,W);
            decMap = nan(H,W);

            pixelDec = nan(size(pFuse));
            pixelDec(idxC) = 1;
            pixelDec(idxH) = 0;
            pixelDec(idxU) = -1;

            pBaseMap(linIdx) = pBase;
            pProtoMap(linIdx) = pProto;
            pFuseMap(linIdx) = pFuse;
            uncFuseMap(linIdx) = uncFuse;
            decMap(linIdx) = pixelDec;

            save(fullfile(wave1MapsDir, cid + "_wave1_bestFused_triplet.mat"), ...
                'cid','alpha','cancerThr','healthyThr','uncThr','tauC','tauH', ...
                'pBaseMap','pProtoMap','pFuseMap','uncFuseMap','decMap', ...
                'pBase','pProto','pFuse','uncFuse','pixelDec');
        end

        fprintf('  OK   | meanPFuse=%.4f | meanUnc=%.4f | core=%s\n', meanPFuse(i), meanUncFuse(i), decCore);

    catch ME
        status(i) = "failed";
        comments(i) = string(ME.message);
        fprintf('  FAIL | %s\n', ME.message);
    end
end

%% Save outputs
Tw1 = table(coreId, group, subset, meanPBaseline, meanPPrototype, meanPEqualWeight, ...
    meanPLockedAlphaNoGate, meanPFuse, meanUncFuse, fracLikelyCancer, fracLikelyHealthy, ...
    fracUncertain, coreDecision_tau065_035, nPixelsUsed, status, comments, ...
    'VariableNames', {'coreId','group','subset','meanPBaseline','meanPPrototype','meanPEqualWeight', ...
                      'meanPLockedAlphaNoGate','meanPFuse','meanUncFuse','fracLikelyCancer', ...
                      'fracLikelyHealthy','fracUncertain','coreDecision_tau065_035', ...
                      'nPixelsUsed','status','comments'});

writetable(Tw1, outCsv);
save(outMat, 'Tw1', 'alpha', 'cancerThr', 'healthyThr', 'uncThr', 'tauC', 'tauH');

fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open Wave 1 locked manifest for writing: %s', outTxt);
fprintf(fid, 'ARBITER Wave 1 locked 2-channel rerun\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));
fprintf(fid, 'alpha      = %.4f\n', alpha);
fprintf(fid, 'cancerThr  = %.4f\n', cancerThr);
fprintf(fid, 'healthyThr = %.4f\n', healthyThr);
fprintf(fid, 'uncThr     = %.4f\n', uncThr);
fprintf(fid, 'tauC       = %.4f\n', tauC);
fprintf(fid, 'tauH       = %.4f\n\n', tauH);

fprintf(fid, 'Rows: %d\n', height(Tw1));
fprintf(fid, 'Successful cores: %d\n', sum(Tw1.status == "ok"));
fprintf(fid, 'Failed cores    : %d\n', sum(Tw1.status == "failed"));
fprintf(fid, 'Missing preproc : %d\n\n', sum(Tw1.status == "missing_preproc"));

fprintf(fid, 'Decision counts among successful cores:\n');
ok = Tw1.status == "ok";
if any(ok)
    fprintf(fid, '  cancer-like : %d\n', sum(Tw1.coreDecision_tau065_035(ok) == "cancer-like"));
    fprintf(fid, '  healthy-like: %d\n', sum(Tw1.coreDecision_tau065_035(ok) == "healthy-like"));
    fprintf(fid, '  uncertain   : %d\n', sum(Tw1.coreDecision_tau065_035(ok) == "uncertain"));
end
fclose(fid);

fprintf('\nWave 1 locked rerun complete.\n');
fprintf('  CSV : %s\n', outCsv);
fprintf('  MAT : %s\n', outMat);
fprintf('  TXT : %s\n\n', outTxt);

disp(Tw1(:, {'coreId','status','meanPFuse','meanUncFuse','fracLikelyCancer','fracLikelyHealthy','fracUncertain','coreDecision_tau065_035'}));
