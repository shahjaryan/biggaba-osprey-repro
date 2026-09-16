# analyse.R
#
# Regenerates every number reported in this project from the Osprey output
# files. Base R only - no package dependencies - so it runs anywhere without
# an install step.
#
# Usage, from the repository root:
#     Rscript analysis/analyse.R
#
# Reads : results/<site>/QuantifyResults/diff1_tCr_Voxel_1_Basis_1.tsv
#         results/<site>/QM_processed_spectra.tsv
#         results/gannet_range/<site>/... (optional, fit-range sensitivity)
# Writes: results/tables/*.csv
#
# Every figure in README.md and docs/discrepancy-log.md should be reproducible
# from this script. If a number in the documentation does not appear here, it
# is not supported by the data.

# ---------------------------------------------------------------- setup ----

# Locate the repository root: the working directory if it contains results/,
# otherwise its parent (so the script also works when run from analysis/).
repo <- getwd()
if (!dir.exists(file.path(repo, "results")) &&
     dir.exists(file.path(repo, "..", "results"))) {
  repo <- normalizePath(file.path(repo, ".."))
}
if (!dir.exists(file.path(repo, "results"))) {
  stop("Cannot find results/. Run this from the repository root:\n",
       "    Rscript analysis/analyse.R")
}

RESULTS <- file.path(repo, "results")
TABLES  <- file.path(RESULTS, "tables")
dir.create(TABLES, showWarnings = FALSE, recursive = TRUE)
cat(sprintf("repository: %s\n", repo))

# Sites in scope. See docs/discrepancy-log.md D-13 (6 published sites absent
# from the public release) and D-18 (S3 unreadable by Osprey).
SITES <- list(
  GE      = c("G1","G4","G5","G6","G7","G8"),
  Philips = c("P1","P3","P4","P5","P6","P7","P8","P9"),
  Siemens = c("S1","S5","S6")
)

# Mikkelsen et al. (2017) NeuroImage 159:32-45, GABA+/Cr quantified in Gannet.
PUBLISHED <- c(GE = 0.123, Philips = 0.111, Siemens = 0.116)
PUB_WHOLE_CV       <- 12.0
PUB_WITHIN_SITE_CV <- 9.5

# GABA amplitudes at or below this are treated as collapsed to zero: the
# GABA / co-edited-MM partition is degenerate at 3T (D-09).
GABA_ZERO <- 0.02

cvpct <- function(x) 100 * sd(x) / mean(x)

# ----------------------------------------------------------------- read ----

read_site <- function(site, root = RESULTS) {
  f <- file.path(root, site, "QuantifyResults",
                 "diff1_tCr_Voxel_1_Basis_1.tsv")
  if (!file.exists(f)) return(NULL)
  d <- read.delim(f, check.names = FALSE)
  list(GABAplus = as.numeric(d[["GABAplus"]]),
       GABA     = as.numeric(d[["GABA"]]),
       Glx      = as.numeric(d[["Glx"]]))
}

vendor_of <- function(site) {
  for (v in names(SITES)) if (site %in% SITES[[v]]) return(v)
  NA_character_
}

all_sites <- unlist(SITES, use.names = FALSE)
D <- setNames(lapply(all_sites, read_site), all_sites)
missing <- all_sites[vapply(D, is.null, logical(1))]
if (length(missing)) {
  stop("missing results for: ", paste(missing, collapse = ", "),
       "\nRun matlab/run_osprey_batch.m first.")
}

# ------------------------------------------------------- per-site table ----

per_site <- do.call(rbind, lapply(all_sites, function(s) {
  g <- D[[s]]$GABAplus
  data.frame(site = s, vendor = vendor_of(s), n = length(g),
             mean = mean(g), sd = sd(g), cv_pct = cvpct(g),
             gaba_collapsed = sum(D[[s]]$GABA < GABA_ZERO),
             glx_cv_pct = cvpct(D[[s]]$Glx),
             stringsAsFactors = FALSE)
}))

cat("\n===== PER-SITE =====\n")
print(per_site, row.names = FALSE, digits = 4)
write.csv(per_site, file.path(TABLES, "per_site.csv"), row.names = FALSE)

# ----------------------------------------------------- per-vendor table ----

per_vendor <- do.call(rbind, lapply(names(SITES), function(v) {
  ss     <- SITES[[v]]
  pooled <- unlist(lapply(ss, function(s) D[[s]]$GABAplus))
  smeans <- vapply(ss, function(s) mean(D[[s]]$GABAplus), numeric(1))
  nz     <- sum(vapply(ss, function(s) sum(D[[s]]$GABA < GABA_ZERO), numeric(1)))
  data.frame(vendor = v, sites = length(ss), n = length(pooled),
             mean = mean(pooled), sd = sd(pooled),
             pooled_cv_pct = cvpct(pooled),
             between_site_cv_pct = cvpct(smeans),
             gaba_collapsed = nz,
             gaba_collapsed_pct = 100 * nz / length(pooled),
             published_gannet = PUBLISHED[[v]],
             stringsAsFactors = FALSE)
}))

cat("\n===== PER-VENDOR =====\n")
print(per_vendor, row.names = FALSE, digits = 4)
write.csv(per_vendor, file.path(TABLES, "per_vendor.csv"), row.names = FALSE)

# ----------------------------------------------------------- ratios -------
# Ratios and CVs are scale-invariant, so they are valid comparisons even though
# the absolute GABAplus/tCr scale is not reconciled with Gannet's GABA+/Cr
# (D-08). Absolute values must NOT be compared directly.

M <- setNames(per_vendor$mean, per_vendor$vendor)

