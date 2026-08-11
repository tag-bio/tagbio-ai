# Discover — find the real collection names first

**Never guess a collection name.** They are product-specific, human-readable English with spaces
and sometimes pipes (a compound key like `Subject ID | Laterality`), and they are
**case-sensitive**. A wrong name
either errors or quietly returns nothing. Discovery takes under a second and costs no data
transfer.

## The two calls

```python
# Python
fc.summary                              # a PROPERTY -> DataFrame: every collection, type, size
fc.list_collections("categorical")      # names by type
fc.list_collections("numeric")
fc.info                                 # product metadata (entity name, counts, version)
fc.number_of_entities                   # a PROPERTY, not a method
```

```r
# R
summary(fc)      # a METHOD -> a table describing every collection: name, type, size
colnames(fc)     # just the names
```

> **`colnames()` is empty on a localhost FC.** On a `run_server` dev serve (and the build-in-progress
> self-query) `colnames(fc)` comes back empty, so `all_of(colnames(fc))` and tidy-eval injection
> (`!!sym(x)`) are unreliable there. Select by **literal name** with backticks, or use
> `everything()` on a small product. On a **deployed** product both calls work.

You can also browse the collections in the Tag.bio front-end, which is often faster for getting
oriented on an unfamiliar product.

### ⚠️ R and Python `summary` do NOT return the same frame — and the missingness column is INVERTED

**Verified on one live product with both SDKs.** This is the most dangerous asymmetry in the
platform, because the numbers look plausible either way:

| | Python `fc.summary` | R `summary(fc)` |
|---|---|---|
| Name column | `Collection` | `collection` |
| Type column | `Collection Type` | `collection_type` |
| Size column | `Size` | `collection_size` |
| Fourth column | `Entities without data` | `collection_entity_count` |
| **What the fourth column MEANS** | entities **WITHOUT** a value (missing) | entities **WITH** a value (populated) |

Same collection, same moment, 65-entity product: Python reported `Entities without data = 10`; R
reported `collection_entity_count = 55`. Both are correct — they are **complements**.

Two consequences:

1. **Python-shaped code fails loudly in R** (`Column 'Collection' doesn't exist`) — annoying but safe.
2. **The populated-count recipe below silently inverts.** In R, `entity_count - collection_entity_count`
   gives you the **missing** count while you believe it's the populated one. In R the populated count
   **is** `collection_entity_count` — no arithmetic needed.

So: **never port a `summary`-reading block between the SDKs without re-checking the column names and
which side of the missingness the number is on.** Print `names(s)` / `s.columns` first.

### What `summary` actually returns (Python)

Four columns (verified against a deployed product) — note the type column is **`Collection Type`**,
not "Data Type":

| Column | Meaning |
|---|---|
| `Collection` | the collection's name — what you select by |
| `Collection Type` | `categorical` or `numeric` |
| `Size` | **overloaded — depends on the type. See below.** |
| `Entities without data` | number of entities that **don't** have a value (categoricals only) |

#### ⚠️ `Size` is NOT a populated count

This is the single most common misreading of `summary`, and it is wrong by orders of magnitude.
**`Size` means two different things depending on `Collection Type`:**

| `Collection Type` | `Size` is… | Example |
|---|---|---|
| `categorical` | the number of **distinct levels** (cardinality) | `Disease Stage` → `7` = seven stage *labels* |
| `numeric` | the number of **variables** in the collection | `Blood Pressure` → `2`; `HbA1c` → `1` |

A categorical showing `Size=7` next to ~65k missing has seven *labels*, not seven entities. For a
numeric, `Size` is your **fan-out factor** — the number of columns that one selection will add.

⚠️ **On a genomics product that factor can be five figures.** Verified on a public TCGA product:
the `Copy Number` collection reports `Size = 24813`, and `select("Copy Number")` returned a
**24,814-column** frame over 10,967 rows — roughly 272 million cells, from selecting what looks
like *one* collection. `Expression` there is another 20,408. **Read `Size` before you select any
numeric**, and if it's large, select individual `Numeric(collection, variable)` axes instead of the
whole collection.

**The honest populated count is `entity_count - Entities without data`.** Derive it; don't read
`Size` for it.

#### `Entities without data` is null for every numeric collection

Verified: 0 of 69 numeric collections on a real product reported it. So `summary` gives you a
missingness picture for **categoricals only** — for any numeric you must pull the column and count
nulls yourself.

#### These fields arrive as comma-formatted strings

`Size`, `Entities without data`, and `info["entity_count"]` come back as strings like `"263,809"`.
Arithmetic on them raises `TypeError: can't multiply sequence by non-int of type 'float'` until you
coerce.

