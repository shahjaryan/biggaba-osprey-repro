# 01_load_osprey_output.R
#
# Read Osprey per-site exports into one tidy data frame.
#
# UNTESTED. Osprey's exported table filenames and column names vary between
# versions; inspect one site's output directory and fix the readers below before
# trusting anything downstream.

library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(stringr)

RESULTS_DIR <- here::here("results")

IN_SCOPE <- c(paste0("G", 1:8), paste0("P", 1:9), paste0("S", 1:7))

# ---------------------------------------------------------------------------

read_site <- function(site) {
  site_dir <- file.path(RESULTS_DIR, site)
  if (!dir.exists(site_dir)) {
    warning("No output directory for site ", site)
    return(NULL)
  }

  # Osprey writes quantification tables as CSV under the output folder.
  # The exact name depends on version and quantification type; tCr ratios are
  # the target here.
  candidates <- list.files(
    site_dir,
    pattern = "tCr.*\\.csv$|.*tCr.*\\.tsv$",
    recursive = TRUE, full.names = TRUE
  )

  if (length(candidates) == 0) {
    warning("No tCr table found for site ", site,
            " - check the output directory layout")
    return(NULL)
  }
  if (length(candidates) > 1) {
    message("Multiple tCr tables for ", site, "; using: ",
            basename(candidates[1]))
  }

  readr::read_csv(candidates[1], show_col_types = FALSE) |>
    mutate(site = site, .before = 1)
}

# ---------------------------------------------------------------------------

osprey_raw <- purrr::map(IN_SCOPE, read_site) |> purrr::compact()

stopifnot(length(osprey_raw) > 0)

osprey <- dplyr::bind_rows(osprey_raw) |>
  mutate(
    vendor = dplyr::recode(stringr::str_sub(site, 1, 1),
                           G = "GE", P = "Philips", S = "Siemens"),
    site   = factor(site, levels = IN_SCOPE),
    vendor = factor(vendor, levels = c("GE", "Philips", "Siemens"))
  ) |>
  relocate(vendor, .after = site)

# GABA column name differs by Osprey version and coMM3 setting.
gaba_col <- names(osprey)[stringr::str_detect(names(osprey), "(?i)gaba")][1]
if (is.na(gaba_col)) stop("Could not find a GABA column. Inspect names(osprey).")
message("Using GABA column: ", gaba_col)

osprey <- osprey |> mutate(gaba_cr = .data[[gaba_col]])

# ---------------------------------------------------------------------------
# Scope check. Loud, because getting this wrong silently invalidates everything.

n_sites <- dplyr::n_distinct(osprey$site)
n_subj  <- nrow(osprey)

message(sprintf("Loaded %d datasets across %d sites.", n_subj, n_sites))
message("Published sample: 272 datasets, 24 sites (GE 91 / Philips 104 / Siemens 77).")

if (any(c("P10", "S8") %in% as.character(osprey$site))) {
  stop("P10 or S8 present. These postdate Mikkelsen 2017 and must be excluded.")
}

print(osprey |> count(vendor, name = "n"))

saveRDS(osprey, file.path(RESULTS_DIR, "osprey_tidy.rds"))
message("Wrote results/osprey_tidy.rds")
