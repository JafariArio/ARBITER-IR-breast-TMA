%% run_27_wave1_summary_and_figures
% Combine the locked 21-core pilot with the 15-core Wave 1 extension and
% export summary tables + exploratory figures.
%
% Inputs:
%   00_data\outputs\reports\ARBITER_core_channel_scores_v1.csv
%   00_data\outputs\reports_wave1\ARBITER_wave1_core_channel_scores_v1.csv
%
% Outputs:
%   00_data\outputs\reports_wave1\ARBITER_combined_36core_results_v1.csv
%   00_data\outputs\reports_wave1\ARBITER_pilot_vs_wave1_summary_v1.csv
%   00_data\outputs\reports_wave1\ARBITER_wave1_summary_manifest_v1.txt
%   00_data\outputs\figures_wave1\Figure_W1_01_combined36_core_summary.png
%   00_data\outputs\figures_wave1\Figure_W1_02_pilot_vs_wave1_decision_counts.png
%   00_data\outputs\figures_wave1\Figure_W1_03_combined_score_uncertainty_plane.png
%   00_data\outputs\figures_wave1\Figure_W1_04_wave1_only_core_bars.png

clear; clc; close all;

%% Bootstrap repository paths
thisFile  = mfilename('fullpath');
runDir    = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fileparts(matlabDir));
cfg = arbiter_config_paths();

%% Paths
pilotCsv       = fullfile(cfg.report_dir, 'ARBITER_core_channel_scores_v1.csv');
wave1Csv       = fullfile(cfg.wave1_report_dir, 'ARBITER_wave1_core_channel_scores_v1.csv');
wave1ReportDir = cfg.wave1_report_dir;
wave1FigDir    = cfg.wave1_figure_dir;

if ~exist(wave1ReportDir, 'dir')
    mkdir(wave1ReportDir);
end
if ~exist(wave1FigDir, 'dir')
    mkdir(wave1FigDir);
end

outCombinedCsv = fullfile(wave1ReportDir, 'ARBITER_combined_36core_results_v1.csv');
outSummaryCsv  = fullfile(wave1ReportDir, 'ARBITER_pilot_vs_wave1_summary_v1.csv');
outTxt         = fullfile(wave1ReportDir, 'ARBITER_wave1_summary_manifest_v1.txt');

fig1Png = fullfile(wave1FigDir, 'Figure_W1_01_combined36_core_summary.png');
fig1Fig = fullfile(wave1FigDir, 'Figure_W1_01_combined36_core_summary.fig');
fig2Png = fullfile(wave1FigDir, 'Figure_W1_02_pilot_vs_wave1_decision_counts.png');
fig2Fig = fullfile(wave1FigDir, 'Figure_W1_02_pilot_vs_wave1_decision_counts.fig');
fig3Png = fullfile(wave1FigDir, 'Figure_W1_03_combined_score_uncertainty_plane.png');
fig3Fig = fullfile(wave1FigDir, 'Figure_W1_03_combined_score_uncertainty_plane.fig');
fig4Png = fullfile(wave1FigDir, 'Figure_W1_04_wave1_only_core_bars.png');
fig4Fig = fullfile(wave1FigDir, 'Figure_W1_04_wave1_only_core_bars.fig');

assert(isfile(pilotCsv), 'Missing pilot table: %s', pilotCsv);
assert(isfile(wave1Csv), 'Missing Wave 1 table: %s. Run run_26_run_locked2ch_on_wave1 first.', wave1Csv);

