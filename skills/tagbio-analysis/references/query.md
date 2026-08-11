# Query — selecting, filtering, and pulling a dataframe

## Python

```python
import tagbiopy.fc
from tagbiopy.fundamentals import Categorical, Numeric

fc = tagbiopy.fc.FC(fc_name="fc-<name>")

df = fc.df.select(
        "Department",                            # categorical: just the name
        Categorical("Diagnosis"),                # or wrapped explicitly
        Numeric("Blood Pressure", "Systolic"),   # numeric: Numeric(collection, variable)
     ).run()                                     # -> pandas DataFrame
```

## R

```r
library(tagbio); library(dplyr)

con <- tagConnect()
fc  <- tbl(con, "fc-<name>")

df <- fc %>%
  select(Department, `Blood Pressure = Systolic`) %>%   # backticks for spaces/pipes
  collect()                                             # -> data.frame
```

**Always `select()` before `collect()`.** A bare `collect()` with no select pulls **nothing** — not
an error, just an empty result.

## Column naming on the way back

A categorical collection comes back as its own name. A numeric variable comes back **prefixed with
its collection**, and the separator differs by SDK:

| | Selected as | Returned as |
|---|---|---|
| R | `` `Blood Pressure = Systolic` `` | `Blood Pressure = Systolic` |
| Python | `Numeric("Blood Pressure", "Systolic")` | `Blood Pressure: Systolic` |

Strip the prefix so downstream code reads naturally:

```python
df = df.rename(columns=lambda c: c.replace("Blood Pressure: ", ""))
```
```r
names(df) <- sub("^Blood Pressure = ", "", names(df))
```

Write the rename defensively (`.replace`, `sub`) rather than assigning a fixed column list — a
collection that expands into more sub-variables than you expected would silently misalign a
positional assignment.

### The prefix appears in a plugin frame but not always in an SDK pull

Verified on a real product, and it will bite you when moving code between the two paths:

| Path | a single-variable numeric like `HbA1c` comes back as |
|---|---|
| Ad-hoc `fc.select("HbA1c").run()` | `HbA1c` — **bare** |
| Plugin `tag_data.df` (`analysis_variables`) | `HbA1c: HbA1c` — **doubled** |

The doubling happens because a numeric collection holding exactly one variable often names that
variable **the same as the collection**, and the plugin frame always applies the
`"<Collection>: <Variable>"` convention. So a normalizer must handle the degenerate case, not just
strip a known prefix:

```python
def normalize_columns(df):
    def fix(c):
        if ": " not in c:
            return c
        coll, var = c.split(": ", 1)
        return coll if coll == var else var      # "A: A" -> "A";  "BP: Systolic" -> "Systolic"
    return df.rename(columns=fix)
```

Never assume bare names in a plugin, and never assume prefixed names in an ad-hoc pull. Check
`df.columns` on the path you're actually on.

## Filter server-side when you can

Pushing the filter to the engine means you transfer only matching entities — a large win on a big
product.

```python
# Python — needs tagbiopy >= 1.0.6. Each condition is a tuple, chained before .run()
fc.df.select(...).where(("Department", "Cardiology")).run()                 # categorical
fc.df.select(...).where(("Blood Pressure", "Systolic", ">", 120)).run()     # (coll, var, op, value)
fc.df.select(...).where(("Metabolic", "HbA1c", "not null")).run()           # keep entities that HAVE a value
```

```r
# R — needs tagbio >= 1.1.74. Multiple filter()s are AND-combined
fc %>% filter(Department == "Cardiology") %>% select(...) %>% collect()
fc %>% filter(`Blood Pressure = Systolic` > 120) %>% select(...) %>% collect()
fc %>% filter(!is.na(`Metabolic = HbA1c`)) %>% select(...) %>% collect()
```

Operators: `= != < <= > >=`. Two limits to know:

- **There is no server-side "is null" test** — only **not-null**. The engine can't match a numeric
  null yet, and asking for it errors.
- **On older SDKs there is no pushdown at all.** Pull, then filter the frame client-side:
  `df[df["HbA1c"].notna()]` / `filter(!is.na(...))`. Client-side is always the reliable
  fallback; it just costs transfer.

## Size, timeouts, and what will actually kill your query

Every selected collection streams **all entity rows**. The failure modes are specific:

- **Selecting everything can exceed the server's ~2-minute gateway timeout.** In R this surfaces as
  the cryptic `No method asJSON S3 class: request` — that is a **masked 504**, not a bug in your
  code. In Python you may see a dropped connection (`RemoteDisconnected`).
- **A high-cardinality free-text column can blow up the payload on its own.** A column with hundreds
  of thousands of distinct values (raw free-text event descriptions, unnormalized notes) bloats the
  download until the server drops the connection. If a product's `summary` shows a column with a
  cardinality near the entity count, **don't select it** — look for the standardized/normalized
  sibling column instead.
- **A handful of collections on a few hundred thousand rows returns in tens of seconds.** There's a
  row-transfer floor plus a per-collection cost, so budget by column count.

**For a full-data export, use the product's front-end download protocol.** It exports server-side
and is faster than any SDK `collect()` / `.run()`.

## Cache expensive pulls

A large pull is slow and — under the consent guardrail — something you don't want to repeat
casually. Cache it locally and reuse:

```python
import os, pandas as pd
CACHE = os.path.expanduser("~/.myproduct_cache.pkl")
if os.path.exists(CACHE):
    df = pd.read_pickle(CACHE)
else:
    df = fc.df.select(...).run()
    df.to_pickle(CACHE)          # pickle: pyarrow/parquet may not be installed in this env
```

A cache file is a **data extract** — it carries the same sensitivity as the source. Keep it in your
home directory, out of git and out of shared folders, and delete it when done.

## Iterate on a small slice first

Get the logic right cheaply before paying for the full pull:

- Select **two or three columns** and check the shape, dtypes, and null counts.
- Use a **server-side filter** to bound the rows while developing.
- Confirm your join keys are present and unique **before** pulling the wide frame.
- A long-running query on a big product is **not automatically pathological** — validate the logic on
  a bounded subset before blaming performance.
