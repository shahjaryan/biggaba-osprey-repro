% check_toolboxes.m
%
% Ask MATLAB which products the Osprey pipeline ACTUALLY requires, instead of
% discovering them one crash at a time.
%
% Uses matlab.codetools.requiredFilesAndProducts, which performs static
% dependency analysis on the call graph. This is authoritative in a way that
% reading documentation is not - Osprey's docs list two required toolboxes; the
% real answer has been at least three.
%
% SLOW. Osprey's tree is large, so expect several minutes. Run it once.

function check_toolboxes()

ospreyDir = fullfile(getenv('USERPROFILE'), 'Documents', 'osprey');
addpath(genpath(ospreyDir));

entryPoints = {'OspreyJob','OspreyLoad','OspreyProcess','OspreyFit','OspreyQuantify'};

fprintf('\n===== OSPREY PRODUCT DEPENDENCY SCAN =====\n');
fprintf('This is slow (static analysis of a large call graph). Please wait.\n\n');

allProducts = {};

for k = 1:numel(entryPoints)
    fn = which(entryPoints{k});
    if isempty(fn)
        fprintf('%-16s NOT ON PATH - skipped\n', entryPoints{k});
        continue;
    end

    fprintf('%-16s scanning ... ', entryPoints{k});
    t0 = tic;
    try
        [~, pList] = matlab.codetools.requiredFilesAndProducts(fn);
        names = {pList.Name};
        allProducts = union(allProducts, names);
        fprintf('%d product(s) (%.0fs)\n', numel(names), toc(t0));
    catch ME
        fprintf('scan failed: %s\n', ME.message);
    end
end

fprintf('\n===== UNION OF REQUIRED PRODUCTS =====\n');
installed = {ver().Name};
missing   = {};

for k = 1:numel(allProducts)
    have = any(strcmp(installed, allProducts{k}));
    fprintf('  %-48s %s\n', allProducts{k}, tern(have,'INSTALLED','MISSING'));
    if ~have
        missing{end+1} = allProducts{k}; %#ok<AGROW>
    end
end

fprintf('\n');
if isempty(missing)
    fprintf('All required products are installed.\n');
else
    fprintf('MISSING %d product(s). Install all of them before batching:\n', numel(missing));
    for k = 1:numel(missing)
        fprintf('   - %s\n', missing{k});
    end
    fprintf('\nMATLAB Home tab -> Add-Ons -> Get Add-Ons, search each name.\n');
end

fprintf('\nNOTE: static analysis can miss dependencies reached only through\n');
fprintf('feval/eval or dynamic dispatch, so this is a floor, not a guarantee.\n');
fprintf('==========================================\n\n');

end

function s = tern(c,a,b)
    if c, s = a; else, s = b; end
end
