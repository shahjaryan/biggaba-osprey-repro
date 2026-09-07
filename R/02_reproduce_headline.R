# 02_reproduce_headline.R
#
# Reproduce the headline GABA+/Cr table and coefficients of variation from
# Mikkelsen et al. (2017), and place them side by side with the published values.
#
# The output of this script is the core table of the writeup.

library(dplyr)
library(tidyr)
library(readr)

osprey <- readRDS(here::here("results", "osprey_tidy.rds"))

# ---------------------------------------------------------------------------
# Published values (Gannet). Source: Mikkelsen et al. 2017, NeuroImage 159:32-45.
# Do not edit these to make things match.

published <- tibble::tribble(
  ~group,     ~pub_mean, ~pub_sd, ~pub_cv,
  "Overall",  0.116,     0.014,   12.0,
  "GE",       0.123,     0.014,   11.5,
  "Philips",  0.111,     0.013,   11.6,
  "Siemens",  0.116,     0.012,   10.7
)

PUB_WITHIN_SITE_CV <- 9.5

# ---------------------------------------------------------------------------
# Reproduction

cv <- function(x) 100 * stats::sd(x, na.rm = TRUE) / mean(x, na.rm = TRUE)

by_vendor <- osprey |>
  group_by(group = as.character(vendor)) |>
  summarise(
    n       = sum(!is.na(gaba_cr)),
    rep_mean = mean(gaba_cr, na.rm = TRUE),
    rep_sd   = stats::sd(gaba_cr, na.rm = TRUE),
    rep_cv   = cv(gaba_cr),
    .groups  = "drop"
  )

overall <- osprey |>
  summarise(
    group    = "Overall",
    n        = sum(!is.na(gaba_cr)),
    rep_mean = mean(gaba_cr, na.rm = TRUE),
    rep_sd   = stats::sd(gaba_cr, na.rm = TRUE),
    rep_cv   = cv(gaba_cr)
  )

# Mean within-site CV: CV computed per site, then averaged across sites.
within_site_cv <- osprey |>
  group_by(site) |>
  summarise(site_cv = cv(gaba_cr), n = dplyr::n(), .groups = "drop")

mean_within_site_cv <- mean(within_site_cv$site_cv, na.rm = TRUE)

# ---------------------------------------------------------------------------
# Side by side

comparison <- bind_rows(overall, by_vendor) |>
  left_join(published, by = "group") |>
  mutate(
    d_mean     = rep_mean - pub_mean,
    pct_diff   = 100 * (rep_mean - pub_mean) / pub_mean,
    d_cv       = rep_cv - pub_cv,
    # Does the published mean sit inside the reproduction's 95% CI of the mean?
    se         = rep_sd / sqrt(n),
    ci_lo      = rep_mean - 1.96 * se,
    ci_hi      = rep_mean + 1.96 * se,
    pub_in_ci  = pub_mean >= ci_lo & pub_mean <= ci_hi
  ) |>
  select(group, n, pub_mean, rep_mean, d_mean, pct_diff,
         ci_lo, ci_hi, pub_in_ci, pub_cv, rep_cv, d_cv)

print(as.data.frame(comparison), digits = 3)

cat("\nMean within-site CV:\n")
cat(sprintf("  published %.1f%%   reproduced %.1f%%   diff %+.1f%%\n",
            PUB_WITHIN_SITE_CV, mean_within_site_cv,
            mean_within_site_cv - PUB_WITHIN_SITE_CV))

# ---------------------------------------------------------------------------
# The pre-specified expectation

siemens <- comparison |> filter(group == "Siemens")
cat("\n--- Pre-specified check ---\n")
cat("Craven et al. 2022 reports Osprey giving ~28% LOWER estimates on Siemens.\n")
cat(sprintf("Observed Siemens difference vs published: %+.1f%%\n", siemens$pct_diff))
cat(paste0(
  "Interpretation guide:\n",
  "  near -28%  -> independently confirms Craven; strong result\n",
  "  near   0%  -> contradicts Craven; also a strong result, needs explaining\n",
  "  elsewhere  -> log it and investigate; do not tune parameters to move it\n"))

readr::write_csv(comparison, here::here("results", "headline_comparison.csv"))
readr::write_csv(within_site_cv, here::here("results", "within_site_cv.csv"))
cat("\nWrote results/headline_comparison.csv\n")
cat("Now record every divergence in docs/discrepancy-log.md.\n")
