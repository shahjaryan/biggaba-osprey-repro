# Discrepancy log

The primary deliverable. Every place the reproduction diverged from the published
result, what was investigated, and what the divergence is attributable to.

Entries are appended as they are found, including ones later resolved as user error.
**Do not delete resolved entries.** A log that only contains unresolved problems
misrepresents the process, and the resolved ones are often the most instructive.

---

## Template

### D-00 — short title

- **Observed:** what came out
- **Expected:** what the paper reports
- **Magnitude:** absolute and relative difference
- **Investigated:** what was checked, in order
- **Attributable to:** one of — *data scope* / *preprocessing* / *fitting algorithm* /
  *quantification* / *statistical specification* / *undocumented original choice* /
  *my error* / *unresolved*
- **Resolved:** yes/no; if yes, how
- **Bearing on the headline claim:** does this change the conclusion or not

---

## A note on interpretation

Three outcomes are possible for each target number, and they mean different things:

1. **Reproduces within uncertainty.** The published value falls inside the confidence
   interval of the reproduction. Reportable as a successful reproduction.
2. **Diverges, and the cause is identifiable.** More valuable than (1). The cause is
   the finding.
3. **Diverges, cause not identified.** Report it as unresolved. Do not manufacture an
   explanation, and do not keep adjusting parameters until it matches — that converts
   a reproduction into a fit-to-target exercise and destroys the point of the project.

The failure mode to guard against is (3) quietly becoming (1) through undocumented
parameter tuning. Every parameter change made after seeing results goes in
`analysis-decisions.md` marked post-hoc.

---

## Entries

*(none yet — no data processed)*
### D-01 — Concatenated fitting unavailable; forced to Separate

- **Observed:** Osprey prints "Fitting style was changed to Separate, because
  concatenated modeling is still under development" and overrides the request.
- **Expected:** n/a — this is a tool limitation, not a mismatch with the paper.
- **Investigated:** confirmed in `OspreyJob.m` (MEGA branch): if
  `opts.fit.style == 'Concatenated'` it is silently reset to `'Separate'`.
- **Attributable to:** fitting algorithm — capability not present in this Osprey version.
- **Resolved:** yes. Job files now request `'Separate'` explicitly so the
  configuration on disk matches what actually ran. Silent overrides are exactly
  what makes a configuration file untrustworthy later.
- **Bearing on the headline claim:** unknown but plausibly relevant. Gannet fits
  the DIFF spectrum directly; Osprey fitting sub-spectra separately is a genuine
  methodological difference that cannot be eliminated. Must be stated in the
  writeup as a floor on achievable equivalence.

### D-02 — `opts.fit.coMM3` requires an undocumented companion field

- **Observed:** `Unrecognized field name "FWHMcoMM3"` at `OspreyJob.m:564`.
- **Investigated:** the MEGA branch does
  `if isfield(opts.fit,'coMM3') -> MRSCont.opts.fit.FWHMcoMM3 = opts.fit.FWHMcoMM3;`
  reading the field without checking it exists. Setting `coMM3` therefore
  *requires* also setting `FWHMcoMM3`. Osprey's own default is 14 Hz
  (`OspreySettings.m:48`, and every bundled MEGA example job file).
- **Attributable to:** my error (incomplete job spec), surfacing an Osprey bug.
- **Resolved:** yes — `opts.fit.FWHMcoMM3 = 14`, matching Osprey's default.
- **Bearing on the headline claim:** none directly, but note 14 Hz is now a fixed
  analysis parameter that was never consciously chosen. It belongs in the MM3
  sensitivity analysis.

### D-03 — Dataset contains two TEs; only TE 68 is the GABA+ target

- **Observed:** every subject has `*_68.dat` and `*_80.dat` plus `_H2O`
  references for each. Initial discovery logic would have taken all of them.
- **Investigated:** TE 68 ms is the GABA+ acquisition; TE 80 ms is the
  MM-suppressed GABA acquisition. These are separate measures with separate
  published values (GABA+ CV 12%, MM-suppressed reported separately).
- **Attributable to:** my error — file discovery was not TE-aware.
- **Resolved:** yes. Both scripts now filter explicitly on TE 68 and refuse to
  process a site where no filename matches, rather than falling back silently.
- **Bearing on the headline claim:** would have been severe and invisible —
  doubling apparent n and averaging two different quantities into one mean that
  still looked plausible. This is the single most dangerous bug found so far.

### D-04 — Osprey requires undocumented toolboxes

- **Observed:** `Undefined function 'hilbert'` inside `op_robustSpecReg`
  (`BaselineModeling` line 515) during `OspreyProcess`. Earlier,
  `Unable to resolve the name 'uix.Panel'` in the PDF export path.
- **Investigated:** Osprey's documentation lists two mandatory toolboxes
  (Optimization, Statistics and Machine Learning). Actual requirements include
  at least Signal Processing (`hilbert`, used by robust spectral registration)
  and, for PDF export, the GUI Layout Toolbox (`uix.*`, a File Exchange package
  Osprey does not bundle).
- **Attributable to:** environment, not data or algorithm.
- **Resolved:** Signal Processing Toolbox installed; PDF export disabled in
  favour of purpose-built QC plotting.
- **Bearing on the headline claim:** none directly. Recorded because it is a
  reproducibility finding in its own right: a reader attempting to re-run this
  pipeline from Osprey's documented requirements alone would fail twice before
  reaching any data. `matlab/check_toolboxes.m` performs a static dependency
  scan so the real requirement list is stated explicitly in this repo.

