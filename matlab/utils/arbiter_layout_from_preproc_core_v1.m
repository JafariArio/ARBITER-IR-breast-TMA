function layout = arbiter_layout_from_preproc_core_v1(core, expectedCount)
% Build exact spatial layout from a preprocessed core struct.
%
% Priority:
%   1) core.pixelRC if it has expectedCount rows
%   2) core.tissueMask if nnz matches expectedCount
%   3) core.tissueMaskVec reshaped to size(core.tissueMask) if it matches
%
% Returns:
%   layout.mask
%   layout.mode = "pixel_rc" or "mask_linear"
%   layout.pixelRC (if pixel_rc)
%   layout.context

layout = struct();
layout.mask = [];
layout.mode = "";
layout.pixelRC = [];
layout.context = [];

assert(isstruct(core) && isscalar(core), 'Input "core" must be a scalar struct.');

% Context preference
if isfield(core, 'amideMap') && isnumeric(core.amideMap) && ismatrix(core.amideMap) && ~isscalar(core.amideMap)
    layout.context = double(core.amideMap);
elseif isfield(core, 'cubePre') && isnumeric(core.cubePre) && ndims(core.cubePre) == 3
    try
        layout.context = mean(double(core.cubePre), 3, 'omitnan');
    catch
        layout.context = mean(double(core.cubePre), 3);
    end
elseif isfield(core, 'cubeRaw') && isnumeric(core.cubeRaw) && ndims(core.cubeRaw) == 3
    try
        layout.context = mean(double(core.cubeRaw), 3, 'omitnan');
    catch
        layout.context = mean(double(core.cubeRaw), 3);
    end
end

% 1) pixelRC exact mapping
if isfield(core, 'pixelRC') && isnumeric(core.pixelRC) && size(core.pixelRC,2) >= 2
    rc = double(core.pixelRC(:,1:2));
    if size(rc,1) == expectedCount
        % infer image size
        if isfield(core, 'tissueMask') && ismatrix(core.tissueMask) && ~isscalar(core.tissueMask)
            nRows = size(core.tissueMask,1);
            nCols = size(core.tissueMask,2);
        elseif ~isempty(layout.context)
            nRows = size(layout.context,1);
            nCols = size(layout.context,2);
        else
            nRows = max(rc(:,1));
            nCols = max(rc(:,2));
        end

        mask = false(nRows, nCols);
        good = rc(:,1) >= 1 & rc(:,1) <= nRows & rc(:,2) >= 1 & rc(:,2) <= nCols;
        rc = rc(good,:);
        assert(size(rc,1) == expectedCount, 'pixelRC lost rows after bounds check.');

        lin = sub2ind([nRows, nCols], rc(:,1), rc(:,2));
        mask(lin) = true;

        layout.mask = mask;
        layout.mode = "pixel_rc";
        layout.pixelRC = rc;
        layout.nRows = nRows;
        layout.nCols = nCols;
        layout.nMasked = nnz(mask);
        return;
    end
end

% 2) tissueMask exact linear mapping
if isfield(core, 'tissueMask') && ismatrix(core.tissueMask) && ~isscalar(core.tissueMask)
    tm = core.tissueMask;
    if islogical(tm)
        mask = tm;
    else
        u = unique(tm(:));
        if numel(u) <= 3 && all(ismember(u(~isnan(u)), [0 1]))
            mask = logical(tm);
        else
            mask = [];
        end
    end

    if ~isempty(mask) && nnz(mask) == expectedCount
        layout.mask = mask;
        layout.mode = "mask_linear";
        layout.pixelRC = [];
        layout.nRows = size(mask,1);
        layout.nCols = size(mask,2);
        layout.nMasked = nnz(mask);
        return;
    end

    % 3) tissueMaskVec reshaped to tissueMask size
    if isfield(core, 'tissueMaskVec') && isnumeric(core.tissueMaskVec)
        tv = double(core.tissueMaskVec(:));
        if numel(tv) == numel(mask)
            tv2 = reshape(tv, size(mask));
            u = unique(tv2(:));
            if numel(u) <= 3 && all(ismember(u(~isnan(u)), [0 1]))
                mask2 = logical(tv2);
                if nnz(mask2) == expectedCount
                    layout.mask = mask2;
                    layout.mode = "mask_linear";
                    layout.pixelRC = [];
                    layout.nRows = size(mask2,1);
                    layout.nCols = size(mask2,2);
                    layout.nMasked = nnz(mask2);
                    return;
                end
            end
        elseif numel(tv) == expectedCount
            % Sometimes tissueMaskVec may be just the selected-pixel flag aligned to pixelRC
            % but without 2D image layout it cannot be reshaped safely.
        end
    end
end

error('Could not construct an exact preproc layout with expectedCount=%d for core %s.', ...
    expectedCount, local_get_core_name(core));

end

function name = local_get_core_name(core)
if isfield(core, 'name')
    try
        name = char(string(core.name));
    catch
        name = '<unknown>';
    end
else
    name = '<unknown>';
end
end
