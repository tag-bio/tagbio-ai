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

A transformer **emits a CSV in the FC-ingestion format** — one row per (collection, entity,
value) — which the engine loads back as new collections:

```
data_type,collection_set_name,collection_name,variable_name,auth_groups,entity,value
numeric,,Hypertension Risk,Hypertension Risk,,P001-2024-01-15,0.82
```

The engine invokes each transformer with an **output file path** and the **entity key
collection** to key rows on; the script writes its rows to that file.

## Declaring transformers

Transformers are declared via `data_model.transformers` in the **manifest** (`manifest.md`),
pointing at a transformer-set file. Each entry names a script; the engine runs them in order
after load.

## Example (clinic)

A transformer could add a **`Hypertension Stage`** collection computed from `Blood Pressure`:
self-query the local build for `Systolic`/`Diastolic` per encounter, classify each into a stage,
and emit `categorical` rows keyed by the encounter id — a new collection with no new source
column.

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
