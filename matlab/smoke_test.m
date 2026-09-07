% smoke_test.m
%
% GATE 1. Run Osprey end to end on a SINGLE Big GABA dataset.
%
% Zero configuration: point it at nothing, it finds the first dataset in ../data
% and processes exactly one. Nothing downstream in this project matters until
% this produces a plausible number with a fit you have looked at.
%
% A plausible GABA+/Cr is roughly 0.08-0.15. Published whole-cohort mean was
% 0.116 +/- 0.014 (Gannet). A number in range with a visibly bad fit is WORSE
% than no number - it will quietly poison everything downstream.
%
% Expect this to fail the first time. How it fails is the useful information.

function smoke_test()

ospreyDir = fullfile(getenv('USERPROFILE'), 'Documents', 'osprey');
repoDir   = fileparts(fileparts(mfilename('fullpath')));
dataDir   = fullfile(repoDir, 'data');
outDir    = fullfile(repoDir, 'results', 'smoke_test');

fprintf('\n============== SMOKE TEST ==============\n\n');

%% 1. Environment -------------------------------------------------------------

assert(isfolder(ospreyDir), 'Osprey not found at %s', ospreyDir);
addpath(genpath(ospreyDir));
addpath(fileparts(mfilename('fullpath')));

% SPM12: top level ONLY. Adding subfolders breaks SPM, and Osprey's own docs
% say so. Osprey does not use SPM for this pipeline (no coregistration, no
% segmentation) but osp_Toolbox_Check lists SPM12 under neededGlobal for
% OspreyProcess and OspreyFit, so it must be findable on the path regardless.
spmDir = fullfile(getenv('USERPROFILE'), 'Documents', 'spm12');
if isfolder(spmDir) && isempty(which('spm.m'))
    addpath(spmDir);
end
if isempty(which('spm.m'))
    warning(['SPM12 not on the path. Osprey''s module check will complain. ' ...
             'Expected at: %s'], spmDir);
end

for fn = {'fmincon','fitlm'}
    assert(exist(fn{1},'file') || exist(fn{1},'builtin'), ...
        'Missing %s - required toolbox not installed. Run check_environment.', fn{1});
end

% Start from a clean output directory every run. Osprey otherwise finds an
% existing container and blocks on an interactive overwrite prompt, which makes
% iterating painful and would hang an unattended batch entirely.
%
% Osprey opens LogFile.txt and leaves the handle open, so on Windows the
% directory cannot be removed until those handles are released. Close them
% first; if removal still fails, fall back to a timestamped directory rather
% than aborting - never let housekeeping block the actual work.
diary off;
fclose('all');

if isfolder(outDir)
    [ok, msg] = rmdir(outDir, 's');
    if ~ok
        stamp  = datestr(now, 'yyyymmdd_HHMMSS');
        outDir = [outDir '_' stamp];
        fprintf(['Could not clear the previous output directory (%s).\n' ...
                 'Using a fresh one instead:\n  %s\n\n'], strtrim(msg), outDir);
    end
end
mkdir(outDir);

%% 2. Find one dataset --------------------------------------------------------
%
% Vendor is inferred from the site folder name (G/P/S), which is how Big GABA
% codes it. Extensions per vendor:
%     GE      .7     P-file, water reference embedded
%     Philips .sdat  paired .spar, separate water reference file
%     Siemens .dat   TWIX, separate water reference file

assert(isfolder(dataDir), 'No data directory at %s', dataDir);

sites = dir(dataDir);
sites = sites([sites.isdir] & ~ismember({sites.name}, {'.','..'}));
assert(~isempty(sites), 'data/ is empty. Download one MEGA-PRESS site first.');

extMap = containers.Map({'G','P','S'}, {'.7','.sdat','.dat'});

% ---------------------------------------------------------------------------
% CRITICAL: Big GABA ships TWO acquisitions per subject.
%   *_68.dat  TE 68 ms -> GABA+ (co-edited macromolecules present)  <- WANTED
%   *_80.dat  TE 80 ms -> MM-suppressed GABA                        <- NOT wanted
% Plus a water reference for each: *_68_H2O.dat, *_80_H2O.dat
%
% These are DIFFERENT MEASURES with different published values. Mixing them
% would silently corrupt the whole reproduction, and the numbers would still
% look superficially plausible. Filter explicitly on TE 68.
% ---------------------------------------------------------------------------
TE_TARGET  = '68';
isWaterRef = @(n) contains(lower(n), {'h2o','ref','water','_w.'});

chosen = [];
for k = 1:numel(sites)
    v = upper(sites(k).name(1));
    if ~isKey(extMap, v); continue; end

    hits = dir(fullfile(dataDir, sites(k).name, '**', ['*' extMap(v)]));
    if isempty(hits); continue; end

    names = {hits.name};
    isRef = cellfun(isWaterRef, names);

    % Metabolite files at the target TE only.
    isTE  = contains(names, ['_' TE_TARGET '.']) | contains(names, ['_' TE_TARGET '_']);
    metab = hits(~isRef & isTE);

    if isempty(metab)
        % Fall back so a vendor with different naming still smoke-tests,
        % but say so loudly - this needs checking before any batch run.
        metab = hits(~isRef);
        if ~isempty(metab)
            fprintf(['WARNING: no filename matched TE %s for site %s.\n' ...
                     '         Falling back to the first non-reference file.\n' ...
                     '         VERIFY the TE before trusting any result.\n'], ...
                     TE_TARGET, sites(k).name);
        end
    end
    if isempty(metab); continue; end

    chosen = struct('site', sites(k).name, 'vendor', v, ...
                    'metab', metab(1), 'allRefs', hits(isRef));
    break;
