# 00_verify_sample.R
#
# Run this BEFORE any Osprey processing, as soon as demographics.csv is downloaded.
# Confirms the sample matches Mikkelsen 2017 independently of the imaging data.
#
# Catches, cheaply: P10/S8 contamination, wrong vendor counts, and demographic
# imbalance across vendors that could masquerade as a vendor effect later.
#
# Column names in the supplied CSV are unverified, so this prints the structure
# first and then guesses. Fix the mappings below once you can see the real columns.

library(dplyr)
library(readr)
library(stringr)

demo_path <- here::here("data", "demographics.csv")
stopifnot(file.exists(demo_path))

demo <- readr::read_csv(demo_path, show_col_types = FALSE)

cat("=== STRUCTURE ===\n")
print(dplyr::glimpse(demo))
cat("\nColumns:", paste(names(demo), collapse = ", "), "\n\n")

# --- column guessing; correct these once you've seen the real file -------------
pick <- function(df, patterns) {
  hit <- names(df)[stringr::str_detect(names(df), stringr::regex(patterns, ignore_case = TRUE))]
  if (length(hit) == 0) NA_character_ else hit[1]
}
col_site <- pick(demo, "^site|site")
col_age  <- pick(demo, "^age")
col_sex  <- pick(demo, "^sex|gender")

cat(sprintf("Guessed columns -> site: %s | age: %s | sex: %s\n\n",
            col_site, col_age, col_sex))
if (is.na(col_site)) stop("Could not identify a site column. Set col_site manually.")

demo <- demo |>
  mutate(
    site   = as.character(.data[[col_site]]),
    vendor = dplyr::recode(stringr::str_sub(site, 1, 1),
                           G = "GE", P = "Philips", S = "Siemens",
                           .default = NA_character_)
  )

# --- checks -------------------------------------------------------------------
EXPECTED <- c(GE = 91, Philips = 104, Siemens = 77)
IN_SCOPE <- c(paste0("G", 1:8), paste0("P", 1:9), paste0("S", 1:7))

cat("=== SCOPE ===\n")
out_of_scope <- setdiff(unique(demo$site), IN_SCOPE)
if (length(out_of_scope)) {
  cat("Sites present that are NOT in Mikkelsen 2017:",
      paste(out_of_scope, collapse = ", "), "\n")
  cat("These must be excluded. Filtering them now for the counts below.\n\n")
}
demo_scoped <- demo |> filter(site %in% IN_SCOPE)

cat("=== COUNTS ===\n")
counts <- demo_scoped |> count(vendor, name = "observed") |>
  mutate(expected = as.integer(EXPECTED[vendor]),
         match    = observed == expected)
print(as.data.frame(counts))

cat(sprintf("\nTotal in scope: %d (expected 272)\n", nrow(demo_scoped)))
cat(sprintf("Sites in scope: %d (expected 24)\n\n",
            dplyr::n_distinct(demo_scoped$site)))

if (all(counts$match) && nrow(demo_scoped) == 272) {
  cat(">>> SAMPLE VERIFIED. Matches the published sample.\n\n")
} else {
  cat(">>> MISMATCH. Do not proceed until this is understood.\n")
  cat("    Record the discrepancy in docs/discrepancy-log.md before continuing.\n\n")
}

# --- demographic balance across vendors ---------------------------------------
if (!is.na(col_age)) {
  cat("=== AGE BY VENDOR ===\n")
  print(as.data.frame(
    demo_scoped |> group_by(vendor) |>
      summarise(n = dplyr::n(),
                mean_age = mean(.data[[col_age]], na.rm = TRUE),
                sd_age   = sd(.data[[col_age]],   na.rm = TRUE),
                .groups  = "drop")))
  aov_age <- summary(aov(demo_scoped[[col_age]] ~ demo_scoped$vendor))
  cat("\nAge ~ vendor ANOVA:\n"); print(aov_age)
  cat("A significant result here does NOT invalidate anything, but it means a\n",
      "vendor difference in GABA cannot be cleanly attributed to the scanner.\n\n")
}

if (!is.na(col_sex)) {
  cat("=== SEX BY VENDOR ===\n")
  tab <- table(demo_scoped$vendor, demo_scoped[[col_sex]])
  print(tab)
  cat("\nChi-squared:\n"); print(chisq.test(tab))
}
