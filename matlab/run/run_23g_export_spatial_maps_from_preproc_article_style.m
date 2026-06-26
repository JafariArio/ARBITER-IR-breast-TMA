%% run_23g_export_spatial_maps_from_preproc_article_style
% Export representative spatial ARBITER maps using exact preprocessed core
% indexing, with article-style typography:
%   - Arial everywhere
%   - larger titles, tick labels, and colorbar labels
%   - 600 dpi PNG + TIFF export
%
% Main manuscript cores:
%   E16, M15, M1, M4
%
% SI cores:
%   L13, M16, M7, M10

clear; clc; close all;

%% Bootstrap repository paths
thisFile = mfilename('fullpath');
runDir   = fileparts(thisFile);
matlabDir = fileparts(runDir);
addpath(matlabDir);
addpath(fullfile(matlabDir, 'utils'));
cfg = arbiter_config_paths();


%% Global article-style defaults
set(groot, 'defaultAxesFontName', 'Arial');
set(groot, 'defaultTextFontName', 'Arial');
set(groot, 'defaultColorbarFontName', 'Arial');
set(groot, 'defaultAxesFontSize', 16);
set(groot, 'defaultTextFontSize', 16);
set(groot, 'defaultColorbarFontSize', 16);
set(groot, 'defaultAxesLineWidth', 1.2);
set(groot, 'defaultLineLineWidth', 1.5);
set(groot, 'defaultFigureColor', 'w');

%% Paths
rootDir    = cfg.project_root;
reportDir  = fullfile(rootDir, '00_data', 'outputs', 'reports');
outMainDir = fullfile(rootDir, '00_data', 'outputs', 'figures', 'spatial_main');
outSIDir   = fullfile(rootDir, '00_data', 'outputs', 'figures', 'spatial_SI');

if ~exist(outMainDir, 'dir'); mkdir(outMainDir); end
if ~exist(outSIDir,   'dir'); mkdir(outSIDir);   end

precompMat = fullfile(reportDir, 'fusion_precompute_v1.mat');
assert(isfile(precompMat), 'Missing file: %s', precompMat);

%% Core sets
mainCores = {'E16','M15','M1','M4'};
siCores   = {'L13','M16','M7','M10'};

%% Locked settings
alpha      = 0.90;
cancerThr  = 0.60;
healthyThr = 0.40;
uncThr     = 0.45;

%% Typography sizes
titleFS    = 24;
cbFS       = 18;
tickFS     = 16;

%% Load precomputed channels
S = load(precompMat);
assert(isfield(S, 'precomp'), 'fusion_precompute_v1.mat does not contain variable "precomp".');
precomp = S.precomp;

%% Export loop
allSets = {mainCores, siCores};
allOuts = {outMainDir, outSIDir};
setNames = {'MAIN','SI'};