%% Read pilot table
opts = detectImportOptions(pilotCsv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
Tpilot = readtable(pilotCsv, opts);

numVarsPilot = {'meanPBaseline','meanPPrototype','meanPEqualWeight','meanPLockedAlphaNoGate', ...
                'meanPFuse','meanUncFuse','fracLikelyCancer','fracLikelyHealthy','fracUncertain'};
for i = 1:numel(numVarsPilot)
    if ismember(numVarsPilot{i}, Tpilot.Properties.VariableNames)
        Tpilot.(numVarsPilot{i}) = double(str2double(string(Tpilot.(numVarsPilot{i}))));
    end
end

if ~ismember('coreDecision_tau065_035', Tpilot.Properties.VariableNames)
    if ismember('coreDecision', Tpilot.Properties.VariableNames)
        Tpilot.coreDecision_tau065_035 = string(Tpilot.coreDecision);
    else
        Tpilot.coreDecision_tau065_035 = repmat("", height(Tpilot), 1);
    end
end
if ~ismember('group', Tpilot.Properties.VariableNames)
    Tpilot.group = repmat("", height(Tpilot), 1);
end
if ~ismember('subset', Tpilot.Properties.VariableNames)
    Tpilot.subset = repmat("", height(Tpilot), 1);
end

Tpilot.coreId = upper(strtrim(string(Tpilot.coreId)));
Tpilot.group = strtrim(string(Tpilot.group));
Tpilot.subset = strtrim(string(Tpilot.subset));
Tpilot.coreDecision_tau065_035 = lower(strtrim(string(Tpilot.coreDecision_tau065_035)));
Tpilot.cohort = repmat("Pilot21", height(Tpilot), 1);
Tpilot.status = repmat("ok", height(Tpilot), 1);

%% Read wave1 table
opts = detectImportOptions(wave1Csv, 'VariableNamingRule', 'preserve');
for ii = 1:numel(opts.VariableTypes)
    opts.VariableTypes{ii} = 'string';
end
Tw1 = readtable(wave1Csv, opts);

numVarsW1 = {'meanPBaseline','meanPPrototype','meanPEqualWeight','meanPLockedAlphaNoGate', ...
             'meanPFuse','meanUncFuse','fracLikelyCancer','fracLikelyHealthy','fracUncertain','nPixelsUsed'};
for i = 1:numel(numVarsW1)
    if ismember(numVarsW1{i}, Tw1.Properties.VariableNames)
        Tw1.(numVarsW1{i}) = double(str2double(string(Tw1.(numVarsW1{i}))));
    end
end

Tw1.coreId = upper(strtrim(string(Tw1.coreId)));
Tw1.group = strtrim(string(Tw1.group));
Tw1.subset = strtrim(string(Tw1.subset));
Tw1.coreDecision_tau065_035 = lower(strtrim(string(Tw1.coreDecision_tau065_035)));
Tw1.status = lower(strtrim(string(Tw1.status)));
Tw1.cohort = repmat("Wave1_15", height(Tw1), 1);

%% Harmonize columns
keepVars = {'coreId','cohort','group','subset','meanPBaseline','meanPPrototype','meanPEqualWeight', ...
            'meanPLockedAlphaNoGate','meanPFuse','meanUncFuse','fracLikelyCancer','fracLikelyHealthy', ...
            'fracUncertain','coreDecision_tau065_035','status'};
for i = 1:numel(keepVars)
    if ~ismember(keepVars{i}, Tpilot.Properties.VariableNames)
        Tpilot.(keepVars{i}) = repmat("", height(Tpilot), 1);
    end
    if ~ismember(keepVars{i}, Tw1.Properties.VariableNames)
        Tw1.(keepVars{i}) = repmat("", height(Tw1), 1);
    end
end
Tpilot = Tpilot(:, keepVars);
Tw1    = Tw1(:, keepVars);

Tall = [Tpilot; Tw1];
Tall = Tall(~ismissing(Tall.coreId) & strlength(Tall.coreId) > 0, :);

sortCohort = zeros(height(Tall),1);
sortCohort(Tall.cohort == "Wave1_15") = 1;
sortScore = -Tall.meanPFuse;
[~, idx] = sortrows([sortCohort sortScore], [1 2]);
Tall = Tall(idx, :);

%% Summary table
cohort = ["Pilot21";"Wave1_15";"Combined36"];
nCores = [sum(Tall.cohort=="Pilot21"); sum(Tall.cohort=="Wave1_15"); height(Tall)];

nCancerLike = [sum(Tall.cohort=="Pilot21" & Tall.coreDecision_tau065_035=="cancer-like"); ...
               sum(Tall.cohort=="Wave1_15" & Tall.coreDecision_tau065_035=="cancer-like"); ...
               sum(Tall.coreDecision_tau065_035=="cancer-like")];
nHealthyLike = [sum(Tall.cohort=="Pilot21" & Tall.coreDecision_tau065_035=="healthy-like"); ...
                sum(Tall.cohort=="Wave1_15" & Tall.coreDecision_tau065_035=="healthy-like"); ...
                sum(Tall.coreDecision_tau065_035=="healthy-like")];
nUncertain = [sum(Tall.cohort=="Pilot21" & Tall.coreDecision_tau065_035=="uncertain"); ...
              sum(Tall.cohort=="Wave1_15" & Tall.coreDecision_tau065_035=="uncertain"); ...
              sum(Tall.coreDecision_tau065_035=="uncertain")];

meanPFuse = [mean(Tall.meanPFuse(Tall.cohort=="Pilot21"), 'omitnan'); ...
             mean(Tall.meanPFuse(Tall.cohort=="Wave1_15"), 'omitnan'); ...
             mean(Tall.meanPFuse, 'omitnan')];
meanUncFuse = [mean(Tall.meanUncFuse(Tall.cohort=="Pilot21"), 'omitnan'); ...
               mean(Tall.meanUncFuse(Tall.cohort=="Wave1_15"), 'omitnan'); ...
               mean(Tall.meanUncFuse, 'omitnan')];

Tsum = table(cohort, nCores, nCancerLike, nHealthyLike, nUncertain, meanPFuse, meanUncFuse);

writetable(Tall, outCombinedCsv);
writetable(Tsum, outSummaryCsv);

%% Figure W1-01
f1 = figure('Color','w','Position',[80 80 1350 520]);
x = 1:height(Tall);
b = bar(x, Tall.meanPFuse, 'FaceColor', 'flat');
for i = 1:height(Tall)
    if Tall.coreDecision_tau065_035(i) == "cancer-like"
        b.CData(i,:) = [0.85 0.20 0.20];
    elseif Tall.coreDecision_tau065_035(i) == "healthy-like"
        b.CData(i,:) = [0.20 0.65 0.25];
    else
        b.CData(i,:) = [0.55 0.55 0.55];
    end
end
hold on;
yline(0.60, '--r', 'cancerThr', 'LineWidth', 1.2);
yline(0.40, '--g', 'healthyThr', 'LineWidth', 1.2);
for i = 1:height(Tall)
    if Tall.cohort(i) == "Pilot21"
        plot(i, min(1.02, Tall.meanPFuse(i)+0.03), 'ko', 'MarkerFaceColor','w', 'MarkerSize',4);
    else
        plot(i, min(1.02, Tall.meanPFuse(i)+0.03), 'ks', 'MarkerFaceColor','k', 'MarkerSize',4);
    end
end
set(gca, 'XTick', x, 'XTickLabel', cellstr(Tall.coreId), 'XTickLabelRotation', 45);
ylabel('Mean fused score');
title('Wave 1 combined 36-core summary');
legend({'meanPFuse','cancerThr','healthyThr'}, 'Location','southwest');
grid on; box on;
ylim([0 1.05]);
savefig(f1, fig1Fig);
exportgraphics(f1, fig1Png, 'Resolution', 300);

%% Figure W1-02
f2 = figure('Color','w','Position',[100 100 920 520]);
X = [nCancerLike(1:2) nHealthyLike(1:2) nUncertain(1:2)];
bar(X, 'stacked');
set(gca, 'XTick', 1:2, 'XTickLabel', {'Pilot21','Wave1_15'});
ylabel('Number of cores');
title('Pilot vs Wave 1 decision counts');
legend({'cancer-like','healthy-like','uncertain'}, 'Location','northeast');
grid on; box on;
savefig(f2, fig2Fig);
exportgraphics(f2, fig2Png, 'Resolution', 300);

%% Figure W1-03
f3 = figure('Color','w','Position',[120 120 900 640]);
hold on;
ok = Tall.status == "ok";
idx = ok & Tall.coreDecision_tau065_035=="cancer-like";
scatter(Tall.meanPFuse(idx), Tall.meanUncFuse(idx), 70, [0.85 0.20 0.20], 'o', 'filled');
idx = ok & Tall.coreDecision_tau065_035=="healthy-like";
scatter(Tall.meanPFuse(idx), Tall.meanUncFuse(idx), 70, [0.20 0.65 0.25], 'o', 'filled');
idx = ok & Tall.coreDecision_tau065_035=="uncertain";
scatter(Tall.meanPFuse(idx), Tall.meanUncFuse(idx), 70, [0.50 0.50 0.50], 'o', 'filled');
idxW1 = ok & Tall.cohort=="Wave1_15";
plot(Tall.meanPFuse(idxW1), Tall.meanUncFuse(idxW1), 'ks', 'MarkerSize', 9, 'LineWidth', 1.2);
for i = 1:height(Tall)
    if ok(i)
        text(Tall.meanPFuse(i)+0.008, Tall.meanUncFuse(i)+0.004, Tall.coreId(i), 'FontSize', 8);
    end
end
xline(0.60, '--r', 'cancerThr', 'LineWidth', 1.2);
xline(0.40, '--g', 'healthyThr', 'LineWidth', 1.2);
yline(0.45, '--k', 'uncThr', 'LineWidth', 1.2);
xlabel('Mean fused score');
ylabel('Mean fused uncertainty');
title('Combined score-uncertainty plane (Wave 1 highlighted)');
grid on; box on;
savefig(f3, fig3Fig);
exportgraphics(f3, fig3Png, 'Resolution', 300);

%% Figure W1-04
f4 = figure('Color','w','Position',[150 150 1200 520]);
Tw1ok = Tw1(Tw1.status=="ok", :);
[~, ord] = sort(Tw1ok.meanPFuse, 'descend');
Tw1ok = Tw1ok(ord, :);
x = 1:height(Tw1ok);
b = bar(x, Tw1ok.meanPFuse, 'FaceColor', 'flat');
for i = 1:height(Tw1ok)
    if Tw1ok.coreDecision_tau065_035(i) == "cancer-like"
        b.CData(i,:) = [0.85 0.20 0.20];
    elseif Tw1ok.coreDecision_tau065_035(i) == "healthy-like"
        b.CData(i,:) = [0.20 0.65 0.25];
    else
        b.CData(i,:) = [0.55 0.55 0.55];
    end
end
hold on;
yline(0.60, '--r', 'cancerThr', 'LineWidth', 1.2);
yline(0.40, '--g', 'healthyThr', 'LineWidth', 1.2);
set(gca, 'XTick', x, 'XTickLabel', cellstr(Tw1ok.coreId), 'XTickLabelRotation', 45);
ylabel('Mean fused score');
title('Wave 1 only: locked 2-channel rerun');
grid on; box on;
ylim([0 1.05]);
savefig(f4, fig4Fig);
exportgraphics(f4, fig4Png, 'Resolution', 300);

%% Text summary
fid = fopen(outTxt, 'w');
assert(fid >= 0, 'Could not open Wave 1 summary manifest for writing: %s', outTxt);
fprintf(fid, 'ARBITER Wave 1 summary manifest\n');
fprintf(fid, 'Created: %s\n\n', datestr(now, 30));
fprintf(fid, 'Pilot rows   : %d\n', sum(Tall.cohort=="Pilot21"));
fprintf(fid, 'Wave 1 rows  : %d\n', sum(Tall.cohort=="Wave1_15"));
fprintf(fid, 'Combined rows: %d\n\n', height(Tall));

fprintf(fid, 'Decision counts\n');
for i = 1:height(Tsum)
    fprintf(fid, '  %-10s | n=%d | cancer-like=%d | healthy-like=%d | uncertain=%d | meanPFuse=%.4f | meanUnc=%.4f\n', ...
        Tsum.cohort(i), Tsum.nCores(i), Tsum.nCancerLike(i), Tsum.nHealthyLike(i), Tsum.nUncertain(i), ...
        Tsum.meanPFuse(i), Tsum.meanUncFuse(i));
end

fprintf(fid, '\nOutputs:\n');
fprintf(fid, '  %s\n', outCombinedCsv);
fprintf(fid, '  %s\n', outSummaryCsv);
fprintf(fid, '  %s\n', fig1Png);
fprintf(fid, '  %s\n', fig2Png);
fprintf(fid, '  %s\n', fig3Png);
fprintf(fid, '  %s\n', fig4Png);
fclose(fid);

fprintf('\nWave 1 summary complete.\n');
fprintf('  Combined CSV: %s\n', outCombinedCsv);
fprintf('  Summary CSV : %s\n', outSummaryCsv);
fprintf('  Summary TXT : %s\n', outTxt);
