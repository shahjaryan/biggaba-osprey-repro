% qc_plot.m
%
% Visual QC for a fitted Osprey container, without the GUI Layout Toolbox.
%
% osp_plotAllPDF routes through osp_plotModule -> uix.Panel and therefore needs
% the GUI Layout Toolbox. osp_plotFit does NOT - it draws with plain MATLAB
% graphics. So we call it directly and save PNGs.
%
% Usage:
%   qc_plot                          % uses results/smoke_test/MRSCont_smoke.mat
%   qc_plot(pathToMat)
%   qc_plot(pathToMat, kk)
%
% LOOK AT THE OUTPUT. The number is not the check; the fit is. Specifically:
%   - Does the model (red) track the data (black) across 2.8-3.2 ppm?
%   - Is the residual flat and small, or does it have structure at the GABA peak?
%   - Is the baseline smooth, or is it absorbing signal that should be GABA?
%   - Any lipid contamination below ~2 ppm bleeding into the fit range?

function qc_plot(matPath, kk)

if nargin < 1 || isempty(matPath)
    repoDir = fileparts(fileparts(mfilename('fullpath')));
    matPath = fullfile(repoDir, 'results', 'smoke_test', 'MRSCont_smoke.mat');
end
if nargin < 2 || isempty(kk); kk = 1; end

ospreyDir = fullfile(getenv('USERPROFILE'), 'Documents', 'osprey');
addpath(genpath(ospreyDir));

assert(isfile(matPath), 'No container at %s', matPath);
fprintf('Loading %s ...\n', matPath);
S = load(matPath);
MRSCont = S.MRSCont;

outDir = fullfile(fileparts(matPath), 'qc');
if ~isfolder(outDir); mkdir(outDir); end

% MEGA subspectra indexing (see osp_plotFit header):
%   VoxelIndex = [experiment, subspectrum, basisset]
%   subspectrum 1 = off, 2 = diff1
targets = { 'diff1 (edited - this is where GABA lives)', [1 2 1], 'diff1'; ...
            'off   (unedited - Cr reference)',           [1 1 1], 'off'   };

for t = 1:size(targets,1)
    label = targets{t,1};
    vox   = targets{t,2};
    tag   = targets{t,3};

    fprintf('\nPlotting %s ... ', label);
    try
        fh = osp_plotFit(MRSCont, kk, 'metab', vox, 0, 1, ...
                         'Frequency (ppm)', '', sprintf('%s - dataset %d', tag, kk));
        set(fh, 'Visible', 'on');
        png = fullfile(outDir, sprintf('fit_%s_kk%d.png', tag, kk));
        exportgraphics(fh, png, 'Resolution', 150);
        fprintf('saved %s\n', png);
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        fprintf('  (osp_plotFit argument order varies between Osprey versions;\n');
        fprintf('   try: osp_plotFit(MRSCont, %d, ''metab'', [1 2 1]) by hand)\n', kk);
    end
end

%% Quality metrics alongside the published comparators
fprintf('\n================ QUALITY METRICS ================\n');
try
    QM = MRSCont.QM;
    f = fieldnames(QM);
    for i = 1:numel(f)
        v = QM.(f{i});
        if isstruct(v)
            sub = fieldnames(v);
            for j = 1:numel(sub)
                val = v.(sub{j});
                if isnumeric(val) && ~isempty(val)
                    fprintf('  %-28s %s\n', [f{i} '.' sub{j}], mat2str(val(:).', 5));
                end
            end
        elseif isnumeric(v) && ~isempty(v)
            fprintf('  %-28s %s\n', f{i}, mat2str(v(:).', 5));
        end
    end
catch
    fprintf('  (could not read MRSCont.QM)\n');
end

fprintf('\nPublished comparators (Mikkelsen 2017, Gannet):\n');
fprintf('  NAA linewidth   8.10 Hz     NAA SNR   447\n');
fprintf('  GABA SNR          25        GABA+ fit error  5-6%%\n');
fprintf('  CAUTION: SNR and fit error are NOT defined identically across MRS\n');
fprintf('  packages. Verify each definition in source before recording a\n');
fprintf('  discrepancy - a definitional difference is not a result.\n');
fprintf('=================================================\n\n');

end
