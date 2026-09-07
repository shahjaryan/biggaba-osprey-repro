function jobPath = writeOspreyJobFile(jobPath, J)
% writeOspreyJobFile  Emit an Osprey job file (.m) from a struct.
%
%   Osprey job files are plain MATLAB scripts that assign a set of documented
%   variables. Generating them programmatically keeps the batch reproducible:
%   every job file actually used gets written to disk and can be committed
%   alongside the results, so the exact configuration behind any number is
%   recoverable later. That is the whole point in a reproduction project.
%
%   J fields: seqType, editTarget, dataScenario, files, files_ref, files_w,
%             outputFolder, opts
%
%   UNTESTED against a real Osprey installation.

    fid = fopen(jobPath, 'w');
    if fid == -1
        error('Could not open job file for writing: %s', jobPath);
    end
    closer = onCleanup(@() fclose(fid));

    fprintf(fid, '%% Auto-generated Osprey job file\n');
    fprintf(fid, '%% Generated %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '%% Do not edit by hand - regenerate from the batch script.\n\n');

    % --- sequence information ---
    fprintf(fid, 'seqType = ''%s'';\n', J.seqType);
    fprintf(fid, 'editTarget = %s;\n', cellstr2str(J.editTarget));
    fprintf(fid, 'dataScenario = ''%s'';\n\n', J.dataScenario);

    % --- files ---
    fprintf(fid, 'files = %s;\n', cellstr2str(J.files));

    if isfield(J, 'files_ref') && ~isempty(J.files_ref)
        fprintf(fid, 'files_ref = %s;\n', cellstr2str(J.files_ref));
    end
    if isfield(J, 'files_w') && ~isempty(J.files_w)
        fprintf(fid, 'files_w = %s;\n', cellstr2str(J.files_w));
    end

    fprintf(fid, '\noutputFolder = ''%s'';\n\n', J.outputFolder);

    % --- options ---
    writeOptsStruct(fid, J.opts, 'opts');

end

% -------------------------------------------------------------------------

function writeOptsStruct(fid, s, prefix)
% Recursively emit struct fields as MATLAB assignments.
    fn = fieldnames(s);
    for i = 1:numel(fn)
        v    = s.(fn{i});
        name = sprintf('%s.%s', prefix, fn{i});
        if isstruct(v)
            writeOptsStruct(fid, v, name);
        elseif ischar(v)
            fprintf(fid, '%s = ''%s'';\n', name, v);
        elseif iscell(v)
            fprintf(fid, '%s = %s;\n', name, cellstr2str(v));
        elseif isnumeric(v) || islogical(v)
            if isscalar(v)
                fprintf(fid, '%s = %g;\n', name, v);
            else
                fprintf(fid, '%s = [%s];\n', name, num2str(v(:)', '%g '));
            end
        else
            warning('Skipping unsupported field type for %s', name);
        end
    end
end

% -------------------------------------------------------------------------

function s = cellstr2str(c)
% Render a cell array of strings as MATLAB literal source.
    if isempty(c)
        s = '{}';
        return;
    end
    parts = cellfun(@(x) sprintf('''%s''', x), c, 'UniformOutput', false);
    s = ['{' strjoin(parts, ', ') '}'];
end
