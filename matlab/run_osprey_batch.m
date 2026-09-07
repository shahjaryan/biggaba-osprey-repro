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
logFile   = fullfile(outRoot, 'batch_log.txt');

% IN-SCOPE SITES ONLY.
% NITRC hosts P10 and S8; Mikkelsen 2017 did not analyse them. Including them
% would compare a different sample against the published numbers.
% Set ONLY_SITES to restrict the run, e.g. {'S1'} for a single-site test.
% Leave empty to process everything in scope.
ONLY_SITES = {'S1'};

sites = [ arrayfun(@(i) sprintf('G%d', i), 1:8, 'UniformOutput', false), ...
          arrayfun(@(i) sprintf('P%d', i), 1:9, 'UniformOutput', false), ...
          arrayfun(@(i) sprintf('S%d', i), 1:7, 'UniformOutput', false) ];

if ~isempty(ONLY_SITES)
    sites = sites(ismember(sites, ONLY_SITES));
    fprintf('RESTRICTED RUN: %s\n', strjoin(sites, ', '));
end

% File extension by vendor prefix. VERIFY against the unzipped archives before
% trusting this - the internal layout has not been confirmed.
extByVendor = containers.Map( {'G','P','S'}, {'.7', '.sdat', '.dat'} );

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
opts.fit.FWHMcoMM3         = 14;          % required companion field to coMM3
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

    if ~isfolder(siteDir)
        logmsg('  SKIP: directory not found (%s)', siteDir);
        summary(end+1) = struct('site', site, 'nFound', 0, ...
                                'status', 'missing', 'msg', siteDir); %#ok<SAGROW>
        continue;
    end

    ext   = extByVendor(vendor);
    found = dir(fullfile(siteDir, '**', ['*' ext]));

    % CRITICAL: each subject has TE 68 (GABA+) AND TE 80 (MM-suppressed).
    % They are different measures with different published values. Taking both
    % would double the apparent n and silently average two quantities together.
    names = {found.name};
    isRef = contains(lower(names), {'h2o', 'ref', 'water', '_w.'});
    isTE  = contains(names, '_68.') | contains(names, '_68_');

    metab = found(~isRef & isTE);
    refs  = found(isRef & isTE);

    if isempty(metab) && any(~isRef)
        logmsg(['  WARNING: no file matched TE 68 at %s. Vendor naming may ' ...
                'differ. NOT processing - verify naming first.'], site);
        summary(end+1) = struct('site', site, 'nFound', 0, ...
                                'status', 'te_unmatched', 'msg', ''); %#ok<SAGROW>
        continue;
    end

    logmsg('  TE68: %d metabolite, %d reference (of %d total files)', ...
           numel(metab), numel(refs), numel(found));

    if isempty(metab)
        logmsg('  SKIP: no metabolite files matched *%s', ext);
        summary(end+1) = struct('site', site, 'nFound', 0, ...
                                'status', 'no_data', 'msg', ext); %#ok<SAGROW>
        continue;
    end

    files = fullfile({metab.folder}, {metab.name});

    % GE P-files embed their water reference; the others need it supplied.
    if vendor == 'G' || isempty(refs)
        files_ref = {};
    else
        files_ref = fullfile({refs.folder}, {refs.name});
        if numel(files_ref) ~= numel(files)
            logmsg(['  WARNING: %d metabolite vs %d reference files. Osprey ' ...
                    'requires equal-length arrays. Check pairing before trusting ' ...
                    'this site.'], numel(files), numel(files_ref));
        end
    end

    % Clear per-site output so Osprey does not block on its overwrite prompt.
    % An interactive prompt inside a 24-site loop would hang the run overnight.
    if isfolder(outDir)
        [ok,~] = rmdir(outDir, 's');
        if ~ok
            outDir = [outDir '_' datestr(now,'yyyymmdd_HHMMSS')];
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
        logmsg('  FAIL: %s', ME.message);
        summary(end+1) = struct('site', site, 'nFound', numel(files), ...
                                'status', 'error', 'msg', ME.message); %#ok<SAGROW>
    end
end

%% ------------------------------------------------------------------
%  Wrap up
%  ------------------------------------------------------------------

T = struct2table(summary);
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
