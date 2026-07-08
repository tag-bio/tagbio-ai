# Transformers — computing new collections after load

A **transformer** is a script (R, Python, or bash) that runs **during the build**, after the
data model is loaded but before the archive is written, and **adds new collections** to the
product. Use one when a collection must be *computed* rather than parsed from a source column —
a derived category, a score, or a value pulled from another product.

## How a transformer works

During `build_archive`, the engine stands up a **transient HTTP server** over the in-progress
build so a transformer can query it, then runs each transformer, then writes the archive:

- **Self-query the local build** (the product being built): `tagConnect()` with **no host_url**,
  `tbl(con)` with **no table name** (`r.md`). This is how you read collections that already
  exist in *this* build to compute new ones.
- **Pull from another deployed product** (cross-product enrichment): `tagConnect(host_url = …)`
  and `tbl(con, "other-product")`. This is how one FC broadcasts values derived from a related,
  already-deployed FC.
- **Pull from a *locally-served* dependency** (deploy outage, or building both together): serve the
  dependency on a **non-default port** (`run_server … port=7999`) and point the transformer at it —
  `tagConnect(host_url = "http://localhost:7999")`, **bare `tbl(con)`** (single-FC serve, `r.md`).
  Use a port ≠ 8000 so it doesn't collide with the build's own transformer-callback server. When
  the two builds run **near-concurrently**, the dependency's server may not be up when this
  transformer starts — so **poll until it can serve a pull** (retry `tbl(con) %>% select(<a
  column>) %>% collect()` with a `Sys.sleep`/deadline loop) instead of failing on a not-yet-ready
  server. A long-running earlier transformer (e.g. a PRS step) also naturally covers the startup gap.

A transformer **emits a CSV in the FC-ingestion format** — one row per (collection, entity,
value) — which the engine loads back as new collections. The columns are fixed:

```
data_type,collection_set_name,collection_name,variable_name,auth_groups,entity,value
numeric,,Hypertension Risk,Hypertension Risk,,E1001,0.82
categorical,,Hypertension Stage,Stage 2,,E1001,Stage 2
```

- **`entity`** is the value that keys the row to an entity — a value of the transformer's
  declared **`entity_collection`** (below), not the internal unique key.
- For a **numeric** row, `variable_name` is the variable and `value` is the number.
- For a **categorical** row, `variable_name` is the **tag/level** the entity gets. `value` is used
  only as a **presence guard** — the engine tags the entity when it is non-empty and **skips the row
  when it is empty** (that is the mechanism for "this entity has no value here", not a convention).
  It is not stored, so just repeat the level in it.
- A blank `collection_set_name` / `auth_groups` means "none" / "visible to all".

The engine invokes each transformer with two arguments appended to its `command` — an **output
file path** and the **entity_collection** name — and the script writes its rows to that path. A
transformer may **add** collections but **cannot override an existing** one (the build errors).

## Declaring transformers

Transformers are declared via `data_model.transformers` in the **manifest** (`manifest.md`),
pointing at a transformer-set file — a JSON array of entries:

```json
[
  {
    "name": "hypertension_stage",
    "command": "Rscript config/transformers/hypertension_stage.R",
    "entity_collection": "Encounter ID",
    "allow_null": true
  }
]
```

- **`command`** is run as `command <output_file> "<entity_collection>"`.
- **`entity_collection`** names the collection whose values the `entity` column holds (here
  `Encounter ID`, one value per encounter).
- **`allow_null: true`** tolerates output rows whose entity key isn't in the build instead of
  aborting. The engine runs the entries **in order** after load.

## Example (clinic — shipped and runnable)

The example FC ships a working transformer. `config/transformers/hypertension_stage.R`
self-queries the local build for each encounter's `Blood Pressure = Systolic` /
`Blood Pressure = Diastolic` (a numeric variable is exposed as `Collection = Variable`, `r.md`),
classifies each into an ACC/AHA stage, and emits `categorical` rows keyed by `Encounter ID`. It
is registered in `config/transformers.json` and wired via `data_model.transformers` in
`manifest.json`. After a build, the new **`Hypertension Stage`** collection (Normal / Elevated /
Stage 1 / Stage 2) appears in `data_dictionary.tsv` — a collection with no new source column.

## Build order and cross-product pulls

- **Same-build data → self-query the local build.** A deployed copy will not yet have the
  collection you are adding (chicken-and-egg).
- **Cross-product data → the source product must be built and deployed first.** This creates a
  real build-order dependency between FCs.
- The build is therefore **not hermetic** when transformers pull from other products — account
  for that in the deploy pipeline.

## When a rebuild is required

Any change to a transformer, or to a source product it pulls from, requires **rebuilding** the
consuming FC's archive — transformers run at build time, not serve time.

> **Guardrail:** a transformer that pulls from another product or an external source is a data
> access — obtain the user's **informed consent** and confirm the source (see `SKILL.md` →
> Guardrails).

## Recipe: add a transformer

A transformer can be **R, Python, or bash** — the language is irrelevant to the engine, which only
cares about the two arguments in and the ingestion CSV out. The **shipped worked example is R**
(`config/transformers/hypertension_stage.R`). A **Python** transformer is the same shape — self-query
the local build with `tagbiopy` (the no-`fc_name` localhost form, `python.md`) and write the same CSV:

```python
import sys, csv
import tagbiopy.fc
from tagbiopy.fundamentals import Numeric

output_file = sys.argv[1]            # arg 1: output CSV path   (arg 2 = entity_collection name)
fc = tagbiopy.fc.FC(host="http://localhost:8000")               # the local build server; no fc_name
df = fc.df.select("Encounter ID", Numeric("Blood Pressure", "Systolic")).run()
sys_col = next(c for c in df.columns if c.endswith("Systolic"))  # "Blood Pressure: Systolic"

# Use csv.writer (never hand-format with f-strings) so a comma/newline in an entity value or label
# is quoted, not injected into the ingestion CSV.
with open(output_file, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["data_type", "collection_set_name", "collection_name",
                "variable_name", "auth_groups", "entity", "value"])
    for _, row in df.iterrows():
        s = row[sys_col]
        if s != s:               # skip NaN
            continue
        level = "High" if s >= 140 else "Not High"
        w.writerow(["categorical", "", "BP Flag", level, "", row["Encounter ID"], level])
```

Register it like the R one (`"command": "python3 config/transformers/<name>.py"`). A **bash**
transformer just shells out to whatever produces those rows.

> **The port isn't magic.** The local build server runs on the **default port 8000**. R's
> `tagConnect()` isn't dynamically discovering it — it simply **defaults to `http://localhost:8000`**
> too; Python just names that URL explicitly. Both hit the same fixed port. If you build the server
> on a **non-default `port=`**, match it in the Python `host=` (R picks it up from `TAGBIO_HOST_URL`).

1. Write the script (R/Python/bash) taking an output-file path and the entity key collection.
2. Read inputs by self-querying the local build (or pulling a deployed product).
3. Compute values and write FC-ingestion rows (`data_type,collection_set_name,collection_name,
   variable_name,auth_groups,entity,value`) to the output file.
4. Register it in the config's transformer set; rebuild.

## Common mistakes

- **Self-querying a deployed copy for this build's new data** — it isn't there yet; query the
  local build.
- **A cross-product pull without the build-order dependency** — the source product must be
  deployed first.
- **Expecting a transformer to run at serve time** — it runs only during `build_archive`.

That completes the build path. Return to `SKILL.md` for the reading order and golden rules.