for s = 1:2
    coreList = allSets{s};
    outDir   = allOuts{s};

    fprintf('\n=== Exporting %s article-style spatial maps from preproc ===\n', setNames{s});

    for i = 1:numel(coreList)
        coreId = coreList{i};
        fprintf('\nCore: %s\n', coreId);

        assert(isfield(precomp, coreId), 'precomp does not contain core "%s".', coreId);
        entry = precomp.(coreId);

        assert(isfield(entry, 'pBase') && isnumeric(entry.pBase), ...
            'Core %s does not contain numeric pBase.', coreId);
        assert(isfield(entry, 'pProto') && isnumeric(entry.pProto), ...
            'Core %s does not contain numeric pProto.', coreId);

        pBase  = double(entry.pBase(:));
        pProto = double(entry.pProto(:));
        assert(numel(pBase) == numel(pProto), 'Core %s: pBase/pProto length mismatch.', coreId);

        preFile = arbiter_find_preproc_file_v1(rootDir, coreId);
        fprintf('  using preproc file: %s\n', preFile);

        P = load(preFile);
        assert(isfield(P, 'core'), 'Preproc file does not contain variable "core": %s', preFile);
        core = P.core;

        layout = arbiter_layout_from_preproc_core_v1(core, numel(pBase));

        % Map vectors into 2D core grid using exact preproc indexing
        pBaseMap  = nan(layout.nRows, layout.nCols);
        pProtoMap = nan(layout.nRows, layout.nCols);

        if layout.mode == "mask_linear"
            pBaseMap(layout.mask)  = pBase;
            pProtoMap(layout.mask) = pProto;
        elseif layout.mode == "pixel_rc"
            lin = sub2ind([layout.nRows, layout.nCols], layout.pixelRC(:,1), layout.pixelRC(:,2));
            pBaseMap(lin)  = pBase;
            pProtoMap(lin) = pProto;
        else
            error('Unknown layout mode for core %s.', coreId);
        end

        % Locked fused map
        pFuseMap = alpha .* pBaseMap + (1 - alpha) .* pProtoMap;

        % Reconstructed uncertainty map
        uncFuseMap = 0.5 .* (1 - abs(2 .* pFuseMap - 1)) + 0.5 .* abs(pBaseMap - pProtoMap);
        uncFuseMap = max(0, min(1, uncFuseMap));
        uncFuseMap(~layout.mask) = nan;

        % Final arbitration
        finalMap = nan(layout.nRows, layout.nCols);
        finalMap(layout.mask) = 0;
        finalMap(layout.mask & pFuseMap >= cancerThr  & uncFuseMap <= uncThr) = 1;
        finalMap(layout.mask & pFuseMap <= healthyThr & uncFuseMap <= uncThr) = -1;

        %% Context
        if ~isempty(layout.context)
            fig = figure('Color','w','Visible','off','Position',[100 100 900 780]);
            imagesc(layout.context);
            axis image off;
            title(sprintf('%s | context', coreId), ...
                'FontWeight', 'bold', 'FontName', 'Arial', 'FontSize', titleFS, 'Interpreter', 'none');
            colormap(gray);

            exportgraphics(fig, fullfile(outDir, [coreId '_context.png']), 'Resolution', 600);
            exportgraphics(fig, fullfile(outDir, [coreId '_context.tif']), 'Resolution', 600);
            close(fig);
        end

        %% Fused pCancer
        fig = figure('Color','w','Visible','off','Position',[100 100 900 780]);
        imagesc(pFuseMap, 'AlphaData', ~isnan(pFuseMap));
        axis image off;
        title(sprintf('%s | fused pCancer', coreId), ...
            'FontWeight', 'bold', 'FontName', 'Arial', 'FontSize', titleFS, 'Interpreter', 'none');
        colormap(parula);

        cb = colorbar;
        cb.FontName = 'Arial';
        cb.FontSize = tickFS;
        cb.LineWidth = 1.1;
        cb.Label.String = 'Fused pCancer';
        cb.Label.FontName = 'Arial';
        cb.Label.FontWeight = 'bold';
        cb.Label.FontSize = cbFS;

        exportgraphics(fig, fullfile(outDir, [coreId '_fused_pCancer.png']), 'Resolution', 600);
        exportgraphics(fig, fullfile(outDir, [coreId '_fused_pCancer.tif']), 'Resolution', 600);
        close(fig);

        %% Fused uncertainty
        fig = figure('Color','w','Visible','off','Position',[100 100 900 780]);
        imagesc(uncFuseMap, 'AlphaData', ~isnan(uncFuseMap));
        axis image off;
        title(sprintf('%s | fused uncertainty', coreId), ...
            'FontWeight', 'bold', 'FontName', 'Arial', 'FontSize', titleFS, 'Interpreter', 'none');
        colormap(parula);

        cb = colorbar;
        cb.FontName = 'Arial';
        cb.FontSize = tickFS;
        cb.LineWidth = 1.1;
        cb.Label.String = 'Fused uncertainty';
        cb.Label.FontName = 'Arial';
        cb.Label.FontWeight = 'bold';
        cb.Label.FontSize = cbFS;

        exportgraphics(fig, fullfile(outDir, [coreId '_fused_uncertainty.png']), 'Resolution', 600);
        exportgraphics(fig, fullfile(outDir, [coreId '_fused_uncertainty.tif']), 'Resolution', 600);
        close(fig);

        %% Final arbitration
        fig = figure('Color','w','Visible','off','Position',[100 100 900 780]);
        imagesc(finalMap, 'AlphaData', ~isnan(finalMap));
        axis image off;
        title(sprintf('%s | final arbitration', coreId), ...
            'FontWeight', 'bold', 'FontName', 'Arial', 'FontSize', titleFS, 'Interpreter', 'none');
        colormap(parula(256));
        caxis([-1 1]);

        cb = colorbar;
        cb.FontName = 'Arial';
        cb.FontSize = tickFS;
        cb.LineWidth = 1.1;
        cb.Ticks = [-1 0 1];
        cb.TickLabels = {'healthy-like','uncertain','cancer-like'};
        cb.Label.String = 'Final decision';
        cb.Label.FontName = 'Arial';
        cb.Label.FontWeight = 'bold';
        cb.Label.FontSize = cbFS;

        exportgraphics(fig, fullfile(outDir, [coreId '_final_arbitration.png']), 'Resolution', 600);
        exportgraphics(fig, fullfile(outDir, [coreId '_final_arbitration.tif']), 'Resolution', 600);
        close(fig);

        fprintf('  layout mode: %s\n', layout.mode);
        fprintf('  selected pixel count: %d\n', nnz(layout.mask));
        fprintf('  wrote article-style maps to: %s\n', outDir);
    end
end

fprintf('\nDone.\n');
fprintf('Main figure folder:\n  %s\n', outMainDir);
fprintf('SI figure folder:\n  %s\n', outSIDir);