pairs <- list(c("GE","Siemens"), c("GE","Philips"), c("Siemens","Philips"))
ratios <- do.call(rbind, lapply(pairs, function(p) {
  data.frame(pair = paste(p[1], "/", p[2]),
             observed  = M[[p[1]]] / M[[p[2]]],
             published = PUBLISHED[[p[1]]] / PUBLISHED[[p[2]]],
             stringsAsFactors = FALSE)
}))

cat("\n===== VENDOR RATIOS (scale-invariant) =====\n")
print(ratios, row.names = FALSE, digits = 4)
write.csv(ratios, file.path(TABLES, "vendor_ratios.csv"), row.names = FALSE)

# The headline comparison: Siemens against the mean of the other two vendors.
siem_obs <- M[["Siemens"]] / mean(c(M[["GE"]], M[["Philips"]]))
siem_pub <- PUBLISHED[["Siemens"]] /
            mean(c(PUBLISHED[["GE"]], PUBLISHED[["Philips"]]))

# P3 is a 5.2 SD outlier that four tested hypotheses failed to explain (D-17).
# It is RETAINED in the primary analysis; both figures are reported.
ph_noP3   <- unlist(lapply(setdiff(SITES$Philips, "P3"),
                           function(s) D[[s]]$GABAplus))
siem_obs2 <- M[["Siemens"]] / mean(c(M[["GE"]], mean(ph_noP3)))

headline <- data.frame(
  analysis = c("all sites", "excluding P3"),
  siemens_rel_observed  = c(siem_obs, siem_obs2),
  siemens_rel_published = c(siem_pub, siem_pub),
  siemens_pct_low = c(100 * (1 - siem_obs / siem_pub),
                      100 * (1 - siem_obs2 / siem_pub)),
  craven_prediction_pct = c(28, 28),
  stringsAsFactors = FALSE)

cat("\n===== HEADLINE: Siemens vs mean(GE, Philips) =====\n")
print(headline, row.names = FALSE, digits = 4)
write.csv(headline, file.path(TABLES, "headline.csv"), row.names = FALSE)

# ------------------------------------------------------- variability ------

pooled_all      <- unlist(lapply(all_sites, function(s) D[[s]]$GABAplus))
pooled_noP3     <- unlist(lapply(setdiff(all_sites, "P3"),
                                 function(s) D[[s]]$GABAplus))
within_site_cvs <- per_site$cv_pct

variability <- data.frame(
  quantity  = c("whole-dataset CV", "whole-dataset CV (excl P3)",
                "mean within-site CV"),
  observed  = c(cvpct(pooled_all), cvpct(pooled_noP3), mean(within_site_cvs)),
  published = c(PUB_WHOLE_CV, PUB_WHOLE_CV, PUB_WITHIN_SITE_CV),
  stringsAsFactors = FALSE)

cat("\n===== VARIABILITY =====\n")
print(variability, row.names = FALSE, digits = 4)
cat(sprintf("\nwithin-site CV range: %.1f%% - %.1f%%\n",
            min(within_site_cvs), max(within_site_cvs)))
cat(sprintf("total n = %d across %d sites   (published: 272 across 24)\n",
            length(pooled_all), length(all_sites)))
write.csv(variability, file.path(TABLES, "variability.csv"), row.names = FALSE)

# ------------------------------- fit-range sensitivity analysis (D-07) ----

GR <- file.path(RESULTS, "gannet_range")
if (dir.exists(GR)) {
  gd <- setNames(lapply(all_sites, read_site, root = GR), all_sites)
  have <- all_sites[!vapply(gd, is.null, logical(1))]

  if (length(have)) {
    cat(sprintf("\n===== FIT-RANGE SENSITIVITY (D-07): %d/%d sites =====\n",
                length(have), length(all_sites)))
    if (length(have) < length(all_sites)) {
      cat("INCOMPLETE - missing: ",
          paste(setdiff(all_sites, have), collapse = ", "), "\n", sep = "")
    }

    cmp <- do.call(rbind, lapply(have, function(s) {
      a <- mean(D[[s]]$GABAplus); b <- mean(gd[[s]]$GABAplus)
      data.frame(site = s, vendor = vendor_of(s),
                 default_range = a, gannet_range = b,
                 pct_change = 100 * (b - a) / a, stringsAsFactors = FALSE)
    }))
    print(cmp, row.names = FALSE, digits = 4)
    write.csv(cmp, file.path(TABLES, "fit_range_sensitivity.csv"),
              row.names = FALSE)

    vend <- unique(cmp$vendor)
    if (length(vend) >= 2) {
      gm <- setNames(vapply(vend, function(v)
              mean(unlist(lapply(cmp$site[cmp$vendor == v],
                                 function(s) gd[[s]]$GABAplus))), numeric(1)), vend)
      cat("\nvendor means under Gannet's range:\n")
      for (v in vend) cat(sprintf("  %-8s %.4f  (default %.4f)\n", v, gm[[v]], M[[v]]))

      if (all(c("GE","Philips","Siemens") %in% vend)) {
        so <- gm[["Siemens"]] / mean(c(gm[["GE"]], gm[["Philips"]]))
        cat(sprintf("\nSiemens vs mean(GE,Philips) at Gannet range: %.3f -> %.1f%% low\n",
                    so, 100 * (1 - so / siem_pub)))
        cat(sprintf("                       at default range: %.3f -> %.1f%% low\n",
                    siem_obs, 100 * (1 - siem_obs / siem_pub)))
      } else {
        cat("\nSiemens sites absent - the headline comparison cannot be made.\n")
      }
    }
  }
} else {
  cat("\n(no results/gannet_range - fit-range sensitivity analysis not run)\n")
}

cat(sprintf("\nTables written to %s\n", TABLES))
