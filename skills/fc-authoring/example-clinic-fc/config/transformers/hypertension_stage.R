#!/usr/bin/env Rscript
# Transformer: add a "Hypertension Stage" categorical collection to the clinic build.
#
# It is computed, not parsed: the stage depends on BOTH blood-pressure numbers together
# (ACC/AHA rule), which no single source column holds. So we self-query the local build
# for each encounter's Systolic/Diastolic, classify it, and emit the new collection.
#
# The engine invokes this with two args:
#   $1  output_file       -- where to write the FC-ingestion CSV
#   $2  entity_collection  -- the collection whose values key each row (here "Encounter ID")

library(tagbio)
suppressMessages(library(dplyr))

args <- commandArgs(trailingOnly = TRUE)
output_file <- args[1]

# Self-query the LOCAL build in progress. HARDCODE localhost: a bare tagConnect() only falls back
# to localhost when nothing outranks it, so an ambient host (env TAGBIO_BASE_URL, or a ~/.tagbio.json
# entry) would hijack the connect to a remote cluster and a bare tbl() there 405s. A transformer
# isn't in plugin-context, so the SDK won't auto-force localhost -- the author must state it. Use no
# table name (tbl(con)): a deployed copy would NOT yet have this run's data (chicken-and-egg).
# A numeric variable is exposed as "<Collection> = <Variable>" (the SDK's qdelim); a
# categorical collection is exposed under its own name.
con <- tagConnect(host_url = "http://localhost:8000")
bp <- tbl(con) %>%
  select(`Encounter ID`, `Blood Pressure = Systolic`, `Blood Pressure = Diastolic`) %>%
  collect() %>%
  rename(systolic = `Blood Pressure = Systolic`, diastolic = `Blood Pressure = Diastolic`)

# ACC/AHA blood-pressure staging from the two readings together.
stage <- function(sys, dia) {
  if (is.na(sys) || is.na(dia)) return(NA_character_)
  if (sys >= 140 || dia >= 90) return("Stage 2")
  if (sys >= 130 || dia >= 80) return("Stage 1")
  if (sys >= 120)              return("Elevated")
  "Normal"
}

bp <- bp %>%
  mutate(`Hypertension Stage` = mapply(stage, systolic, diastolic)) %>%
  filter(!is.na(`Hypertension Stage`))

# FC-ingestion "tall" format: one row per (collection, entity, value). For a CATEGORICAL
# collection the engine reads variable_name as the tag/level and only checks that value is
# non-empty. entity = the Encounter ID value, matching the entity_collection passed in.
# auth_groups blank = visible to all.
out <- data.frame(
  data_type           = "categorical",
  collection_set_name = "",
  collection_name     = "Hypertension Stage",
  variable_name       = bp$`Hypertension Stage`,
  auth_groups         = "",
  entity              = bp$`Encounter ID`,
  value               = bp$`Hypertension Stage`,
  stringsAsFactors    = FALSE
)

# Let write.csv quote string fields (its default) so a comma/newline in a value can't corrupt the
# ingestion CSV — never write this file unquoted.
write.csv(out, output_file, row.names = FALSE)
cat(sprintf("[hypertension_stage] wrote %d rows to %s\n", nrow(out), output_file), file = stderr())
