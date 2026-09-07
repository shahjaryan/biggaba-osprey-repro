# Reproducing Mikkelsen et al. (2017) with Osprey

An attempt to reproduce the multi-site GABA+ quantification results of the Big GABA
study using a different modelling algorithm than the original.

**Status:** in progress. Nothing here has been validated against real data yet.

---

## The question

[Mikkelsen et al. (2017, *NeuroImage*)](https://doi.org/10.1016/j.neuroimage.2017.07.021)
quantified GABA+ from 272 participants across 24 sites and three scanner vendors,
using **Gannet**. They reported a whole-dataset coefficient of variation of 12.0% and
attributed variance 72% / 20% / 8% to subject-within-site / site / vendor.

This project re-runs the same spectra through **Osprey** and asks:

> How much of the published result survives a change of modelling algorithm alone —
> holding the data, the voxel, and the acquisition completely fixed?

This is not a criticism of either tool. It is a measurement of analytic degrees of
freedom in a domain where the data are unusually well controlled, which makes it a
clean place to ask the question.

### Why there is a prior

[Craven et al. (2022, *NMR in Biomedicine*)](https://doi.org/10.1002/nbm.4702)
compared seven algorithms on this same repository and found:

- ICC across algorithms for GABA+ of only **0.38** (0.44 with the MM3 component modelled)
- Pairwise between-tool correlations typically **r = 0.4–0.6**
- Variance partition coefficients of **33.8% algorithm** / 16.4% site / 6.4% subject /
  4.0% vendor — the choice of software mattered roughly eight times more than the
  scanner vendor
- Specifically, Osprey producing ~28% *lower* estimates on Siemens data

So this reproduction has a falsifiable expectation going in, rather than being an
open-ended fishing trip. If Osprey reproduces Mikkelsen's numbers closely, that
contradicts Craven. If it diverges in the direction and magnitude Craven reports,
that is a successful independent confirmation of a reproducibility problem.

**Both outcomes are publishable-flavoured results. Neither is a failed project.**
This is the reason this particular reproduction was chosen.

---

## Data

Big GABA, hosted on NITRC: https://www.nitrc.org/projects/biggaba/

Only the **MEGA-PRESS** packages are needed (`*_MP`), roughly 3.5 GB total. The PRESS
packages are short-TE data used for other analyses and are out of scope.

### Critical scoping detail

NITRC currently hosts **26 sites** (G1–G8, P1–P10, S1–S8). Mikkelsen 2017 analysed
**24** (G1–G8, P1–P9, S1–S7, n=272). The repository grew after publication.

**P10 and S8 must be excluded** or the reproduction is comparing against a different
sample than the paper. This is the single easiest way to silently get wrong numbers.

Site prefixes are **vendor** codes, not subject codes:

| Prefix | Vendor | Sites in paper | Participants |
|---|---|---|---|
| G | GE | G1–G8 | 91 |
| P | Philips | P1–P9 | 104 |
| S | Siemens | S1–S7 | 77 |

Data are gitignored. See `data/README.md`.

---

## Why this is cheap to run

The primary published measure is **GABA+/Cr** — a creatine ratio. Creatine referencing
requires no tissue segmentation and no structural images, so the entire SPM12
coregistration and segmentation path is skipped. No FreeSurfer. No fMRIPrep.

Practical consequence: this runs on a laptop in hours, not a cluster in weeks.

(Water-referenced GABA+/H₂O *would* need tissue fractions — but the repository ships
`voxel_tissue_fractions.csv`, so even that can be done without running segmentation
locally. It is a possible extension, not part of the primary target.)

---

## Repository layout

```
matlab/
  smoke_test.m              # START HERE — one dataset, end to end
  jobBigGABA_template.m     # Osprey job file template
  build_joblist.m           # scan data dir, emit per-site job files
  run_osprey_batch.m        # loop sites, run pipeline, export results
R/
  01_load_osprey_output.R   # read Osprey exports into a tidy frame
  02_reproduce_headline.R   # the published numbers, side by side
  03_variance_decomposition.R  # multilevel model, 72/20/8 target
docs/
  target-values.md          # every number being reproduced, with source
  analysis-decisions.md     # every judgment call and its rationale
  discrepancy-log.md        # where it diverged and why  <- the real deliverable
```

`docs/discrepancy-log.md` is the point of the project. The code is in service of it.

---

## Order of operations

1. **Smoke test on one dataset before downloading everything.** Pull a single small
   site, run `matlab/smoke_test.m`, confirm a plausible GABA+/Cr number comes out.
   Nothing else matters until this works.
2. Download the remaining 22 in-scope sites.
3. Batch process. Log every exclusion.
4. Reproduce the headline table in R.
5. Variance decomposition.
6. Write up, discrepancy log first.

---

## Software requirements

- MATLAB R2017a or newer (R2019a+ for the GUI)
- Optimization Toolbox **and** Statistics and Machine Learning Toolbox (both mandatory)
- Osprey: https://github.com/schorschinho/osprey
- SPM12 — only needed for coregistration/segmentation, which this project skips.
  Install it anyway if convenient; on Apple Silicon use the GitHub development
  version, as the official release lacks compatible C binaries.

---

## Honest status of the code in this repo

The MATLAB and R files here are **untested scaffolding**. They were written against
the Osprey documentation, not against a working installation, and no Big GABA data has
been processed. Field names follow the published job-file specification but the scripts
have never been executed. Expect to fix them. Treat them as a starting structure,
not as working code.

## License

MIT (code). The Big GABA data carry their own terms — see NITRC.
