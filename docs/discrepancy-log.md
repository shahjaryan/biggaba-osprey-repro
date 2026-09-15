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

### D-09 — GABA / co-edited MM partition is degenerate (site S1, n=12)

- **Observed:** Osprey's `GABA` estimate collapses to ~0 in 7 of 12 subjects
  (0.0000, 0.0002, 0.0009, 0.0078, 0.0111, 0.0131, 0.0147) while `MM09` absorbs
  the corresponding signal. In one subject (#5) the partition flips: GABA 0.2047,
  MM09 0.0982.
- **Diagnostic pattern:** the SUM is stable while its COMPONENTS are not.

  | quantity | mean | SD | CV |
  |---|---|---|---|
  | GABAplus | 0.2789 | 0.0371 | 13.3% |
  | GABA     | 0.0540 | 0.0699 | 129.3% |
  | MM09     | 0.2249 | 0.0549 | 24.4% |
  | Glx      | 1.6341 | 0.1378 | 8.4% |

  A well-determined total with an ill-determined split is the signature of
  collinearity between the two basis functions.
- **Mechanism:** GABA and co-edited MM3 both sit at ~3.0 ppm and overlap heavily.
  At 3T with standard MEGA-PRESS they are not separable — which is precisely why
  the literature reports "GABA+" rather than GABA. Consistent with the large
  number of "Positive dir derivative in projection / Using the backtracking step"
  messages during fitting: the optimizer traversing a flat valley.
- **Attributable to:** a known physical limitation of the acquisition, surfaced by
  Osprey's attempt to model the two components separately. NOT a defect.
- **Consequences:**
  1. **`GABAplus` is the only comparable quantity.** Any analysis using Osprey's
     `GABA` column would report numerical noise. Locked.
  2. `opts.fit.coMM3` is directly implicated (the '3to2MM' constraint ties MM3co
     to MM09). This raises the priority of the MM3 sensitivity analysis.
  3. Plausibly a contributor to Craven et al.'s ICC of 0.38 across algorithms —
     if the GABA/MM split is under-determined, different algorithms will resolve
     it differently while all fitting the data comparably well.
- **Bearing on the headline claim:** significant, and possibly the most
  interesting result available. If the total is reproducible while the
  partition is not, that is a precise and useful statement about what
  edited MRS at 3T can and cannot measure.

### D-10 — Water reference fit is ill-conditioned in all 12 datasets

- **Observed:** every water fit reports `Df(x)` = NaN, `relDf(x)` = NaN,
  `rho` = NaN, largest eigenvalue ~1e11-6e11, lambda 1e5-1e7, terminating on
  "absolute step size".
- **Attributable to:** unknown; systematic rather than dataset-specific.
- **Bearing:** none on Phase 1 (creatine-referenced). **Blocking for Phase 2**
  (water-referenced, Big GABA II targets). Must be understood before that work
  begins.

### D-11 — Site S1 within-site CV vs published

- **Observed:** GABAplus/tCr CV = 13.3% (n=12, Siemens site S1).
- **Published:** mean within-site CV 9.5%; whole-dataset CV 12.0%.
- **Status:** NOT yet a discrepancy. 9.5% is a mean across 24 sites; individual
  site CVs vary around it, and a single site cannot be compared to that average.
  Revisit once several sites are processed.
- **Note:** CV is scale-invariant, so this comparison is valid even though the
  absolute GABAplus/tCr scale is not yet reconciled with Gannet's GABA+/Cr (D-08).

### D-12 — Vendor difference is far larger in Osprey than in Gannet (PRELIMINARY)

**Status: SIGNAL, NOT RESULT. One site per vendor. Do not cite this yet.**

- **Observed:**

  | site | vendor | n | GABAplus/tCr | SD | CV | GABA collapsed to ~0 |
  |---|---|---|---|---|---|---|
  | G1 | GE      |  7 | 0.3983 | 0.0648 | 16.3% | 0/7 |
  | S1 | Siemens | 12 | 0.2789 | 0.0371 | 13.3% | 7/12 |

- **Key comparison (scale-invariant, so unaffected by D-08):**
  - Observed GE/Siemens ratio  = **1.428** (Siemens 30% below GE)
  - Published GE/Siemens ratio = **1.060** (Siemens 5.7% below GE)
  - Excess Siemens-lowness in Osprey ≈ **26%**

- **Relation to the pre-specified prediction:** Craven et al. (2022) report Osprey
  giving ~28% lower estimates on Siemens data. That figure was recorded in
  `docs/target-values.md` BEFORE any data was processed. The observed ~26% is
  close to it.

- **Why this cannot yet be claimed:**
  1. n=7 and n=12, one site per vendor. In the published decomposition, site
     accounts for 20% of variance vs 8% for vendor — a single site is a poor
     estimate of its vendor and site effects alone could produce this.
  2. The GABA/MM degeneracy (D-09) differs sharply by vendor: 0/7 collapsed in
     GE vs 7/12 in Siemens. That difference in fit behaviour may be driving the
     means rather than any vendor effect on GABA+ itself.
  3. Both within-site CVs (16.3%, 13.3%) exceed the published 9.5%, suggesting
     this pipeline is noisier than the original irrespective of vendor.

- **What would settle it:** 2-3 GE sites and 3-4 Siemens sites, to separate the
  vendor effect from site-level variance. This is the next experiment.

- **Bearing on the headline claim:** potentially central. If it survives more
  sites, it is an independent confirmation of an algorithm effect via a
  different route, against a prediction registered in advance.

### D-13 — The published sample is not available; 6 of 24 sites are missing

**Confirmed by two independent sources.**

- **Observed:** `demographics.csv` contains 228 subjects across 20 sites. The
  NITRC MEGA-PRESS package lists exactly 20 releases. The two agree exactly.
- **Published sample:** 272 subjects, 24 sites (G1-G8, P1-P9, S1-S7).

  | vendor | available | published | diff |
  |---|---|---|---|
  | GE      |  67 |  91 | -24 |
  | Philips | 101 | 104 |  -3 |
  | Siemens |  60 |  77 | -17 |
  | total   | 228 | 272 | -44 |

- **Absent from the public release:** `G2, G3, P2, S2, S4, S7`
- **Present but postdating the paper (out of scope):** `P10, S8`

- **Achievable scope for this reproduction — 18 sites, 204 subjects:**
  - GE      (6 sites): G1, G4, G5, G6, G7, G8 — 67 subjects
  - Philips (8 sites): P1, P3, P4, P5, P6, P7, P8, P9 — 89 subjects
  - Siemens (4 sites): S1, S3, S5, S6 — 48 subjects

- **Consequences:**
  1. The exact published sample **cannot be reconstructed**. Every comparison
     must state that it is computed on a different, smaller sample.
  2. Whole-dataset CV (12.0%) and the variance decomposition (72/20/8) were
     computed on 272 subjects / 24 sites. Site-level variance in particular is
     sensitive to which sites are included, so the decomposition comparison is
     the weakest of the planned targets.
  3. Siemens falls from 7 sites to 4, making it the least well-estimated vendor —
     directly relevant to D-12, where the Siemens comparison carries the most
     weight.
  4. Siemens sex ratio is imbalanced in the available data (38F/22M) relative to
     roughly 50/50 for GE and Philips.

- **Attributable to:** data availability, not analysis.
- **Bearing on the headline claim:** substantial, and a reportable finding in its
  own right — a widely cited multi-site study whose underlying data is no longer
  fully available in the form analysed. Any absolute comparison to the published
  numbers now carries a sample-composition caveat that cannot be removed.

- **Note:** several releases (S1, S3, S6, S8, G1, G4, G5) are distributed as
  external URLs rather than NITRC-hosted zips, which is a link-rot risk. S1 and
  G1 resolved successfully as of 2026-09-07.

### D-14 — Three vendors: anomaly is Siemens-specific, matching the pre-registered prediction

**Status: STRONG SIGNAL. Still one site per vendor. Not yet a result.**

- **Observed (one site per vendor):**

  | site | vendor | n | GABAplus/tCr | CV | GABA collapsed |
  |---|---|---|---|---|---|
  | G1 | GE      |  7 | 0.3983 | 16.3% | 0/7 |
  | P1 | Philips |  9 | 0.3813 |  8.2% | 0/9 |
  | S1 | Siemens | 12 | 0.2789 | 13.3% | 7/12 |

- **Ordering:** observed GE > Philips > Siemens; published GE > Siemens > Philips.
  **Does not match** — Siemens moves from middle to last.

- **Pairwise ratios (scale-invariant, so unaffected by D-08):**

  | pair | observed | published |
  |---|---|---|
  | GE / Philips     | 1.045 | 1.108 |
  | GE / Siemens     | 1.428 | 1.060 |
  | Siemens / Philips| 0.732 | 1.045 |

- **The key structure:** GE and Philips reproduce the published relationship
  closely (1.045 vs 1.108). This acts as a control: the pipeline is not
  generically inflating vendor differences. The entire anomaly is Siemens.

- **Magnitude, against the mean of the other two vendors:**
  - observed  Siemens / mean(GE, Philips) = 0.716
  - published Siemens / mean(GE, Philips) = 0.991
  - **Siemens runs 27.8% low.**

- **Pre-registered prediction:** Craven et al. (2022) report Osprey giving ~28%
  lower estimates on Siemens data. Recorded in `docs/target-values.md` before any
  processing. Observed 27.8%.

- **Candidate mechanism:** the GABA/MM partition degeneracy (D-09) is ALSO
  Siemens-specific — 7/12 collapsed in Siemens vs 0/7 GE and 0/9 Philips. These
  are likely the same phenomenon. Establishing the link is the most valuable open
  question in the project.

- **Secondary observation:** Philips within-site CV of 8.2% is close to the
  published mean within-site CV of 9.5% — a clean reproduction of a published
  variability figure. GE (16.3%) and Siemens (13.3%) are both high.

- **Caveats that still stand:**
  1. One site per vendor (n=7/9/12). Could be site-level rather than vendor-level.
  2. Per D-13, only 4 Siemens sites exist in the public release, so the Siemens
     arm will remain the least well-estimated regardless.
  3. Site accounts for 20% of variance vs 8% for vendor in the published
     decomposition — a single site is a weak vendor estimate by construction.

- **Next experiment:** all 18 available in-scope sites. That is what converts this
  from signal to result, and it is roughly six hours of unattended compute.


### D-15 — Documented acquisition error at S6; providers' workaround adopted

- **Source:** `Important_Notes.pdf`, Big GABA release (NITRC), the only note in
  the file.
- **Issue:** at site S6, water suppression was mistakenly left on when acquiring
  the GABA+ water references, so `*GABA_68_H2O` is unusable for subjects
  **S01-S06** (6 of 12 subjects at that site).
- **Providers' recommendation:** substitute the MM-suppressed water reference
  `*GABA_80_H2O`, the echo times being equivalent (TE = 68 ms).
- **Decision:** follow the recommendation. A reproduction should honour the data
  provider's documented guidance rather than invent its own remedy. Implemented
  as a site- and subject-specific exception in `run_osprey_batch.m`, which logs
  each substitution as it happens.
- **Alternatives considered and rejected:**
  - *Ratio-only for S6* — would lose eddy-current correction for all 12 subjects,
    making S6 processed differently from every other site regardless.
  - *Exclude S6 entirely* — would reduce Siemens from 4 sites to 3, and Siemens
    is already the weakest arm (D-13) and the one carrying D-14.
- **Why this matters beyond bookkeeping:** Osprey uses `files_ref` for
  eddy-current correction and lineshape referencing during PROCESSING, upstream
  of quantification. A corrupted water reference can therefore distort the
  processed spectra even for creatine-referenced results, which do not use water
  scaling. **Unverified:** how much ECC actually moves GABAplus/tCr. Worth
  measuring directly by processing S6 both ways.
- **Related correction:** the `_68`/`_80` filename suffixes denote acquisition
  type, not literal echo time. Mikkelsen 2017 reports MM-suppressed TE as 80 ms
  for GE/Philips but 68 ms for Siemens, and this note confirms TE 68 for the
  `_80` files at S6. Code comments describing a "TE filter" have been corrected;
  the filter's behaviour (select GABA+, exclude MM-suppressed) is unchanged.
- **Bearing on the headline claim:** moderate. Affects 6 of 48 Siemens subjects,
  in the vendor arm carrying the main finding.

---

# FULL RUN — 17 sites, 192 subjects (2026-09-14)

### D-16 — Siemens effect CONFIRMED across three independent sites

**This is now a result, not a signal.**

| vendor | sites | n | GABAplus/tCr | between-site CV |
|---|---|---|---|---|
| GE      | 6 | 67 | 0.3764 | 6.2% |
| Philips | 8 | 89 | 0.3688 | 18.4% |
| Siemens | 3 | 36 | **0.2703** | **2.8%** |

Siemens site means: S1 0.2789, S5 0.2641, S6 0.2679. A between-site CV of 2.8%
means the three sites agree with each other far more closely than GE's six do —
this is not one anomalous site.

**Magnitude vs the pre-registered prediction:**

| | observed | published | Siemens runs |
|---|---|---|---|
| Siemens / mean(GE, Philips), all sites | 0.726 | 0.991 | **26.8% low** |
| same, excluding the P3 outlier (D-17)  | 0.749 | 0.991 | **24.4% low** |

Craven et al. (2022) predicted Osprey would give ~28% lower estimates on Siemens
data. That figure was recorded in `target-values.md` before any data was
processed. Observed 24-27% across three independent sites.

**Ordering does not reproduce:** observed GE > Philips > Siemens; published
GE > Siemens > Philips. Siemens moves from middle to last.

**GE vs Philips DOES reproduce** once the P3 outlier is set aside:
GE/Philips = 1.089 observed vs 1.108 published. The anomaly is confined to
Siemens; the pipeline is not generically distorting vendor differences.

**Mechanism — the dissociation is clean:**

| vendor | subjects with GABA collapsed to ~0 |
|---|---|
| Siemens | 28 / 36 (**78%**) |
| GE      |  2 / 67 (3%, all at G6) |
| Philips |  0 / 89 (0%) |

The GABA/co-edited-MM degeneracy (D-09) is almost universal on Siemens and
essentially absent elsewhere. Siemens lowness and Siemens degeneracy co-occur
this cleanly across 17 sites; the most likely reading is that they are the same
phenomenon. **Establishing the causal link is the single most valuable remaining
piece of work.**

**Variability — within-site reproduces, between-site does not:**

| quantity | observed | published |
|---|---|---|
| mean within-site CV | **11.1%** | 9.5% |
| whole-dataset CV | 20.6% (17.3% excl. P3) | 12.0% |

This is itself a clean finding: Osprey preserves the original's *within-site*
precision while roughly doubling *between-site/vendor* spread. That is the
signature of an algorithm effect rather than added noise, and it is consistent
with Craven et al.'s variance partition (algorithm 33.8% vs vendor 4.0%).

**Caveats that remain:**
1. 3 of 7 published Siemens sites (D-13); S3 failed to process (D-18).
2. 192 subjects / 17 sites against the published 272 / 24.
3. Absolute scale still unreconciled with Gannet (D-08). Every comparison above
   is a ratio or a CV, both scale-invariant, so this does not affect them.
4. The P3 exclusion is POST-HOC. Both figures are reported throughout.

### D-17 — P3 is a 5.2 SD outlier among Philips sites

- **Observed:** P3 GABAplus/tCr = 0.5184. The other seven Philips sites span
  0.2803-0.3813 (mean of site means 0.3468). P3 sits **5.2 SD** above them.
- **Effect:** inflates Philips pooled mean 0.3454 -> 0.3688 and Philips
  between-site CV 9.5% -> 18.4%. Excluding it, Philips between-site CV (9.5%)
  matches GE's order of magnitude and GE/Philips lines up with the published
  ratio (1.089 vs 1.108).
- **Status:** UNEXPLAINED. Not yet excluded from the primary analysis; both
  with- and without-P3 figures are reported.
- **Next step:** inspect P3's fits and QM metrics directly. Candidate
  explanations include a genuine site difference, an acquisition difference not
  captured in the metadata, or a systematic fitting failure at that site.
- **Rule:** do not drop P3 merely because removing it improves agreement with
  the published values. That reasoning is how a reproduction becomes a
  fit-to-target exercise. It is excluded only if an independent, documented
  reason is found.

### D-18 — S3 cannot be read by Osprey as distributed; EXCLUDED

- **Observed:** `Index exceeds array bounds` (`MATLAB:badsubscript`) on
  **dataset 1**, before any processing.
- **Stack:** `read_twix_hdr:15` <- `mapVBVD:378` <- `io_loadspec_twix:36`
  <- `osp_LoadTwix:66` <- `OspreyLoad:197`
- **Root cause:** S3 is Siemens **VD** software with a **multi-RAID** TWIX
  container (`Scan 1/2`); S1, S5 and S6 are **VB** (`single RAID file detected`).
  At `read_twix_hdr.m:15`, `bufname = bufname{1}` fails because the preceding
  `regexp(bufname,'^\w*','match')` returned empty - the file pointer was at the
  wrong offset, i.e. the reader mis-navigated the multi-RAID structure. Osprey's
  bundled mapVBVD claims VD support (CHANGELOG: "added support for VD13
  multi-raid files") but fails on these files.
- **Ruled out:** an earlier hypothesis that S3's two file-size groups
  (6 x 186 MB, 6 x 94 MB) caused a mixed-dimension failure. Each group was run
  separately and **both failed identically at the same line**, so the size split
  is incidental (likely channel count) and not the cause.
- **Decision: EXCLUDE S3.** Siemens remains at 3 sites / 36 subjects.
- **Alternatives considered and rejected:**
  - *Convert via spec2nii to NIfTI-MRS* (Osprey reads it natively). Rejected for
    the primary analysis: S3 would then enter through a DIFFERENT input path
    than the other 16 sites, so any difference in its numbers would be
    attributable either to the site or to the conversion, with no way to
    separate them - in the vendor arm carrying the headline finding. Acceptable
    only as an explicitly labelled sensitivity analysis, never pooled.
  - *Update mapVBVD from upstream.* A third modification to the toolchain with
    unknown interactions with Osprey.
- **Reportable finding in its own right:** one of the four available Siemens
  sites cannot be read by the analysis tool as distributed, and the error message
  gives no indication of the cause. A user following the documented path hits a
  hard failure with no diagnostic path forward.
