# Data

## Data citation and acknowledgement

This project analyses the **Big GABA** dataset. Its terms require that any use
cite the following, and acknowledge the funding below. If you use this
repository's results, cite these as well as the repository itself.

> Mikkelsen M et al. Big GABA: Edited MR spectroscopy at 24 research sites.
> *NeuroImage* 2017;159:32-45. doi:[10.1016/j.neuroimage.2017.07.021](https://doi.org/10.1016/j.neuroimage.2017.07.021)
>
> Mikkelsen M et al. Big GABA II: Water-referenced edited MR spectroscopy at 25
> research sites. *NeuroImage* 2019;191:537-548. doi:[10.1016/j.neuroimage.2019.02.059](https://doi.org/10.1016/j.neuroimage.2019.02.059)
>
> Povazan M et al. Comparison of multivendor single-voxel MR spectroscopy data
> acquired in healthy brain at 26 sites. *Radiology* 2020;295:171-180.
> doi:[10.1148/radiol.2020191037](https://doi.org/10.1148/radiol.2020191037)

**Acknowledgement:** this work uses data supported by NIH grant **R01 EB016089**.

---

Data are **not** committed. Download them here.

## Source

Big GABA, NITRC: https://www.nitrc.org/projects/biggaba/

A free NITRC account is likely required to download (unverified — check).

## What to get

Only the **MEGA-PRESS** packages (`*_MP`), ~3.5 GB total. Skip the PRESS packages
(short-TE, out of scope for this reproduction).

Also grab the two small files under "Additional data":

- `demographics.csv` (~5 KB)
- `voxel_tissue_fractions.csv` (~9 KB) — not needed for the primary GABA+/Cr
  analysis, but required if the water-referenced extension is attempted later

## Which sites

**In scope (24 sites, matching Mikkelsen 2017):**

- `G1_MP` … `G8_MP` (GE, 91 participants)
- `P1_MP` … `P9_MP` (Philips, 104 participants)
- `S1_MP` … `S7_MP` (Siemens, 77 participants)

**Do NOT download / do not include:** `P10_MP`, `S8_MP`.

These sites were added to the repository after the 2017 paper. Including them means
comparing a different sample against the published numbers, which invalidates the
reproduction silently — the code will run fine and give wrong answers.

## Smoke test first

Download **one** site before the rest. `S5_P` and `P10_P` are among the smallest
listed packages; pick a small MEGA-PRESS one, unzip it, and look at the actual
folder structure — the internal layout of these archives has not been verified and
the batch script's file-discovery logic assumes a layout that may be wrong.

Then run `matlab/smoke_test.m`.

## Expected layout

The scripts assume:

```
data/
  G1/ ... G8/
  P1/ ... P9/
  S1/ ... S7/
```

with per-subject files inside. Expected extensions:

| Vendor | Metabolite file | Water reference |
|---|---|---|
| GE | `.7` (P-file) | embedded in the P-file |
| Philips | `.sdat` (+ `.spar`) | separate file |
| Siemens | `.dat` (TWIX) | separate file |

If the archives unpack differently, fix `extByVendor` and the `dir()` globbing in
`matlab/run_osprey_batch.m` rather than reshuffling the data by hand — the script
should document the real layout.

## Acquisition parameters (for reference)

- TR 2000 ms, TE 68 ms
- 320 averages (160 ON / 160 OFF)
- Medial parietal voxel, 30 × 30 × 30 mm³
- ~10 min scan
