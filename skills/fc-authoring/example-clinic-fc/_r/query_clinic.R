# Ad-hoc query against a running Clinic FC, with a quick analysis (R).
#
# There are two ways to connect:
#
#   LOCALHOST (used below): an FC you started yourself with run_server on this machine
#     (serving on localhost:8000). A local server needs NO authentication.
#
#   DEPLOYED (Tag.bio cluster): an FC running as a container in the Tag.bio deployment
#     cluster. That DOES require authentication — a named connection string / stored
#     credentials (e.g. ~/.tagbio.json). See the commented alternative below.
#
# Run this after `bash _shell_scripts/run_server.sh` is up.

library(tagbio)
library(dplyr)

# --- Connect to a LOCALHOST FC (no auth needed) ---
con <- tagConnect(host_url = "http://localhost:8000")

# --- Deployed alternative (requires auth + a named connection; do NOT hardcode credentials) ---
# con <- tagConnect(host_url = Sys.getenv("TAGBIO_BASE_URL"))   # credentials via ~/.tagbio.json

# Target the FC. A LOCALHOST run_server serves a single product, so tbl(con) takes NO name.
# (On a DEPLOYED cluster you name the product: tbl(con, "fc-clinic").)
fc <- tbl(con)

# Pull just the columns you need. Always select() BEFORE collect() — a bare collect() pulls nothing.
# A numeric variable is named "<Collection> = <Variable>" (the R SDK's separator); select those
# names, then strip the prefix so the analysis code reads as plain Systolic / Diastolic.
df <- fc %>%
  select(Department, `Blood Pressure = Systolic`, `Blood Pressure = Diastolic`) %>%
  collect()
names(df) <- sub("^Blood Pressure = ", "", names(df))

# Quick analysis: mean blood pressure by department.
df %>%
  group_by(Department) %>%
  summarise(
    mean_systolic  = mean(Systolic,  na.rm = TRUE),
    mean_diastolic = mean(Diastolic, na.rm = TRUE),
    encounters     = n()
  ) %>%
  print()
