# Ad-hoc check (Python): a numeric NOT-NULL filter actually drops the null rows AT THE ENGINE.
#
# Mirror of _r/query_notnull_filter.R. Labs are sparse (rolled up per encounter), so the numeric
# variable "Metabolic: HbA1c" is null for every encounter without that lab — real nulls to filter,
# no fixture edits. We assert the baseline has BOTH nulls and non-nulls (so the filter is meaningful,
# never a silent no-op) and that the 'not null' filter returns exactly the non-null entities.
#
# Requires tagbiopy >= 1.0.6 (3-tuple 'not null' filter). Run after run_server.sh is up.

import sys

import tagbiopy.fc
from tagbiopy.fundamentals import Numeric

COLL, VAR = "Metabolic", "HbA1c"
NAME = f"{COLL}: {VAR}"   # the Python SDK's numeric-variable output separator is ": "

fc = tagbiopy.fc.FC(fc_name="fc-clinic", host="http://localhost:8000")

total = len(fc.df.select("Department").run())
baseline = fc.df.select(Numeric(COLL, VAR)).run()
vals = baseline[NAME]
n_null = int(vals.isna().sum())
n_notnull = int(vals.notna().sum())

print(f"baseline: {total} entities | {n_null} null | {n_notnull} non-null on '{NAME}'")

# Meaningful-test guard: something to drop AND something to keep.
assert n_null > 0, "baseline has no nulls — pick a sparser variable"
assert n_notnull > 0, "baseline has no non-nulls — pick another variable"

notnull = fc.df.select(Numeric(COLL, VAR)).where((COLL, VAR, "not null")).run()
ok_count = len(notnull) == n_notnull
ok_clean = bool(notnull[NAME].notna().all())
ok_drop = len(notnull) < total

print(f"'not null' filter: {len(notnull)} rows (expected {n_notnull}) | "
      f"all non-null: {ok_clean} | dropped {total - len(notnull)} null entities")

if ok_count and ok_clean and ok_drop:
    print("PASS: engine honored the not-null filter; null rows were dropped.")
else:
    print("FAIL: not-null filter did not behave as expected.")
    sys.exit(1)
