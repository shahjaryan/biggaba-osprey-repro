# Patch: OspreyProcess.m line 783

**Applies to:** Osprey reporting version 2.9.6, `develop` branch,
`git describe` = `v.2.6.0-130-g98b2e35`

**Symptom**

```
Error using :
Colon operands must be real scalars.
Error in OspreyProcess (line 783)
for kk = 1 : MRSCont.nDatasets
```

Occurs after processing completes successfully, in the block that gathers
metadata from the processed spectra.

**Cause**

`MRSCont.nDatasets` starts life as a scalar (`OspreyJob.m:1018` and
`OspreyLoad.m:114`, both `size(MRSCont.files,2)`), but `OspreyLoad.m:126` then
sets `MRSCont.nDatasets(2) = 1`, promoting it to a 1x2 vector
`[nSubjects, nExperiments]`.

Line 783 was not updated for that change and applies the colon operator to the
whole vector. This is a straightforward missed index, not an ambiguity: every
other loop in the same file uses the indexed form —

- line 49  `for kk = 1:MRSCont.nDatasets(1)`
- line 50  `for ll = 1:MRSCont.nDatasets(2)`
- line 794 `for kk = 1:MRSCont.nDatasets(1)`   <- identical pattern, 11 lines below
- line 799 `for ll = 2:MRSCont.nDatasets(2)`

**Change**

```diff
-    for kk = 1 : MRSCont.nDatasets
+    for kk = 1 : MRSCont.nDatasets(1)
```

**Justification**

The loop body indexes `MRSCont.processed.(SubSpecNames{ss}){1,kk}` — the second
cell dimension, which is the subject dimension. `nDatasets(1)` is therefore the
correct bound, matching line 794 which indexes the same structure the same way.

**Effect on results**

None. This is reached after all signal processing is complete and only populates
`MRSCont.info` metadata. It changes no spectral values.

**Reproducibility note**

This project runs a MODIFIED Osprey. Anyone re-running it needs this patch. The
modification is confined to one line and is recorded here rather than by
vendoring the whole toolbox.

**Upstream**

Worth reporting at https://github.com/schorschinho/osprey/issues — the fix is
unambiguous and the repository is actively maintained.
