function preFile = arbiter_find_preproc_file_v1(rootDir, coreId)
% Find a unique *_preproc_v0*.mat file for the given core ID.

patterns = {['*' coreId '*preproc_v0*.mat'], ['*' coreId '*preproc*.mat']};
hits = [];

for i = 1:numel(patterns)
    d = dir(fullfile(rootDir, '**', patterns{i}));
    if ~isempty(d)
        hits = d;
        break;
    end
end

assert(~isempty(hits), 'Could not find preprocessed MAT file for core %s under %s', coreId, rootDir);

% Prefer shortest full path if multiple hits
fulls = strings(numel(hits),1);
lens = zeros(numel(hits),1);
for i = 1:numel(hits)
    fulls(i) = string(fullfile(hits(i).folder, hits(i).name));
    lens(i) = strlength(fulls(i));
end
[~, idx] = min(lens);
preFile = char(fulls(idx));
end
