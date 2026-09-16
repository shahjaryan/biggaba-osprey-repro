% run_osprey_batch.m
%
% Process Big GABA sites through Osprey, one site at a time.
%
% Run smoke_test.m first. Do not run this until a single dataset has produced a
% plausible number and a fit you have actually looked at.
%
% Site-by-site rather than one large job so a failure on one vendor does not
% lose the whole run, and so partial results survive a crash.

clear; close all; clc;

%% ===================================================================
%  RUN CONFIGURATION  - the only block you normally edit
%  ===================================================================
%
% RUN_LABEL separates output from different analysis configurations:
%   ''             -> results/<site>                 (primary run)
%   'gannet_range' -> results/gannet_range/<site>    (fit-range sensitivity)
%
% FIT_RANGE is the variable under test in the D-07 sensitivity analysis:
%   []            -> Osprey's default [0.2 4.2] (OspreySettings.m:42)
%   [2.79 4.10]   -> Gannet's difference-spectrum range (Mikkelsen 2017)
%
% Everything else is held fixed so the comparison isolates the fit range.

RUN_LABEL = 'gannet_range';
FIT_RANGE = [2.79 4.10];

ONLY_SITES    = {};    % e.g. {'S1'} to restrict; {} = all in-scope sites
SKIP_EXISTING = true;  % resume: skip sites that already have an MRSCont .mat

%% ===================================================================
%  Paths
%  ===================================================================

ospreyDir = fullfile(getenv('USERPROFILE'), 'Documents', 'osprey');
spmDir    = fullfile(getenv('USERPROFILE'), 'Documents', 'spm12');
repoDir   = fileparts(fileparts(mfilename('fullpath')));
dataRoot  = fullfile(repoDir, 'data');

outRoot = fullfile(repoDir, 'results');
if ~isempty(RUN_LABEL)
    outRoot = fullfile(outRoot, RUN_LABEL);
end
if ~isfolder(outRoot); mkdir(outRoot); end
logFile = fullfile(outRoot, 'batch_log.txt');

%% ===================================================================
%  Sites in scope   (see docs/discrepancy-log.md, D-13 and D-18)
%  ===================================================================
%
% Mikkelsen 2017 analysed 24 sites (G1-G8, P1-P9, S1-S7, n=272). The public
% MEGA-PRESS release contains only 20; six published sites are absent entirely
% (G2, G3, P2, S2, S4, S7) and two postdate the paper (P10, S8 - out of scope).
%
% S3 is additionally EXCLUDED (D-18): Siemens VD software with a multi-RAID
% TWIX container, which Osprey's bundled mapVBVD cannot read - it fails in
% read_twix_hdr.m:15 before any processing. Not a data-quality exclusion; the
% data may be fine, but this toolchain cannot read it.
%
% What remains: 17 sites, 192 subjects. The published sample cannot be
% reconstructed, and every comparison must state this.

sites = { 'G1','G4','G5','G6','G7','G8', ...              % GE      (6)
          'P1','P3','P4','P5','P6','P7','P8','P9', ...    % Philips (8)
          'S1','S5','S6' };                               % Siemens (3)

if ~isempty(ONLY_SITES)
    sites = sites(ismember(sites, ONLY_SITES));
end

% Metabolite file extension by vendor prefix, verified against the archives.
extByVendor = containers.Map( {'G','P','S'}, {'.7', '.SDAT', '.dat'} );

%% ===================================================================
%  Setup
%  ===================================================================

addpath(genpath(ospreyDir));
addpath(fileparts(mfilename('fullpath')));      % writeOspreyJobFile

% SPM12 is not used by this pipeline (no coregistration, no segmentation) but
% osp_Toolbox_Check lists it under neededGlobal for OspreyProcess/OspreyFit,
% reached via osp_CheckRunPreviousModule. Top level only - never genpath.
if isfolder(spmDir) && isempty(which('spm.m')); addpath(spmDir); end

diary off; fclose('all');

fid = fopen(logFile, 'a');
logmsg = @(varargin) logBoth(fid, varargin{:});

logmsg('==== batch started %s ====', datestr(now));
if isempty(RUN_LABEL)
    logmsg('     config: PRIMARY   fit.range = Osprey default [0.2 4.2]');
else
    logmsg('     config: %s   fit.range = [%.2f %.2f]', RUN_LABEL, FIT_RANGE(1), FIT_RANGE(2));
end
logmsg('     sites : %s', strjoin(sites, ', '));
logmsg('     output: %s', outRoot);

%% ===================================================================
%  Processing options - identical for every site
%  ===================================================================
%
% Holding these fixed across vendors is the entire design. If a vendor needs a
% different setting to run at all, that is a finding for the discrepancy log,
% not something to special-case silently here.

