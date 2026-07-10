# The manifest — one deployable instance

The **manifest** (`manifest.json`) ties a data product together: what to **build** (the data
model) and what to **serve** (the protocols), plus where the **archive** lives. A build
(`build_archive`), a serve (`run_server`), or a `compile` is pointed at a manifest.

> **manifest.json vs `deploy/deployments.yml`.** The manifest is what you use **locally** — it
> drives `compile` / `build_archive` / `run_server` on your machine. **`deployments.yml`** is the
> **cluster** deployment descriptor (`governance.md`): one entry per served instance, carrying the
> archive location, the cloud jar, JVM sizing, and secrets. They overlap in spirit (both point at a
> config/main and an archive) but serve different stages — think "manifest = dev, deployments.yml =
> production." You author and test with the manifest; you deploy with `deployments.yml`.

## Shape

```jsonc
{
  // Identity (may also live in main.json; the manifest wins when both are present).
  "data_product_definition": {
    "name": "fc-clinic",
    "title": "Clinic FC (example)",
    "entity_name_singular": "encounter",
    "entity_name_plural": "encounters"
  },

  // The BUILD side — inputs build_archive needs (gated OFF for run_server, which loads the archive).
  "data_model": {
    "config": "config/config.json",        // the data-model config (entities, parsers)
    "data_dir": "./",                       // base directory for CSV/TSV file paths
    "log": "build.log"                      // where the build writes its log
    // "transformers": "config/transformers.json",        // optional — see transformers.md
    // "sql_connection": "../connection/connection.json"  // for SQL sources (configuration-and-sources.md)
  },

  // The SERVE side — inputs run_server needs (gated OFF for build_archive).
  "serve": {
    "main": "main.json"                     // registered protocols + tests
    // "run_tests": "true"                  // optionally execute tests when serving
  },

  // The immutable artifact that connects the two planes: build writes it, serve reads it.
  "archive": "archive.ser"
}
```

- **`data_model`** vs **`serve`** — the command gates which half is used: `build_archive` builds
  `data_model` and skips `serve`; `run_server` loads the `archive` and skips `data_model`;
  `compile` validates both without loading data.
- **`archive`** — the versioned, immutable output (`overview.md`).
- **`data_product_definition`** — the product's **identity**: `name` (the id used in URLs/API and to
  address it, e.g. `tbl(con, "fc-clinic")`) and `title` plus the **`entity_name_singular` /
  `entity_name_plural`** — the noun the **UI** uses when it labels and counts entities ("8
  **encounters**", "this **encounter**"). Set them to your grain's real-world noun; they are
  cosmetic but user-facing.
- **Why identity can live in both `main.json` and the manifest:** `main.json` carries the product's
  *own* identity (used when you serve it directly), while the manifest can **override** it
  **per deployed instance** — so two instances built from the same `main` can present different
  names/titles. When both set it, **the manifest wins**. Put it in `main.json` for the single-instance
  case; override in the manifest only when an instance needs to differ.
- **Cloud-served products** add storage coordinates at the **top level** (bucket + auth) so the
  archive can be fetched from S3 / GCS / Azure; pick the matching server jar
  (`configuration-and-sources.md`).

## One repo, many instances

A single repo can define **several deployable instances**, each its own **manifest** (and its own
deployment entry, `governance.md`). What varies between instances lives in the **manifest**, not
necessarily in the config — and this is deliberately flexible:

- **Same config + same main, different source.** For an FC built around a common **schema**, one
  instance can source from a **public** dataset and another from a **private** one — identical
  `config` and `main.json`, different manifests (different source/connection, archive, deployment).
  The data model and the apps are the same; only where the data comes from differs.
- **Different config, same grain.** A **fixed-date snapshot** vs a live build, or a differently
  filtered source, is a second manifest pointing at a **different config** at the *same* grain.
- **Different config, different grain = a genuinely different FC.** A different entity grain means
  different `unique_keys`, hence a different config (`entities.md`: one FC has one grain). It is
  still just another manifest in the same repo.

So "another FC" is really "another manifest/deployment"; whether it reuses the config and main or
swaps them is up to you. (When several instances share one `main`, every collection that `main`'s
protocols reference must exist in **every** instance's build.)

## Versioning

The archive is **immutable once written**, so a version is simply a distinct archive file. The
example hardcodes `archive.ser`, which a rebuild overwrites — for real versioning, give each build
a distinct archive path (e.g. a dated name), keep the old files, and point `run_server` at whichever
version you want to serve or roll back to.

## Where it's used

- `_shell_scripts/build_archive.sh` → `build_archive manifest=manifest.json`
- `_shell_scripts/run_server.sh` → `run_server manifest=manifest.json`
- `_shell_scripts/compile_local.sh` → `compile manifest=manifest.json` (fast, no data load)

That completes the build path. Return to `SKILL.md` for the reading order and golden rules.
