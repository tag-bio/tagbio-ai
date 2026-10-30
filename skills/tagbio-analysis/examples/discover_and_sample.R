#!/usr/bin/env Rscript
# List data products, describe the data model and collection sets, then look at a product through a small sample (R).
# Needs tagbio >= 1.1.104.
#
# The listing calls move no data. head(n) and collect() EXECUTE A REAL PULL (of n entities): under
# the guardrails in ../SKILL.md, don't run them against a proprietary/regulated product without the
# requester's attestation, and don't print the rows.
#
#   Rscript discover_and_sample.R fc-<name>      # a deployed product
#   Rscript discover_and_sample.R localhost      # a local run_server on :8000

library(tagbio)
library(dplyr)

args    <- commandArgs(trailingOnly = TRUE)
FC_NAME <- if (length(args) > 0) args[[1]] else "localhost"

# --- Connect ----------------------------------------------------------------------------------
if (FC_NAME == "localhost") {
  con <- tagConnect(host_url = "http://localhost:8000")
  fc  <- tbl(con)
} else {
  con <- tagConnect()
  fc  <- tbl(con, FC_NAME)
}

# --- Discover (metadata only) -----------------------------------------------------------------
products <- tagListDataProducts(con)          # name, title, description, url
cat("data products on this cluster:", nrow(products), "\n")

# One row per collection: pull column names, type, kind, entity counts, small categoricals' values, sets.
dd <- tagDataDictionary(fc)
cat(sprintf("%s: %d collections on %s %s\n", attr(dd, "data_product")$title, nrow(dd),
            format(attr(dd, "data_product")$entity_count, big.mark = ","), attr(dd, "data_product")$entity_name_plural))
print(dd %>% count(data_type, kind))

sets <- tagListCollectionSets(fc)             # e.g. "Labs"
cat("collection sets:", if (length(sets)) paste(sets, collapse = ", ") else "(none)", "\n")

# --- Sample (pulls n entities) ----------------------------------------------------------------
# head(n) is a reproducible sample of n entities (same seed, same entities), not "the first n".
# Put filter() before head() to sample within a cohort.
if (length(sets)) {
  family <- fc %>% select(collection_set(sets[[1]])) %>% head(25) %>% collect()
  cat(sprintf("'%s' set: %d columns on %d sampled entities\n", sets[[1]], ncol(family), nrow(family)))
}

# Single-valued categoricals as factors (opt-in); multi-valued columns stay "; "-joined strings.
typed <- fc %>% select(everything()) %>% head(25) %>% collect(factors = TRUE)
cat("factor columns:", paste(names(typed)[vapply(typed, is.factor, logical(1))], collapse = ", "), "\n")