```python
def to_num(x):
    return pd.to_numeric(str(x).replace(",", ""), errors="coerce")

s = fc.summary.copy()
s["n_missing"] = s["Entities without data"].map(to_num)
size          = s["Size"].map(to_num)
is_cat        = s["Collection Type"].eq("categorical")

s["n_levels"]    = size.where(is_cat)          # cardinality, categoricals only
s["n_variables"] = size.where(~is_cat)         # column fan-out, numerics only
s["n_populated"] = (int(to_num(fc.info["entity_count"])) - s["n_missing"]).where(is_cat)
```

**Cardinality is also your payload-safety signal.** A categorical whose `n_levels` approaches or
exceeds the entity count is near-free-text and will bloat a download until the server drops the
connection. Classify these by *measured cardinality*, not by name, so a newly-added free-text column
is caught without anyone maintaining a blocklist:

```python
hazard = s["Collection Type"].eq("categorical") & s["n_levels"].gt(0.02 * n_entities)
```

A level count **above** the entity count is not a bug — it means the collection is **multi-valued**
(one entity carrying several levels at once; see `data-model.md`).

### What `fc.info` returns

Useful keys, all verified: **`entity_name_singular` / `entity_name_plural`** (the grain's noun),
`entity_count`, **`data_version`** and `data_timestamp` (pin these in your notes),
`version` / `data_server_version` (the engine), `commit` (the repo revision the product was built
from), `title` / `description`, `overview_protocol` and `cohort_protocol` (the apps to open in the
UI), and `missing_tests` / `failed_tests` — a non-empty `failed_tests` is a warning about the
product's own health, worth reporting rather than analyzing around.

## Every collection is categorical or numeric

That type decides how you select it and what you can do with it.

| | **Categorical** | **Numeric** |
|---|---|---|
| Holds | labels / text / dates-as-strings | measurements |
| Its variables are | its **distinct values**, auto-derived | **explicitly named** axes |
| Select in R | `` `Department` `` | `` `Blood Pressure = Systolic` `` |
| Select in Python | `"Department"` or `Categorical("Department")` | `Numeric("Blood Pressure", "Systolic")` |
| Use for | grouping, filtering, cross-tabs | averaging, regression, ranges |

A **numeric collection groups related measurements**: one `Blood Pressure` collection holding
`Systolic` and `Diastolic` variables. That's why selecting a numeric needs *both* names — the bare
variable name will not resolve.

## Naming conventions worth recognizing

Real products are consistent in ways that let you predict the shape once you've seen `summary`:

- **A date usually appears twice** — once numeric (a sortable epoch timestamp) and once categorical
  (a `YYYY/MM/DD` display string). A common pattern is `X Date` = **numeric**, `X Calendar Date` =
  **categorical**. The string form is often the cleaner one to parse; timestamps can carry junk
  outliers (year 1900, year 3025) that need clipping.
- **Scores, ages, counts, pressures, volumes** are numeric. **Stages, statuses, lateralities, codes,
  flags, IDs** are categorical.
- **Identifiers** may be categorical (carried for output, not analysis) and can be **very
  high-cardinality** — see the payload warning in `query.md`.
- **A numeric collection may expand into many sub-variables** when it models something like a
  per-entity fitted curve — e.g. one collection yielding `intercept`, `slope_per_year`,
  `baseline_value`, `final_value`, `mean_value`, `n_visits`, `followup_years`. Selecting the
  collection pulls the whole family, so a "single" selection can widen your frame a lot. Check
  `summary` for how many variables a collection has before assuming it's one column.

## Guard your selections against typos

Intersect what you want with what exists, rather than letting a bad name fail the whole query:

```python
available = set(fc.summary["Collection"])
wanted    = ["Department", "Blood Pressure", "Nonexistent Thing"]
use       = [c for c in wanted if c in available]
missing   = [c for c in wanted if c not in available]
if missing:
    print("not in this product:", missing)     # names only — never print data values
```

```r
available <- colnames(fc)
wanted    <- c("Department", "Blood Pressure = Systolic")
use       <- intersect(wanted, available)
setdiff(wanted, available)                      # report what's missing
```

On some SDK versions a bad name raises an unhelpful `TypeError` from deep inside the query builder;
this guard turns that into a clear message.

## Also worth checking before you analyze

- **`fc.info` / the product's title and description** — states the entity noun ("records",
  "encounters", "eyes"). That noun *is* the grain (`data-model.md`).
- **`number_of_entities`** — your row count ceiling. If a pull returns exactly this, you selected
  everything and applied no filter.
- **The data version**, when the product exposes it — pin it in your notes so a rerun months later
  is comparable.
- **The product's own `_AI/about-this-data-product` skill**, if its repo ships one — it names the
  grain, the join keys, and the collection families in the product's own jargon.
