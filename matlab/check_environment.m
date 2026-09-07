% check_environment.m
%
% Run this FIRST, before anything else. Takes seconds. Tells you whether this
% machine can run the project at all.
%
% Usage:  cd into this folder in MATLAB, then:  check_environment
%
% Edit ospreyDir below if you installed Osprey somewhere else.

function check_environment()

ospreyDir = fullfile(getenv('USERPROFILE'), 'Documents', 'osprey');

fprintf('\n=========== ENVIRONMENT CHECK ===========\n\n');

pass = true;

%% MATLAB version
v = version('-release');
fprintf('MATLAB release       : %s\n', v);
if verLessThan('matlab','9.2')
    fprintf('   FAIL - Osprey needs R2017a or newer.\n');
    pass = false;
elseif verLessThan('matlab','9.6')
    fprintf('   OK for command line. GUI needs R2019a+; this project does not use the GUI.\n');
else
    fprintf('   OK\n');
end

%% Required toolboxes
%
% THREE SIGNALS, AND THEY MEAN DIFFERENT THINGS. Do not conflate them:
%
%   exist('<fn>')          AUTHORITATIVE for usability. Are the product files
%                          actually on this machine? If no, code will not run,
%                          regardless of licensing.
%   license('test',...)    Entitlement only. Asks "would the license manager
%                          grant this feature" - a licensed-but-NOT-INSTALLED
%                          toolbox returns 1 here. This is not proof of anything
%                          being usable.
%   ver() name matching    Advisory. Display names change between releases.
%                          Note that ver() also only lists INSTALLED products,
%                          which makes it a useful cross-check on exist().
%
% The gate is exist(). License status is reported because it tells you which
% fix you need: entitled-but-missing means "install it", not "buy it".

fprintf('\nRequired toolboxes:\n');
installed = {ver().Name};

% Osprey's documentation lists only the first two. Signal Processing was
% discovered the hard way, via 'hilbert' failing inside op_robustSpecReg during
% OspreyProcess. Run check_toolboxes.m for the authoritative dependency list.
checks = { ...
  'Optimization Toolbox',                    'Optimization_Toolbox', {'fmincon','lsqnonlin'}; ...
  'Statistics and Machine Learning Toolbox', 'Statistics_Toolbox',   {'fitlm','normpdf'}; ...
  'Signal Processing Toolbox',               'Signal_Toolbox',       {'hilbert','findpeaks'} };

for k = 1:size(checks,1)
    displayName = checks{k,1};
    featureName = checks{k,2};
    probeFns    = checks{k,3};

    licOK = false;
    try
        licOK = license('test', featureName) == 1;
    catch
    end

    missingFns = {};
    for j = 1:numel(probeFns)
        if exist(probeFns{j}, 'file') == 0 && exist(probeFns{j}, 'builtin') == 0
            missingFns{end+1} = probeFns{j}; %#ok<AGROW>
        end
    end
    fnOK   = isempty(missingFns);
    nameOK = any(strcmp(installed, displayName));

    % INSTALLED is the only thing that matters for running code.
    fprintf('  %-45s %s\n', displayName, tern(fnOK,'INSTALLED','NOT INSTALLED'));
    fprintf('      functions:%-4s  license:%-4s  ver-name:%-4s\n', ...
            tern(fnOK,'yes','no'), tern(licOK,'yes','no'), tern(nameOK,'yes','no'));

    if ~fnOK
        fprintf('      missing: %s\n', strjoin(missingFns, ', '));
        if licOK
            fprintf('      >> LICENSED BUT NOT INSTALLED. You do not need to buy this.\n');
            fprintf('         Install it: MATLAB Home tab -> Add-Ons -> Get Add-Ons,\n');
            fprintf('         search the toolbox name, click Install. Or re-run the\n');
            fprintf('         MathWorks installer and tick the product.\n');
        else
            fprintf('      >> Not licensed on this machine either. Check your\n');
            fprintf('         Brandeis MathWorks account entitlements.\n');
        end
        pass = false;
    end
end

fprintf('\n  Products ver() reports as INSTALLED:\n');
for k = 1:numel(installed)
    fprintf('    - %s\n', installed{k});
end
if numel(installed) <= 1
    fprintf('    (only base MATLAB - no toolboxes installed on this machine)\n');
end

%% Osprey
fprintf('\nOsprey:\n');
fprintf('  looking in: %s\n', ospreyDir);
if isfolder(ospreyDir)
    fprintf('  folder found                                  OK\n');
    addpath(genpath(ospreyDir));
    coreFns = {'OspreyJob','OspreyLoad','OspreyProcess','OspreyFit','OspreyQuantify'};
    for k = 1:numel(coreFns)
        have = ~isempty(which(coreFns{k}));
        fprintf('  %-45s %s\n', coreFns{k}, tern(have,'OK','NOT ON PATH'));
        if ~have
            pass = false;
        end
    end
else
    fprintf('  NOT FOUND - clone it:\n');
    fprintf('    git clone https://github.com/schorschinho/osprey.git\n');
    pass = false;
end

%% SPM12
%
% Not used by this pipeline (GABA+/Cr needs no coregistration or segmentation),
% but osp_Toolbox_Check lists SPM12 under neededGlobal for OspreyProcess and
% OspreyFit, reached via osp_CheckRunPreviousModule. So it must be on the path
% or Osprey complains at every module boundary.
fprintf('\nSPM12:\n');
spmDir = fullfile(getenv('USERPROFILE'), 'Documents', 'spm12');
if isfolder(spmDir) && isempty(which('spm.m'))
    addpath(spmDir);
    fprintf('  added to path: %s\n', spmDir);
end
spmFound = which('spm.m');
if isempty(spmFound)
    fprintf('  spm.m NOT on path                             MISSING\n');
    fprintf('      expected at %s\n', spmDir);
    fprintf('      fix: addpath(''%s'')   <- top level ONLY, never genpath\n', spmDir);
    pass = false;
else
    fprintf('  %-45s OK\n', spmFound);
end

%% Data
fprintf('\nData:\n');
dataDir = fullfile(fileparts(pwd), 'data');
if ~isfolder(dataDir)
    dataDir = fullfile(pwd, '..', 'data');
end
if isfolder(dataDir)
    d = dir(dataDir);
    d = d([d.isdir] & ~ismember({d.name}, {'.','..'}));
    if isempty(d)
        fprintf('  data/ exists but is empty - download one MEGA-PRESS site first.\n');
    else
        fprintf('  site folders present: %s\n', strjoin({d.name}, ', '));
        for k = 1:numel(d)
            n7   = numel(dir(fullfile(dataDir, d(k).name, '**', '*.7')));
            nsd  = numel(dir(fullfile(dataDir, d(k).name, '**', '*.sdat')));
            ndat = numel(dir(fullfile(dataDir, d(k).name, '**', '*.dat')));
            fprintf('    %-6s  .7=%-4d .sdat=%-4d .dat=%-4d\n', ...
                    d(k).name, n7, nsd, ndat);
        end
    end
else
    fprintf('  data/ not found relative to %s\n', pwd);
end

%% Verdict
fprintf('\n-----------------------------------------\n');
if pass
    fprintf('READY. Next: put one MEGA-PRESS site in data/, then run smoke_test.\n');
else
    fprintf('NOT READY. Fix the items marked MISSING / NOT FOUND above.\n');
end
fprintf('=========================================\n\n');

end

function s = tern(c, a, b)
    if c, s = a; else, s = b; end
end