### D-05 — Osprey bug: `OspreyProcess.m:783` indexes a vector as a scalar

- **Observed:** `Colon operands must be real scalars` at `OspreyProcess.m:783`,
  *after* all spectral processing completed successfully (28.4 s elapsed).
- **Investigated:** `MRSCont.nDatasets` is promoted from scalar to a 1x2 vector
  `[nSubjects, nExperiments]` at `OspreyLoad.m:126`. Line 783 applies a colon to
  the whole vector. Lines 49, 50, 794 and 799 of the same file all use the
  indexed form; line 794 is the identical loop pattern eleven lines later.
- **Attributable to:** upstream tool bug (Osprey 2.9.6, develop branch).
- **Resolved:** yes — patched to `MRSCont.nDatasets(1)`. Full rationale and diff
  in `patches/osprey-nDatasets-line783.md`.
- **Bearing on the headline claim:** none. The affected block runs after
  processing and only populates `MRSCont.info` metadata; no spectral values are
  touched.
- **Consequence for reproducibility:** this project now runs a MODIFIED Osprey.
  That must be stated in the writeup, and the patch file is the record of it.

### D-06 — `nDatasets` indexing bug is repo-wide, not a single line

- **Observed:** after patching `OspreyProcess.m:783`, the identical error
  reappeared at `osp_saveNII.m:41`, then would have recurred throughout.
- **Investigated:** a repo-wide search for a colon applied to bare
  `MRSCont.nDatasets` returns **49 occurrences across 21 files**, including
  `osp_fitInitialise.m` (521, 535) and `osp_extract_minmax_fit.m` (66), both of
  which lie on the single-voxel MEGA fitting path this project uses.
- **Root cause:** `nDatasets` was migrated from scalar to `[nSubjects, nExperiments]`
  (set at `OspreyLoad.m:126`) without updating the loops that consume it.
- **Why it went unnoticed upstream:** `1:[1 1]` was historically a *warning* in
  MATLAB that silently used the first element — which is the correct value. The
  bug was therefore invisible and harmless until MATLAB promoted it to an error.
  Confirmed failing on R2026a.
- **Attributable to:** upstream tool bug.
- **Resolved:** yes, via `patches/apply_osprey_patches.py` — idempotent, dry-run
  capable, and emits `patches/patch_manifest.txt` listing every file and line.
- **Safety argument:** `x(1)` on a scalar returns the scalar in MATLAB, so the
  rewrite cannot alter behaviour anywhere the code already worked. It replaces
  an error (or a warning-and-guess) with the explicit intent.
- **Bearing on the headline claim:** none on the numbers. Substantial for
  reproducibility: this analysis requires a patched Osprey, and the patch script
  plus manifest are what make that reproducible by someone else.
- **Also:** `opts.saveNII` was left at its default and enabled a NIfTI-MRS export
  this project does not need. Now explicitly 0. Preferring to disable an unused
  code path over patching it is the better move where both are available.

### D-07 — Fit range differs substantially from the original

- **Observed:** Osprey ran at its default `opts.fit.range = [0.2 4.2]`
  (`OspreySettings.m:42`); the job file did not set it.
- **Expected:** Gannet fit the difference spectrum over **2.79–4.10 ppm**.
- **Consequence:** Osprey models the entire lipid/macromolecule region and the
  large NAA subtraction artifact near 2.0 ppm, with a flexible spline baseline
  spanning all of it. Gannet excludes that territory by construction. The two
  algorithms are solving visibly different problems on identical data — clearly
  seen in the diff1 QC plot, where the largest features in Osprey's fit range
  lie outside Gannet's entirely.
- **Attributable to:** analysis choice (mine, by omission — the default was
  accepted rather than chosen).
- **Resolved:** no. Elevated to the primary sensitivity analysis: run at
  Osprey's default AND at Gannet's 2.79–4.10, report both.
- **Bearing on the headline claim:** potentially large. This is currently the
  leading candidate explanation for any divergence in absolute values.

### D-08 — "GABA+" is not the same construct in the two packages

- **Observed:** first dataset gives GABAplus/tCr = 0.3141 against a published
  GABA+/Cr of 0.116 — a factor of ~2.7.
- **Investigated:** Osprey's output satisfies exactly
  `GABA (0.0849) + MM09 (0.2292) = GABAplus (0.3141)`. With
  `coMM3 = '3to2MM'` — documented in `osp_addDiffMMPeaks.m` as "3:2 MM09 and
  co-edited MM3 model" — the co-edited MM3 at 3.0 ppm is tied to MM09 by a fixed
  ratio. Macromolecule therefore accounts for ~73% of GABAplus here.
  Gannet instead fits a single three-Gaussian to the whole 3.0 ppm peak and
  references a Lorentzian Cr fit from the OFF spectrum, with its own proton
  scaling.
- **Attributable to:** definitional difference between packages, NOT (yet) a
  disagreement about the data.
- **Resolved:** no. **Do not compare absolute values until this is settled.**
- **Workaround adopted:** coefficient of variation is scale-invariant, so
  published CVs (whole-dataset 12.0%, mean within-site 9.5%) can be compared
  without first resolving the normalization. CV is therefore the first
  reproduction target.
- **Bearing on the headline claim:** central. Reporting a 2.7x difference as a
  finding without resolving this would be the single worst error available in
  this project.
