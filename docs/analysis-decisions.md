# Analysis decisions

Every judgment call, its rationale, and whether it was forced or chosen. Written
*before* seeing results wherever possible, so that the writeup can distinguish
pre-specified choices from post-hoc ones.

Status key: **[LOCKED]** decided in advance · **[OPEN]** not yet decided ·
**[FORCED]** no choice available

---

## The central design decision

The point of this project is to change **one** thing — the modelling algorithm — and
hold everything else as close to the original as possible. Every decision below should
be judged against that: does it isolate the algorithm, or does it introduce a second
difference that will confound the comparison?

Where Osprey cannot be made to match Gannet's behaviour, that is itself a finding and
belongs in the discrepancy log rather than being papered over.

---

## Sample construction

**[LOCKED] Include only G1–G8, P1–P9, S1–S7.**
NITRC now hosts P10 and S8, which postdate the 2017 paper. Including them would
compare a different sample to the published numbers. Excluded.

**[LOCKED] MEGA-PRESS only.**
The PRESS packages are short-TE data serving other analyses. Out of scope.

**[OPEN] Participant-level exclusions.**
The original excluded 7 GABA+ datasets (3%) for "lipid contamination or excessive
frequency offsets" but does not say which. This cannot be reproduced exactly.

Options:
1. Exclude nothing, and report the difference this makes.
2. Apply an explicit, pre-specified quantitative rule and report how many it catches.
3. Report both.

Preference is (3) — run the primary analysis with no exclusions, then repeat under an
explicit rule, and report both alongside the published figure. The gap between them
bounds how much the undocumented exclusion could have mattered. **This is one of the
most interesting discrepancies available in the project and should not be smoothed
over by quietly excluding seven datasets until the numbers match.**

---

## Preprocessing

**[OPEN] Spectral registration method** (`opts.SpecReg`).
Gannet used spectral registration for frequency/phase correction. Osprey offers
`'RobSpecReg'`, `'ProbSpecReg'`, `'RestrSpecReg'`, `'none'`. These are not identical
to Gannet's implementation. `'RobSpecReg'` is the Osprey default and is the closest
philosophical match. Recommend defaulting to it and noting the mismatch rather than
attempting to hand-match Gannet's algorithm — matching it would be a research project
in itself.

**[OPEN] Transient rejection threshold.**
The original rejected ON/OFF pairs whose frequency/phase offset estimates exceeded
3 SD from the mean. Whether Osprey's rejection is equivalent needs checking in source,
not assumed.

**[LOCKED] No eddy-current correction beyond defaults** unless the vendor path
requires it. Deviating here adds a second uncontrolled difference.

---

## Fitting

**[OPEN] `opts.fit.coMM3` — co-edited macromolecule modelling.**
This is the highest-leverage parameter in the project. Craven et al. found ICC across
algorithms of 0.38 *without* the MM3 component and 0.44 *with* it. Options include
`'3to2MM'`, `'1to1GABA'`, `'freeGauss'`, `'fixedGauss'`, `'none'`.

Gannet's three-Gaussian fit over 2.79–4.10 ppm does not map cleanly onto any of these.

Recommend: run the primary analysis at Osprey's default, then run the MM3 variants as
a **specified sensitivity analysis**. Reporting how much the answer moves across MM3
settings is arguably a more valuable result than the primary comparison itself,
because it quantifies a degree of freedom that is usually left unreported in papers.

**[LOCKED] `opts.fit.method = 'Osprey'`.**
Using the LCModel backend would change two things at once.

**[OPEN] `opts.fit.range`.**
Gannet fit the DIFF spectrum over 2.79–4.10 ppm. Osprey's default range differs.
Decide whether to match Gannet's range (isolates the algorithm better) or use Osprey's
default (tests Osprey as it is actually used in practice). These answer different
questions. Recommend Osprey default for the primary, Gannet-matched as a sensitivity
analysis, and say plainly which question each answers.

**[LOCKED] Basis sets from the Osprey package.**
Craven et al. used these, so it keeps the prior comparable.

---

## Quantification

**[LOCKED] GABA+/Cr as the primary outcome.**
Matches the paper's primary measure and requires no tissue segmentation, no structural
images, and no SPM12 segmentation path. This is what makes the project laptop-scale.

**[LOCKED] No tissue correction in the primary analysis.**
Creatine-referenced values in the original were not tissue corrected.

---

## Statistics

**[OPEN] Variance decomposition model.**
The published 72/20/8 split needs a multilevel model with participants nested in sites
nested in vendors. The exact specification is not fully stated in the paper. Whatever
is used must be written down here explicitly, because a different nesting structure
will produce different percentages from identical data — and that would be a
statistical artifact misreported as a reproduction failure.

**[LOCKED] Report effect sizes and intervals, not just point estimates.**
A reproduction that reports only whether numbers "matched" is not informative. The
question is whether the published value falls within the uncertainty of the
reproduction.

---

## Standing rule

If a decision has to be made *after* seeing results, it gets logged here and marked
post-hoc. The credibility of the whole exercise depends on that distinction being
visible.

---

## Supplied CSVs — provenance and use

Two small files ship with the repository. Their roles differ and should not be
conflated.

### demographics.csv — [LOCKED] verification only, not analysis input

Used to confirm sample construction **independently of the imaging data**, before
Osprey runs: 272 participants, 24 sites, 91 GE / 104 Philips / 77 Siemens. This is
the check against two silent failure modes — P10/S8 contamination, and subjects
quietly dropping out when the batch fails to parse a file.

Secondary use: confirming age and sex are balanced across vendors, so that any
observed vendor difference cannot be attributed to demographic imbalance.

Not used as a covariate in the primary analysis. The published headline values are
uncorrected descriptives, and adding covariates would introduce a second difference.

### voxel_tissue_fractions.csv — [FORCED] imported from the original pipeline

Contains GM/WM/CSF fractions **derived by the original authors' segmentation**, not
by this project.

Irrelevant to Phase 1 (GABA+/Cr is a creatine ratio, no tissue correction).

For the Phase 2 water-referenced extension, using this file means **importing a
component of the original pipeline rather than reproducing it**. This is a deliberate
choice: it holds segmentation constant so that the algorithm comparison stays clean.
But it must be stated explicitly in the writeup. A reader will otherwise assume the
segmentation was performed independently, and the reproduction would be overclaiming.

If the water-referenced results diverge, segmentation is *excluded* as an explanation
by construction — which narrows the search for causes usefully, but only if the
provenance is documented.
