#!/usr/bin/env Rscript
# Discover a Tag.bio product, then pull a small dataframe and summarize it (R).
#
# `summary()` returns METADATA only and moves no patient data — safe to run first.
# The collect() below EXECUTES A REAL PULL: under the guardrails in ../SKILL.md, don't run it
# against a proprietary/regulated product without the requester's attestation.
#
#   Rscript explore_and_pull.R fc-<name>

library(tagbio)
library(dplyr)

args    <- commandArgs(trailingOnly = TRUE)
FC_NAME <- if (length(args) > 0) args[[1]] else "fc-clinic"

# --- Connect ----------------------------------------------------------------------------------
# tagConnect() resolves the host (TAGBIO_BASE_URL in the notebook, else ~/.tagbio.json) and the
# API key from ~/.tagbio.json. Never hardcode the key.
con <- tagConnect()
fc  <- tbl(con, FC_NAME)          # NAME the product on a deployed cluster.
                                  # On a localhost run_server: tagConnect(host_url=...) + tbl(con)

# --- Discover (metadata only) -----------------------------------------------------------------
info <- summary(fc)               # a METHOD in R (a PROPERTY in Python)
cat("product:", FC_NAME, "\n")
cat("collections:", nrow(info), "\n")
print(utils::head(info))          # metadata rows: names/types/sizes, not data values

available <- colnames(fc)
wanted    <- c("Department", "Blood Pressure = Systolic", "Blood Pressure = Diastolic")
use       <- intersect(wanted, available)
missing   <- setdiff(wanted, available)
if (length(missing)) cat("NOT in this product:", paste(missing, collapse = ", "), "\n")
if (!length(use)) stop("none of the requested collections exist here — re-run discovery")

# --- Pull -------------------------------------------------------------------------------------
# Always select() BEFORE collect(); a bare collect() pulls nothing. Backticks are required for
# names with spaces, "=" or "|". Numerics are named `Collection = Variable` in R (": " in Python).
df <- fc %>%
  select(all_of(use)) %>%
  collect()

# Strip the collection prefix defensively so the analysis reads naturally.
names(df) <- sub("^Blood Pressure = ", "", names(df))

# --- Report structure, not rows ---------------------------------------------------------------
cat("\nrows:", nrow(df), " cols:", ncol(df), "\n")
cat("columns:", paste(names(df), collapse = ", "), "\n")
print(colSums(is.na(df)))

# --- Analyze ----------------------------------------------------------------------------------
# n() counts rows; the honest denominator for a mean is entities that HAVE a value.
if (all(c("Department", "Systolic") %in% names(df))) {
  df %>%
    group_by(Department) %>%
    summarise(
      mean_systolic = mean(Systolic, na.rm = TRUE),
      with_value    = sum(!is.na(Systolic)),
      rows          = n(),
      .groups       = "drop"
    ) %>%
    print()
}

# Grain check: at event grain these rows are events, not subjects. `Unique ID` is added to every
# extract automatically, so a rows-vs-entities gap is always detectable.
if ("Unique ID" %in% names(df)) {
  cat("\nrows:", nrow(df), " distinct entities:", length(unique(df[["Unique ID"]])), "\n")
}
