% run_osprey_batch.m
%
% Process all in-scope Big GABA sites through Osprey, one site at a time.
%
% Run smoke_test.m first. Do not run this until a single dataset has produced a
% plausible number and a fit you have actually looked at.
%
% Processes site by site rather than all 272 at once so that a failure on one
% vendor does not lose the whole run, and so partial results survive a crash.
%
% UNTESTED.

clear; close all; clc;

%% ------------------------------------------------------------------
%  Configuration - EDIT
%  ------------------------------------------------------------------

ospreyDir = fullfile(getenv('USERPROFILE'), 'Documents', 'osprey');
repoDir   = fileparts(fileparts(mfilename('fullpath')));
dataRoot  = fullfile(repoDir, 'data');
outRoot   = fullfile(repoDir, 'results');
if ~isempty(RUN_LABEL)
    outRoot = fullfile(outRoot, RUN_LABEL);
end
logFile   = fullfile(outRoot, 'batch_log.txt');

% IN-SCOPE SITES ONLY.
% NITRC hosts P10 and S8; Mikkelsen 2017 did not analyse them. Including them
% would compare a different sample against the published numbers.
% SITES IN SCOPE (see docs/discrepancy-log.md D-13).
%
% Mikkelsen 2017 analysed 24 sites (G1-G8, P1-P9, S1-S7, n=272). The public
% MEGA-PRESS release contains only 20 sites, and 6 of the published sites are
% absent entirely: G2, G3, P2, S2, S4, S7. Two sites postdate the paper and are
% out of scope: P10, S8.
%
% What remains: 18 sites, 204 subjects. The exact published sample cannot be
% reconstructed; every comparison must state this.
sites = { 'G1','G4','G5','G6','G7','G8', ...                     % GE      (6)
          'P1','P3','P4','P5','P6','P7','P8','P9', ...           % Philips (8)
          'S1','S5','S6' };                                      % Siemens (3)
% S3 EXCLUDED - unreadable by Osprey as distributed. See D-18.
% Siemens VD software, multi-RAID TWIX container; Osprey's bundled mapVBVD
% fails in read_twix_hdr.m:15 before any processing. Not a data-quality
% exclusion - the data may be fine, but this toolchain cannot read it.

% Restrict the run, e.g. {'S1'} for a single site. Empty = all of the above.
ONLY_SITES = {};

% ---------------------------------------------------------------------------
% RUN CONFIGURATION
%
% RUN_LABEL separates output from different analysis configurations:
%   ''              -> results/<site>                  (primary run, default range)
%   'gannet_range'  -> results/gannet_range/<site>     (fit-range sensitivity)
%
% FIT_RANGE is the one variable under test (D-07):
%   []            -> use Osprey's default, [0.2 4.2] (OspreySettings.m:42)
%   [2.79 4.10]   -> Gannet's difference-spectrum fit range (Mikkelsen 2017)
%
% Everything else is held fixed so the comparison isolates the fit range.
% ---------------------------------------------------------------------------
RUN_LABEL = '';
FIT_RANGE = [];

% Skip sites that already have results. Makes a long unattended run resumable:
% if it dies at site 14, restarting picks up where it stopped rather than
% redoing 13 sites of compute.
SKIP_EXISTING = true;

if ~isempty(ONLY_SITES)
    sites = sites(ismember(sites, ONLY_SITES));
    fprintf('RESTRICTED RUN: %s\n', strjoin(sites, ', '));
end

% File extension by vendor prefix. VERIFY against the unzipped archives before
% trusting this - the internal layout has not been confirmed.
extByVendor = containers.Map( {'G','P','S'}, {'.7', '.SDAT', '.dat'} );

%% ------------------------------------------------------------------
%  Setup
%  ------------------------------------------------------------------

addpath(genpath(ospreyDir));
addpath(fileparts(mfilename('fullpath')));   % for writeOspreyJobFile

spmDir = fullfile(getenv('USERPROFILE'), 'Documents', 'spm12');
if isfolder(spmDir) && isempty(which('spm.m')); addpath(spmDir); end

diary off; fclose('all');

if ~isfolder(outRoot); mkdir(outRoot); end

fid = fopen(logFile, 'a');
logmsg = @(varargin) logBoth(fid, varargin{:});
logmsg('==== batch started %s ====', datestr(now));
if isempty(RUN_LABEL)
    logmsg('     config: PRIMARY  fit.range = Osprey default [0.2 4.2]');