opts = struct();
opts.SpecReg               = 'RobSpecReg';
opts.SubSpecAlignment.mets = 'L2Norm';
opts.fit.method            = 'Osprey';
opts.fit.style             = 'Separate';   % Osprey forces this for MEGA (D-01)
opts.fit.includeMetabs     = {'default'};
opts.fit.coMM3             = '3to2MM';
opts.fit.FWHMcoMM3         = 14;           % required companion to coMM3 (D-02)
if ~isempty(FIT_RANGE)
    opts.fit.range = FIT_RANGE;
end
opts.saveLCM    = 0;
opts.savejMRUI  = 0;
opts.saveVendor = 0;
opts.saveNII    = 0;
opts.savePDF    = 0;   % routes through uix.Panel (GUI Layout Toolbox); QC via qc_plot.m

%% ===================================================================
%  Main loop
%  ===================================================================

summary = struct('site', {}, 'nFound', {}, 'status', {}, 'msg', {});

for s = 1:numel(sites)

    site   = sites{s};
    vendor = site(1);
    outDir = fullfile(outRoot, site);

    logmsg('--- %s ---', site);

    % Resume support.
    doneMarker = fullfile(outDir, sprintf('MRSCont_%s.mat', site));
    if SKIP_EXISTING && isfile(doneMarker)
        logmsg('  SKIP: already processed');
        summary(end+1) = struct('site', site, 'nFound', 0, ...
                                'status', 'skipped', 'msg', 'existing results'); %#ok<SAGROW>
        continue;
    end

    % NITRC archives unpack either as <SITE>_MP/<subject>/ or with an extra
    % nesting level, <SITE>_MP/<SITE>_MP/<subject>/. Recursive globbing below
    % handles both; here we just locate the site root.
    candidates = {fullfile(dataRoot, [site '_MP']), fullfile(dataRoot, site)};
    siteDir = '';
    for c = 1:numel(candidates)
        if isfolder(candidates{c}); siteDir = candidates{c}; break; end
    end
    if isempty(siteDir)
        logmsg('  SKIP: directory not found (%s)', candidates{1});
        summary(end+1) = struct('site', site, 'nFound', 0, ...
                                'status', 'missing', 'msg', candidates{1}); %#ok<SAGROW>
        continue;
    end

    ext   = extByVendor(vendor);
    found = dir(fullfile(siteDir, '**', ['*' ext]));
    if isempty(found)
        logmsg('  SKIP: no files matching *%s', ext);
        summary(end+1) = struct('site', site, 'nFound', 0, ...
                                'status', 'no_data', 'msg', ext); %#ok<SAGROW>
        continue;
    end

    % ---- File selection -------------------------------------------------
    % The _68 / _80 suffixes denote ACQUISITION TYPE, not literal echo time:
    %   _68 = GABA+ (co-edited MM present)   <- in scope
    %   _80 = MM-suppressed GABA             <- out of scope
    % Mikkelsen 2017 gives MM-suppressed TE as 80 ms for GE/Philips but 68 ms
    % for Siemens, and Important_Notes.pdf confirms TE 68 for the _80 files at
    % S6. Mixing the two would double the apparent n and average two different
    % measurements into one plausible-looking mean (D-03).
    names = {found.name};
    isRef = contains(lower(names), {'h2o', '_ref.', 'water', '_w.'});
    isTE  = contains(names, '_68.') | contains(names, '_68_');

    metabFiles = found(~isRef & isTE);

    % Reference candidates are normally TE68 only. S6 is an exception: its
    % documented substitutes are the _80_H2O files, so keep all references there.
    if strcmpi(site, 'S6')
        refFiles = found(isRef);
    else
        refFiles = found(isRef & isTE);
    end

    logmsg('  TE68: %d metabolite, %d reference (of %d files matching *%s)', ...
           numel(metabFiles), numel(refFiles), numel(found), ext);

    if isempty(metabFiles)
        logmsg('  SKIP: no metabolite files matched TE 68');
        summary(end+1) = struct('site', site, 'nFound', 0, ...
                                'status', 'te_unmatched', 'msg', ''); %#ok<SAGROW>
        continue;
    end

    % ---- Reference pairing ----------------------------------------------
    % Pair each metabolite file with its OWN reference by filename stem.
    % Positional pairing would silently mis-associate one subject's water
    % reference with another's spectrum - no error, plausible numbers, wrong
    % results. Same failure class as mixing TE 68 and TE 80.
    pairedRefs = cell(1, numel(metabFiles));
    nUnpaired  = 0;

    for m = 1:numel(metabFiles)
        [~, stem, e] = fileparts(metabFiles(m).name);
        if endsWith(lower(stem), '_act')          % Philips
            wanted = [stem(1:end-4) '_ref' e];
        else                                      % Siemens
            wanted = [stem '_H2O' e];
        end

        % Site-specific exception: S6 (D-15).
        % Important_Notes.pdf: at S6 water suppression was mistakenly left on
        % while acquiring the GABA+ water references, so *GABA_68_H2O is
        % unusable for subjects S01-S06. The data providers recommend
        % substituting the MM-suppressed reference (*GABA_80_H2O), the echo
        % times being equivalent (68 ms). We follow that recommendation.
        if strcmpi(site, 'S6')
            subj = extractBefore(metabFiles(m).name, '_');
            if ismember(upper(subj), {'S01','S02','S03','S04','S05','S06'})
                wanted = strrep(wanted, '_68_H2O', '_80_H2O');
                logmsg('    %s: using %s (documented S6 acquisition error)', subj, wanted);
            end
        end

        idx = find(strcmpi({refFiles.name}, wanted), 1);
        if isempty(idx)
            pairedRefs{m} = '';
            nUnpaired = nUnpaired + 1;
        else
            pairedRefs{m} = fullfile(refFiles(idx).folder, refFiles(idx).name);
        end
    end

    if vendor == 'G'
        files_ref = {};                    % GE P-files embed their own reference
    elseif nUnpaired == 0
        files_ref = pairedRefs;
    else
        logmsg(['  WARNING: %d of %d metabolite files have no matching water ' ...
                'reference. Falling back to ratio-only rather than risk ' ...
                'mis-pairing.'], nUnpaired, numel(metabFiles));
        files_ref = {};
    end

    files = fullfile({metabFiles.folder}, {metabFiles.name});

    % ---- Output directory -----------------------------------------------
    % Cleared each run so Osprey does not block on its interactive overwrite
    % prompt, which would hang an unattended batch indefinitely.
    if isfolder(outDir)
        [ok, ~] = rmdir(outDir, 's');
        if ~ok
            outDir = [outDir '_' datestr(now, 'yyyymmdd_HHMMSS')];
            logmsg('  could not clear output dir; using %s', outDir);
        end
    end
    mkdir(outDir);

    J = struct('seqType', 'MEGA', 'editTarget', {{'GABA'}}, ...
               'dataScenario', 'invivo', 'files', {files}, ...
               'files_ref', {files_ref}, 'outputFolder', outDir, 'opts', opts);

    jobPath = fullfile(outDir, sprintf('job_%s.m', site));
    writeOspreyJobFile(jobPath, J);

    try
        t0 = tic;
        MRSCont = OspreyJob(jobPath);
        MRSCont = OspreyLoad(MRSCont);
        MRSCont = OspreyProcess(MRSCont);
        MRSCont = OspreyFit(MRSCont);
        MRSCont = OspreyQuantify(MRSCont);

        save(fullfile(outDir, sprintf('MRSCont_%s.mat', site)), 'MRSCont', '-v7.3');

        logmsg('  OK: %d dataset(s) in %.1f min', numel(files), toc(t0)/60);
        summary(end+1) = struct('site', site, 'nFound', numel(files), ...
                                'status', 'ok', 'msg', ''); %#ok<SAGROW>
    catch ME
        % Never abort the batch on one site. Log the FULL stack - the message
        % alone is rarely enough to diagnose a failure after an unattended run,
        % and re-running a site to recover the trace costs 20-30 minutes.
        logmsg('  FAIL: %s', ME.message);
        logmsg('        identifier: %s', ME.identifier);
        for st = 1:numel(ME.stack)
            logmsg('        at %s (line %d)', ME.stack(st).name, ME.stack(st).line);
        end
        summary(end+1) = struct('site', site, 'nFound', numel(files), ...
                                'status', 'error', 'msg', ME.message); %#ok<SAGROW>
    end
end

%% ===================================================================
%  Wrap up
%  ===================================================================

% 'AsArray' is required when the struct is scalar (a single-site run) -
% without it struct2table errors because the char fields differ in row count.
if numel(summary) == 1
    T = struct2table(summary, 'AsArray', true);
else
    T = struct2table(summary);
end
writetable(T, fullfile(outRoot, 'batch_summary.csv'));

logmsg('==== batch finished %s ====', datestr(now));
logmsg('ok=%d  error=%d  missing=%d  skipped=%d', ...
       sum(strcmp(T.status,'ok')),      sum(strcmp(T.status,'error')), ...
       sum(strcmp(T.status,'missing')), sum(strcmp(T.status,'skipped')));
fclose(fid);

disp(T);
fprintf('\nEvery site that did not return ok needs an entry in docs/discrepancy-log.md.\n');

%% -------------------------------------------------------------------

function logBoth(fid, fmt, varargin)
    msg = sprintf(fmt, varargin{:});
    fprintf('%s\n', msg);
    fprintf(fid, '%s\n', msg);
end
