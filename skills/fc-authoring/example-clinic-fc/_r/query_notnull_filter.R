# Ad-hoc check (R): a numeric NOT-NULL filter actually drops the null rows AT THE ENGINE.
#
# Why this works with the toy as-is: labs are sparse (rolled up per encounter), so the numeric
# variable `Metabolic = HbA1c` is NULL for every encounter that didn't get that lab. That gives us
# real nulls to filter without editing any fixture. We assert the baseline has BOTH nulls and
# non-nulls (so the filter is meaningful, never a silent no-op — an adversarial reviewer's first
# complaint) and that `!is.na()` returns exactly the non-null entities.
#
# Requires tagbio R SDK >= 1.1.73 (numeric `!=`/`is.na` filter + engine operator `=`).
# Run after `bash _shell_scripts/run_server.sh` is up.

library(tagbio)
library(dplyr)

VAR <- "Metabolic = HbA1c"
fc  <- tbl(tagConnect(host_url = "http://localhost:8000"))

total    <- fc %>% select(Department) %>% collect() %>% nrow()
baseline <- fc %>% select(`Metabolic = HbA1c`) %>% collect()
vals     <- baseline[[VAR]]
n_null   <- sum(is.na(vals))
n_notnull<- sum(!is.na(vals))

cat(sprintf("baseline: %d entities | %d null | %d non-null on '%s'\n",
            total, n_null, n_notnull, VAR))

# Meaningful-test guard: there must be something to drop AND something to keep.
stopifnot("baseline has no nulls — pick a sparser variable"      = n_null > 0,
          "baseline has no non-nulls — pick another variable"    = n_notnull > 0)

notnull <- fc %>%
  filter(!is.na(`Metabolic = HbA1c`)) %>%
  select(`Metabolic = HbA1c`) %>%
  collect()

ok_count <- nrow(notnull) == n_notnull            # returned exactly the non-null entities
ok_clean <- all(!is.na(notnull[[VAR]]))           # none of them are null
ok_drop  <- nrow(notnull) < total                 # the engine actually dropped rows

cat(sprintf("!is.na filter: %d rows (expected %d) | all non-null: %s | dropped %d null entities\n",
            nrow(notnull), n_notnull, ok_clean, total - nrow(notnull)))

if (ok_count && ok_clean && ok_drop) {
  cat("PASS: engine honored the not-null filter; null rows were dropped.\n")
} else {
  stop("FAIL: not-null filter did not behave as expected.")
}
