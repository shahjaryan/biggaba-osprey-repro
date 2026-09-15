% diagnose_s3.m
%
% Why did S3 fail with "Index exceeds array bounds"?
%
% HYPOTHESIS: S3 contains two acquisition variants. Six subjects have ~186 MB
% metabolite files (26.9 MB water refs); the other six have ~94 MB (14.2 MB) -
% almost exactly a 2:1 ratio, consistent with a different channel count or
% number of averages. Osprey processes all 12 in one container, and something
% downstream may assume uniform data dimensions across a job.
%
% TEST: run each size group separately. If both succeed alone but the combined
% job fails, the hypothesis is confirmed and the workaround is obvious.
%
% Run from D:\biggaba-osprey-repro\matlab

function diagnose_s3()

ospreyDir = fullfile(getenv('USERPROFILE'), 'Documents', 'osprey');
addpath(genpath(ospreyDir));
addpath(fileparts(mfilename('fullpath')));
spmDir = fullfile(getenv('USERPROFILE'), 'Documents', 'spm12');
if isfolder(spmDir) && isempty(which('spm.m')); addpath(spmDir); end

repoDir = fileparts(fileparts(mfilename('fullpath')));
siteDir = fullfile(repoDir, 'data', 'S3_MP');
outRoot = fullfile(repoDir, 'results', 'S3_diagnostic');

% Groups determined by file size (see header).
GROUP_LARGE = {'S01','S02','S03','S09','S11','S12'};
GROUP_SMALL = {'S04','S05','S06','S07','S08','S10'};

opts = struct();
opts.SpecReg               = 'RobSpecReg';
opts.SubSpecAlignment.mets = 'L2Norm';
opts.fit.method            = 'Osprey';
opts.fit.style             = 'Separate';
opts.fit.includeMetabs     = {'default'};
opts.fit.coMM3             = '3to2MM';
opts.fit.FWHMcoMM3         = 14;
opts.saveLCM = 0; opts.savejMRUI = 0; opts.saveVendor = 0;
opts.savePDF = 0; opts.saveNII = 0;

diary off; fclose('all');

%% Report the actual data dimensions first -----------------------------------
fprintf('\n=============== S3 FILE INVENTORY ===============\n');
d = dir(fullfile(siteDir, '**', '*_68.dat'));
d = d(~contains(lower({d.name}), 'h2o'));
for k = 1:numel(d)
    fprintf('  %-28s %8.1f MB\n', d(k).name, d(k).bytes/1e6);
end

%% Run the three configurations ----------------------------------------------
runs = { 'ALL_12',      [GROUP_LARGE GROUP_SMALL]; ...
         'LARGE_only',  GROUP_LARGE; ...
         'SMALL_only',  GROUP_SMALL };

results = struct('name',{},'n',{},'status',{},'msg',{},'where',{});

for r = 1:size(runs,1)
    name  = runs{r,1};
    subjs = runs{r,2};

    fprintf('\n=============== %s (n=%d) ===============\n', name, numel(subjs));

    files = {}; files_ref = {};
    for k = 1:numel(subjs)
        m = fullfile(siteDir, subjs{k}, sprintf('%s_GABA_68.dat', subjs{k}));
        w = fullfile(siteDir, subjs{k}, sprintf('%s_GABA_68_H2O.dat', subjs{k}));
        if isfile(m)
            files{end+1} = m; %#ok<AGROW>
            if isfile(w); files_ref{end+1} = w; end %#ok<AGROW>
        end
    end

    outDir = fullfile(outRoot, name);
    if isfolder(outDir); rmdir(outDir,'s'); end
    mkdir(outDir);

    J = struct('seqType','MEGA', 'editTarget',{{'GABA'}}, 'dataScenario','invivo', ...
               'files',{files}, 'files_ref',{files_ref}, ...
               'outputFolder',outDir, 'opts',opts);
    jobPath = fullfile(outDir, 'job.m');
    writeOspreyJobFile(jobPath, J);

    status='ok'; msg=''; where='';
    try
        MRSCont = OspreyJob(jobPath);
        MRSCont = OspreyLoad(MRSCont);

        % Print the loaded dimensions - this is the evidence either way.
        fprintf('\n  loaded dimensions:\n');
        for k = 1:numel(MRSCont.raw)
            try
                fprintf('    %-6s sz=%-18s sw=%.1f  txfrq=%.3f MHz\n', subjs{k}, ...
                        mat2str(MRSCont.raw{k}.sz), MRSCont.raw{k}.spectralwidth, ...
                        MRSCont.raw{k}.txfrq/1e6);
            catch
                fprintf('    %-6s (could not read dims)\n', subjs{k});
            end
        end

        MRSCont = OspreyProcess(MRSCont);
        MRSCont = OspreyFit(MRSCont);
        MRSCont = OspreyQuantify(MRSCont);
        fprintf('\n  >>> %s COMPLETED\n', name);
    catch ME
        status='FAILED'; msg=ME.message;
        if ~isempty(ME.stack)
            where = sprintf('%s line %d', ME.stack(1).name, ME.stack(1).line);
        end
        fprintf('\n  >>> %s FAILED: %s\n', name, msg);
        fprintf('      identifier: %s\n', ME.identifier);
        for st = 1:numel(ME.stack)
            fprintf('      at %s (line %d)\n', ME.stack(st).name, ME.stack(st).line);
        end
    end

    results(end+1) = struct('name',name,'n',numel(files), ...
                            'status',status,'msg',msg,'where',where); %#ok<AGROW>
end

%% Verdict -------------------------------------------------------------------
fprintf('\n=============== VERDICT ===============\n');
for r = 1:numel(results)
    fprintf('  %-12s n=%-3d %-8s %s %s\n', results(r).name, results(r).n, ...
            results(r).status, results(r).msg, results(r).where);
end

allFailed   = strcmp(results(1).status,'FAILED');
groupsOK    = strcmp(results(2).status,'ok') && strcmp(results(3).status,'ok');
if allFailed && groupsOK
    fprintf(['\n  CONFIRMED: each group processes alone, the combined job does not.\n' ...
             '  Osprey cannot handle mixed data dimensions within one job.\n' ...
             '  Workaround: process S3 as two sub-jobs and pool the results.\n']);
elseif allFailed && ~groupsOK
    fprintf(['\n  NOT the mixed-dimension issue - a group failed on its own too.\n' ...
             '  Look at the stack above; the problem is dataset-specific.\n']);
else
    fprintf('\n  The combined job succeeded this time. Re-examine the original failure.\n');
end
fprintf('=======================================\n\n');

end
