# The manifest — one deployable instance

The **manifest** (`manifest.json`) ties a data product together: what to **build** (the data
model) and what to **serve** (the protocols), plus where the **archive** lives. A build
(`build_archive`), a serve (`run_server`), or a `compile` is pointed at a manifest.

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
- **Cloud-served products** add storage coordinates at the **top level** (bucket + auth) so the
  archive can be fetched from S3 / GCS / Azure; pick the matching server jar
  (`configuration-and-sources.md`).

## Versioning

The archive is **immutable once written**, so a version is simply a distinct archive file. The
example hardcodes `archive.ser`, which a rebuild overwrites — for real versioning, give each build
a distinct archive path (e.g. a dated name), keep the old files, and point `run_server` at whichever
version you want to serve or roll back to.

## Where it's used

- `_shell_scripts/build_archive.sh` → `build_archive manifest=manifest.json`
- `_shell_scripts/run_server.sh` → `run_server manifest=manifest.json`
- `_shell_scripts/compile_local.sh` → `compile manifest=manifest.json` (fast, no data load)
