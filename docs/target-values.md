# Target values

Every number this project attempts to reproduce, with its source. Fill in the
"Osprey" and "Δ" columns as results arrive. Do not edit the published column.

Source: Mikkelsen, M., et al. (2017). Big GABA: Edited MR spectroscopy at 24 research
sites. *NeuroImage*, 159, 32–45.

---

## Primary target — GABA+/Cr

| Quantity | Published (Gannet) | Osprey | Δ | Notes |
|---|---|---|---|---|
| GABA+/Cr, overall mean ± SD | 0.116 ± 0.014 | | | |
| GABA+/Cr, GE | 0.123 ± 0.014 | | | |
| GABA+/Cr, Philips | 0.111 ± 0.013 | | | |
| GABA+/Cr, Siemens | 0.116 ± 0.012 | | | |

Craven et al. 2022 reports Osprey giving ~28% lower estimates on Siemens data
specifically. The Siemens row is therefore the pre-registered place to look for
the largest divergence.

## Variability

| Quantity | Published | Osprey | Δ |
|---|---|---|---|
| Whole-dataset CV | 12.0% | | |
| Mean within-site CV | 9.5% | | |
| CV, GE | 11.5% | | |
| CV, Philips | 11.6% | | |
| CV, Siemens | 10.7% | | |

## Variance decomposition

| Level | Published | Osprey | Δ |
|---|---|---|---|
| Participants within site | 72% | | |
| Site | 20% | | |
| Vendor | 8% | | |

## Data quality metrics

These are diagnostic rather than target values — they indicate whether the
preprocessing is behaving comparably, independent of the fitting.

| Metric | Published | Osprey | Notes |
|---|---|---|---|
| GABA+ fit error | 5–6% | | Osprey reports its own fit error; definitions may differ — check before comparing |
| NAA linewidth | 8.10 Hz | | |
| NAA SNR | 447 | | |
| GABA SNR | 25 | | |

**Caution:** SNR and fit error are *not* defined identically across MRS software.
A mismatch here may be a definitional difference rather than a processing difference.
Verify the definition in each tool's source before recording a discrepancy.

## Sample

| Quantity | Published | Reproduced |
|---|---|---|
| Sites | 24 (G1–G8, P1–P9, S1–S7) | |
| Participants | 272 | |
| GE / Philips / Siemens | 91 / 104 / 77 | |
| GABA+ datasets excluded | 7 (3%) | |

Exclusion reason given in the paper: "primarily due to lipid contamination or
excessive frequency offsets." The paper does not enumerate *which* seven. This is a
known unreproducible judgment call — see `analysis-decisions.md`.

---

## Secondary / out of scope for now

- MM-suppressed GABA (19 datasets excluded in the original, 7%). Deliberately excluded
  from the primary target to avoid scope creep.
- Water-referenced GABA+/H₂O. Possible extension using the repository's
  `voxel_tissue_fractions.csv`.

---

## Sample — PUBLISHED vs ACHIEVABLE

See D-13. The public MEGA-PRESS release does not contain the published sample.
Six sites analysed in Mikkelsen 2017 are absent entirely (G2, G3, P2, S2, S4, S7)
and two present sites postdate it (P10, S8).

| | published (2017) | achievable |
|---|---|---|
| sites | 24 | **17** (18 available, S3 unreadable - D-18) |
| subjects | 272 | **192** |
| GE | 91 (G1-G8) | 67 (G1, G4, G5, G6, G7, G8) |
| Philips | 104 (P1-P9) | 89 (P1, P3, P4, P5, P6, P7, P8, P9) |
| Siemens | 77 (S1-S7) | 36 (S1, S5, S6 - S3 excluded, D-18) |

**Every comparison below is computed on a different, smaller sample than the
published figures. This caveat cannot be removed and must appear in the writeup.**

It bites hardest on the variance decomposition: site accounts for 20% of total
variance in the published analysis, so a 24-site and an 18-site decomposition are
not the same quantity. Treat that target as the weakest of the three.

It also bites on Siemens specifically — 4 sites out of 7, the vendor arm carrying
the D-14 finding.

### Pre-processing checks (run 00_verify_sample.R)

| check | expected | observed |
|---|---|---|
| subjects in demographics.csv | 228 (all 20 released sites) | 228 |
| subjects in scope | 192 | 192 |
| sites in scope | 17 | 17 |
| GE / Philips / Siemens | 67 / 89 / 36 | 67 / 89 / 36 |
| P10 or S8 present in results? | No | |
| age balanced across vendors? | — | |
| sex balanced across vendors? | — | Siemens 38F/22M vs ~50:50 others (D-13) |

## Phase 2 targets — Big GABA II (water-referenced)

DO NOT START until Phase 1 is complete. Recorded here so the scope is known.

Source: Mikkelsen, M., et al. (2019). Big GABA II: Water-referenced edited MR
spectroscopy at 25 research sites. *NeuroImage*, 191, 537-548.

Note this is a **different sample again** — 284 volunteers, 25 sites — so the site
scoping must be re-derived rather than reused from Phase 1.

| Quantity | Published | Osprey | Notes |
|---|---|---|---|
| GABA+ cohort-wide CV | 17% | | vs 12% creatine-referenced in 2017 |
| GABA+ within-site CV | 10% | | vs 9.5% creatine-referenced |
| MM-suppressed GABA cohort CV | 29% | | |
| MM-suppressed within-site CV | 19% | | |
| Variance explained by vendor (GABA+) | 53% | | **vs 8% in the 2017 paper** |
| Variance explained by site (MM-supp.) | 54% | | |

The vendor contrast — 8% under creatine referencing, 53% under water referencing on
overlapping data — is the single most interesting number in this project. If it
replicates, the headline finding is that the choice of concentration reference
reorganizes the variance structure of the measurement.
