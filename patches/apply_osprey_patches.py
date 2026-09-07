#!/usr/bin/env python3
"""
Apply the nDatasets indexing fix to a local Osprey clone.

WHY THIS EXISTS
---------------
Osprey promotes MRSCont.nDatasets from a scalar to a 1x2 vector
[nSubjects, nExperiments] in OspreyLoad.m:126. Roughly 50 loops across the
repository still apply the colon operator to the bare value:

    for kk = 1 : MRSCont.nDatasets        % 1 : [1 1]  -> error

On older MATLAB this produced a WARNING and silently used the first element,
which happens to be correct. Recent MATLAB (confirmed on R2026a) makes it a
hard error, so the latent bug becomes fatal on upgrade.

SAFETY
------
Rewriting `MRSCont.nDatasets` to `MRSCont.nDatasets(1)` inside a colon is safe
whether nDatasets is a vector or a scalar: in MATLAB, x(1) on a scalar returns
the scalar. So this cannot change behaviour where the code already worked - it
only replaces an error (or a warning-and-guess) with the explicit intent.

USAGE
-----
    python3 apply_osprey_patches.py <path-to-osprey>          # apply
    python3 apply_osprey_patches.py <path-to-osprey> --check  # report only

Idempotent: running twice changes nothing. Writes patch_manifest.txt recording
every file and line touched, which is the record the writeup cites.
"""
import sys, os, re, io, datetime

PATTERN = re.compile(r'(\d+\s*:\s*)(MRSCont\.nDatasets)(?!\s*\()')

def main():
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    root = sys.argv[1]
    check_only = '--check' in sys.argv

    if not os.path.isdir(root):
        print(f"ERROR: not a directory: {root}"); sys.exit(1)

    changes = []
    for dirpath, _, files in os.walk(root):
        if os.sep + '.git' in dirpath:
            continue
        for fn in files:
            if not fn.endswith('.m'):
                continue
            path = os.path.join(dirpath, fn)
            try:
                text = io.open(path, encoding='utf-8', errors='surrogateescape').read()
            except Exception:
                continue
            if 'MRSCont.nDatasets' not in text:
                continue

            out, hits = [], []
            for i, line in enumerate(text.split('\n'), start=1):
                new = PATTERN.sub(r'\1\2(1)', line)
                if new != line:
                    hits.append((i, line.strip(), new.strip()))
                out.append(new)

            if hits:
                rel = os.path.relpath(path, root)
                changes.append((rel, hits))
                if not check_only:
                    io.open(path, 'w', encoding='utf-8',
                            errors='surrogateescape').write('\n'.join(out))

    total = sum(len(h) for _, h in changes)
    verb = "WOULD PATCH" if check_only else "PATCHED"
    print(f"\n{verb}: {total} line(s) across {len(changes)} file(s)\n")
    for rel, hits in sorted(changes):
        print(f"  {rel}")
        for ln, old, new in hits:
            print(f"      line {ln}")
            print(f"        - {old}")
            print(f"        + {new}")

    if total == 0:
        print("  (nothing to do - already patched, or a version without the bug)")

    if not check_only and total:
        man = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           'patch_manifest.txt')
        with io.open(man, 'w', encoding='utf-8') as f:
            f.write("Osprey nDatasets indexing patch\n")
            f.write(f"Applied: {datetime.datetime.now().isoformat(timespec='seconds')}\n")
            f.write(f"Target : {os.path.abspath(root)}\n")
            f.write(f"Total  : {total} line(s) in {len(changes)} file(s)\n\n")
            for rel, hits in sorted(changes):
                for ln, old, new in hits:
                    f.write(f"{rel}:{ln}\n  - {old}\n  + {new}\n")
        print(f"\nManifest written: {man}")
        print("Commit that file. It is the record of what was modified.")

if __name__ == '__main__':
    main()