end

vendorName = struct('G','GE','P','Philips','S','Siemens');
fprintf('Site        : %s (%s)\n', chosen.site, vendorName.(chosen.vendor));
fprintf('Metabolite  : %s\n', chosen.metab.name);

metabFile = fullfile(chosen.metab.folder, chosen.metab.name);

% Pair the water reference. GE P-files embed their own.
% Siemens/Philips convention here: <stem>_H2O.<ext> alongside <stem>.<ext>
files_ref = {};
if chosen.vendor ~= 'G'
    [~, stem, ext] = fileparts(chosen.metab.name);
    wanted = [stem '_H2O' ext];
    idx = find(strcmpi({chosen.allRefs.name}, wanted), 1);
    if isempty(idx) && ~isempty(chosen.allRefs)
        idx = find(contains(lower({chosen.allRefs.name}), lower(stem)), 1);
    end
    if ~isempty(idx)
        files_ref = {fullfile(chosen.allRefs(idx).folder, chosen.allRefs(idx).name)};
        fprintf('Reference   : %s\n', chosen.allRefs(idx).name);
    else
        fprintf('Reference   : NONE FOUND - ratio-only quantification\n');
    end
else
    fprintf('Reference   : (embedded in GE P-file)\n');
end

fprintf('\n');

%% 3. Job ---------------------------------------------------------------------
%
% Deliberately minimal. No structural image, no OspreyCoreg, no OspreySeg -
% GABA+/Cr is a creatine ratio and needs none of it.

opts = struct();
opts.SpecReg               = 'RobSpecReg';
opts.SubSpecAlignment.mets = 'L2Norm';
opts.fit.method            = 'Osprey';
opts.fit.style             = 'Separate';  % Osprey forces this for MEGA:
                                          % "concatenated modeling is still
                                          % under development". Forced deviation
                                          % - logged in docs/discrepancy-log.md
opts.fit.includeMetabs     = {'default'};
opts.fit.coMM3             = '3to2MM';   % highest-leverage parameter in the
                                         % project - see docs/analysis-decisions.md
opts.fit.FWHMcoMM3         = 14;         % REQUIRED whenever coMM3 is set:
                                         % OspreyJob.m:564 reads this field
                                         % unconditionally. 14 Hz is Osprey's
                                         % own default (OspreySettings.m:48).
opts.saveLCM   = 0;
opts.savejMRUI = 0;
opts.saveVendor= 0;
opts.saveNII   = 0;                      % not needed; also avoids osp_saveNII
opts.savePDF   = 0;                      % Osprey's PDF export routes through
                                         % osp_plotAllPDF -> uix.Panel, which
                                         % needs the GUI Layout Toolbox (a
                                         % separate File Exchange package, not
                                         % bundled). Driving a GUI toolkit for
                                         % 272 headless fits is fragile and slow,
                                         % so QC plotting is done separately by
                                         % qc_plot.m instead.

J = struct('seqType','MEGA', 'editTarget',{{'GABA'}}, 'dataScenario','invivo', ...
           'files',{{metabFile}}, 'files_ref',{files_ref}, ...
           'outputFolder',outDir, 'opts',opts);

jobPath = fullfile(outDir, 'smoke_job.m');
writeOspreyJobFile(jobPath, J);
fprintf('Job file written: %s\n\n', jobPath);

%% 4. Run ---------------------------------------------------------------------
%
% Each stage separately so a failure names the stage that broke.

stages = {'OspreyJob','OspreyLoad','OspreyProcess','OspreyFit','OspreyQuantify'};
MRSCont = jobPath;
for k = 1:numel(stages)
    fprintf('--> %s ... ', stages{k});
    t0 = tic;
    try
        MRSCont = feval(stages{k}, MRSCont);
        fprintf('ok (%.1fs)\n', toc(t0));
    catch ME
        fprintf('FAILED\n\n');
        fprintf('Stage    : %s\n', stages{k});
        fprintf('Message  : %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('Location : %s line %d\n', ME.stack(1).name, ME.stack(1).line);
        end
        fprintf('\nThis is the useful part. Send me the above verbatim.\n');
        rethrow(ME);
    end
end

%% 5. Verdict -----------------------------------------------------------------

fprintf('\n============== RESULT ==============\n');
try
    disp(MRSCont.quantify.tables.metab);
catch
    fprintf('Could not auto-read the quantify tables.\n');
    fprintf('Inspect manually - field names vary by Osprey version:\n');
    disp(MRSCont.quantify);
end

fprintf('\nSanity: GABA+/Cr should be about 0.08-0.15 (published mean 0.116).\n');
fprintf('NOW OPEN THE PDF in:\n  %s\n', outDir);
fprintf('Check the fit visually. A plausible number with a bad fit is worse\n');
fprintf('than no number at all.\n');
fprintf('====================================\n\n');

save(fullfile(outDir,'MRSCont_smoke.mat'), 'MRSCont', '-v7.3');

end
