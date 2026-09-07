# 03_variance_decomposition.R
#
# Reproduce the published variance decomposition:
#   72% participants within site / 20% site / 8% vendor
#
# IMPORTANT CAVEAT
# The paper does not fully specify the model used to produce that split. A
# different nesting structure will produce different percentages from identical
# data. If these numbers diverge, the first hypothesis is a difference in model
# specification, NOT a difference in the data or the fitting algorithm.
# Rule these out before writing up a divergence as a reproduction failure.

library(dplyr)
library(lme4)

osprey <- readRDS(here::here("results", "osprey_tidy.rds"))

PUBLISHED <- c(subject_within_site = 72, site = 20, vendor = 8)

# ---------------------------------------------------------------------------
# Primary specification: sites nested within vendors, participants as residual.

fit <- lme4::lmer(gaba_cr ~ 1 + (1 | vendor / site), data = osprey, REML = TRUE)

vc <- as.data.frame(lme4::VarCorr(fit))

get_var <- function(grp) {
  v <- vc$vcov[vc$grp == grp]
  if (length(v) == 0) NA_real_ else v[1]
}

var_vendor   <- get_var("vendor")
var_site     <- get_var("site:vendor")
var_resid    <- vc$vcov[vc$grp == "Residual"][1]
var_total    <- var_vendor + var_site + var_resid

vpc <- c(
  subject_within_site = 100 * var_resid  / var_total,
  site                = 100 * var_site   / var_total,
  vendor              = 100 * var_vendor / var_total
)

comparison <- tibble::tibble(
  level      = names(PUBLISHED),
  published  = as.numeric(PUBLISHED),
  reproduced = as.numeric(vpc[names(PUBLISHED)]),
  difference = as.numeric(vpc[names(PUBLISHED)]) - as.numeric(PUBLISHED)
)

cat("Primary specification: (1 | vendor/site)\n\n")
print(as.data.frame(comparison), digits = 3)

# ---------------------------------------------------------------------------
# Sensitivity: crossed rather than nested, to show how much the specification
# alone moves the answer. Report this in the writeup regardless of the result --
# it bounds how much of any divergence is attributable to model choice.

fit_alt <- lme4::lmer(gaba_cr ~ 1 + (1 | vendor) + (1 | site), data = osprey)
vc_alt  <- as.data.frame(lme4::VarCorr(fit_alt))
tot_alt <- sum(vc_alt$vcov)

cat("\nSensitivity: (1 | vendor) + (1 | site), non-nested\n")
print(data.frame(
  level = vc_alt$grp,
  pct   = round(100 * vc_alt$vcov / tot_alt, 1)
))

cat(paste0(
  "\nIf the two specifications differ substantially from each other, then model\n",
  "choice is a live confound and any divergence from the published 72/20/8 split\n",
  "cannot be attributed to Osprey vs Gannet. Say so plainly in the writeup.\n"))

readr::write_csv(comparison, here::here("results", "variance_decomposition.csv"))