else
    logmsg('     config: %s  fit.range = [%.2f %.2f]', RUN_LABEL, FIT_RANGE(1), FIT_RANGE(2));
end
logmsg('     output: %s', outRoot);

%% ------------------------------------------------------------------
%  Shared options - identical for every site.
%  ------------------------------------------------------------------
%
% Holding these fixed across vendors is the entire design. If a vendor needs a
% different setting to run at all, that is a finding: log it in
% docs/discrepancy-log.md rather than silently special-casing it here.

opts = struct();
opts.SpecReg               = 'RobSpecReg';
opts.SubSpecAlignment.mets = 'L2Norm';
opts.fit.method            = 'Osprey';
opts.fit.style             = 'Separate';   % Osprey forces this for MEGA
opts.fit.includeMetabs     = {'default'};
opts.fit.coMM3             = '3to2MM';
opts.fit.FWHMcoMM3         = 14;
if ~isempty(FIT_RANGE)
    opts.fit.range = FIT_RANGE;
end          % required companion field to coMM3
opts.saveLCM               = 0;
opts.savejMRUI             = 0;
opts.saveVendor            = 0;
opts.saveNII               = 0;   % not needed; also avoids osp_saveNII
opts.savePDF               = 0;   % see smoke_test.m - QC via qc_plot.m

%% ------------------------------------------------------------------
%  Main loop
%  ------------------------------------------------------------------

summary = struct('site', {}, 'nFound', {}, 'status', {}, 'msg', {});

for s = 1:numel(sites)

    site    = sites{s};
    vendor  = site(1);
    outDir  = fullfile(outRoot, site);

    % NITRC archives unpack as <SITE>_MP (MEGA-PRESS) or <SITE>_P (PRESS).
    % Accept either the bare site name or the _MP suffix; never _P, which is
    % short-TE data and out of scope.
    candidates = {fullfile(dataRoot, [site '_MP']), fullfile(dataRoot, site)};
    siteDir = '';
    for c = 1:numel(candidates)
        if isfolder(candidates{c}); siteDir = candidates{c}; break; end
    end
    if isempty(siteDir); siteDir = candidates{1}; end

    logmsg('--- %s ---', site);

    doneMarker = fullfile(outDir, sprintf('MRSCont_%s.mat', site));
    if SKIP_EXISTING && isfile(doneMarker)
        logmsg('  SKIP: already processed (%s exists)', doneMarker);
        summary(end+1) = struct('site', site, 'nFound', 0, ...
                                'status', 'skipped', 'msg', 'existing results'); %#ok<SAGROW>
        continue;
    end

    if ~isfolder(siteDir)
        logmsg('  SKIP: directory not found (%s)', siteDir);
        summary(end+1) = struct('site', site, 'nFound', 0, ...
                                'status', 'missing', 'msg', siteDir); %#ok<SAGROW>
        continue;
    end

    ext   = extByVendor(vendor);
    found = dir(fullfile(siteDir, '**', ['*' ext]));   % '**' handles the extra
                                                       % nesting in G*/P* archives

    % Vendor file conventions, verified against the unpacked archives:
    %   Siemens  S01_GABA_68.dat        + S01_GABA_68_H2O.dat
    %   GE       S01_GABA_68.7          (water reference embedded in the P-file)
    %   Philips  S01_GABA_68_act.SDAT   + S01_GABA_68_ref.SDAT  (+ .SPAR headers)
    %
    % The _68 / _80 suffixes denote ACQUISITION TYPE, not literal echo time:
    %   _68 = GABA+ (co-edited MM present)   <- in scope
    %   _80 = MM-suppressed GABA             <- out of scope
    % Mikkelsen 2017 gives MM-suppressed TE as 80 ms for GE/Philips but 68 ms for
    % Siemens, and Important_Notes.pdf confirms TE 68 for the _80 files at S6.
    % The filename is a label, not a measurement. This filter selects the GABA+
    % acquisition, which is what matters.
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

    % Pair each metabolite file with its OWN reference by filename stem.
    % Positional pairing would silently mis-associate a subject's water
    % reference with another subject's spectrum - no error, plausible numbers,
    % wrong results. Same failure class as mixing TE 68 and TE 80.
    logmsg('  TE68: %d metabolite, %d reference (of %d files matching *%s)', ...
           numel(metabFiles), numel(refFiles), numel(found), ext);

    metab = metabFiles;
    pairedRefs = cell(1, numel(metabFiles));
    nUnpaired  = 0;

    for m = 1:numel(metabFiles)
        [~, stem, e] = fileparts(metabFiles(m).name);
        if endsWith(lower(stem), '_act')          % Philips
            wanted = [stem(1:end-4) '_ref' e];
        else                                      % Siemens
            wanted = [stem '_H2O' e];
        end
        % ---- Site-specific exception: S6 --------------------------------
        % Important_Notes.pdf (Big GABA, NITRC): at S6 water suppression was
        % mistakenly left on while acquiring the GABA+ water references, so
        % *GABA_68_H2O is unusable for subjects S01-S06. The data providers
        % recommend substituting the MM-suppressed water reference
        % (*GABA_80_H2O), the TEs being equivalent (68 ms).
        %
        % We follow the providers' documented recommendation. See D-15.
        if strcmpi(site, 'S6')
            subj = extractBefore(metabFiles(m).name, '_');
            if ismember(upper(subj), {'S01','S02','S03','S04','S05','S06'})
                wanted = strrep(wanted, '_68_H2O', '_80_H2O');
                logmsg('    %s: using %s (documented S6 acquisition error)', ...
                       subj, wanted);
            end
        end
        % -----------------------------------------------------------------

        idx = find(strcmpi({refFiles.name}, wanted), 1);
        if isempty(idx)
            pairedRefs{m} = '';
            nUnpaired = nUnpaired + 1;
        else
            pairedRefs{m} = fullfile(refFiles(idx).folder, refFiles(idx).name);
        end
    end

    if vendor == 'G'
        files_ref = {};                            % embedded in the P-file
    elseif nUnpaired == 0 && ~isempty(metabFiles)
        files_ref = pairedRefs;
    else
        logmsg(['  WARNING: %d of %d metabolite files have no matching water ' ...
                'reference. Falling back to ratio-only quantification for this ' ...
                'site rather than risk mis-pairing.'], nUnpaired, numel(metabFiles));
        files_ref = {};
    end

    refs = refFiles;   % kept for the log line below

    if isempty(metab)
        logmsg('  SKIP: no metabolite files matched *%s', ext);
        summary(end+1) = struct('site', site, 'nFound', 0, ...
                                'status', 'no_data', 'msg', ext); %#ok<SAGROW>
        continue;
    end

    files = fullfile({metab.folder}, {metab.name});

    % Clear per-site output so Osprey does not block on its overwrite prompt.
    % An interactive prompt inside a 24-site loop would hang the run overnight.
    if isfolder(outDir)
        [ok,~] = rmdir(outDir, 's');
        if ~ok
            outDir = [outDir '_' datestr(now,'yyyymmdd_HHMMSS')];
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
        % Never abort the batch on one site. Record and move on.
        % Log the FULL stack: the message alone is rarely enough to diagnose a
        % failure after an unattended run, and re-running a site to recover the
        % trace costs 20-30 minutes.
        logmsg('  FAIL: %s', ME.message);
        logmsg('        identifier: %s', ME.identifier);
        for st = 1:numel(ME.stack)
            logmsg('        at %s (line %d)', ME.stack(st).name, ME.stack(st).line);
        end
        summary(end+1) = struct('site', site, 'nFound', numel(files), ...
                                'status', 'error', 'msg', ME.message); %#ok<SAGROW>
    end
end

%% ------------------------------------------------------------------
%  Wrap up
%  ------------------------------------------------------------------

% 'AsArray' is required when the struct is scalar (a single site) - without it
% struct2table errors because the char fields have differing row counts.
if numel(summary) == 1
    T = struct2table(summary, 'AsArray', true);
else
    T = struct2table(summary);
end
writetable(T, fullfile(outRoot, 'batch_summary.csv'));

logmsg('==== batch finished %s ====', datestr(now));
logmsg('ok=%d  error=%d  missing=%d  no_data=%d', ...
       sum(strcmp(T.status,'ok')),      sum(strcmp(T.status,'error')), ...
       sum(strcmp(T.status,'missing')), sum(strcmp(T.status,'no_data')));
fclose(fid);

disp(T);
fprintf('\nEvery site that did not return ok needs an entry in docs/discrepancy-log.md.\n');

% -------------------------------------------------------------------------

function logBoth(fid, fmt, varargin)
    msg = sprintf(fmt, varargin{:});
    fprintf('%s\n', msg);
    fprintf(fid, '%s\n', msg);
end
