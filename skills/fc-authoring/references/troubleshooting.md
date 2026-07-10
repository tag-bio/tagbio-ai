# Troubleshooting — reading the log and the common failures

FC config is **schema-less and forgiving**, so most problems show up not as an error but as a
*build that succeeds with something missing*. This guide is the debugging companion to
`dev-loop.md`: how to read the log, and a checklist for the failures you'll actually hit. The
root reflex: **an unknown attribute is silently ignored** (`files-and-value-resolution.md` → the
silent-typo trap), so a misspelled key just vanishes.

## Reading `build.log`

The build writes a log (path set by `data_model.log`, or `log=` on the CLI); raise `verbosity`
(0–5) for more. Read it top-to-bottom and look for:

- **Per-table load lines** — how many rows each source contributed. A table that loaded **0 rows**
  (or far fewer than expected) is a bad path, delimiter, `where` filter, or join that dropped
  everything.
- **"N entities loaded into data model"** — the entity count. Wrong number → a unique_key that
  isn't unique (rows merged) or an entity_table that didn't load.
- **"Post-processing of N parsers complete"** — how many parsers ran. Fewer than you wrote → a
  parser was skipped (often a typo'd attribute).
- **The generated `data_dictionary.tsv`** — the ground truth of what got built: every collection,
  its variables, and entity counts. If a collection isn't here, it wasn't produced.
- **`WARN` / `DETAIL` lines** — some are benign (e.g. a `DETAIL: 'parsers' not found in config`
  when your parsers are nested in the tables is just the engine checking for an optional top-level
  `parsers` array you're not using — harmless). Read them, but not every one is a problem.

## "My collection didn't appear" — checklist

The single most common symptom. Work down it:

1. **Attribute spelling.** `collcetion`, `unqiue_keys`, `varaible`, `table_alais` — a misspelled
   key is dropped silently. Check the exact names against `parsers.md` / `catalog-table-types.md`.
2. **The parser's table actually loaded.** Check the per-table row count in the log. No rows → no
   collection.
3. **The `column` exists in the source** and is spelled exactly (case matters). A parser over a
   nonexistent column produces nothing.
4. **The join/mapping resolved.** For an other_table, the `id_columns` must line up real columns,
   and a finer key must be in the entity_table's `foreign_keys` — otherwise rows don't attach.
5. **The name isn't colliding.** Collection names are unique **per type** (`reference` rules) —
   two categorical collections can't share a name; two collections of the same name silently
   converge or conflict.
6. **It's in `data_dictionary.tsv`?** If yes, it built and the problem is downstream (a
   data_function/protocol referencing it by the wrong name). If no, it's a build/parse problem
   above.

## Compile / protocol errors

`compile` (fast, no data — `dev-loop.md`) catches these:

- **"data_function … could not resolve" / naming a collection that doesn't exist.** The name in
  the data_function must match the built collection **exactly** (`data-functions.md`). Confirm it
  in `data_dictionary.tsv`; watch numeric variables, which the SDK exposes as
  `Collection = Variable` (`r.md`).
- **"protocol has no test" (coverage gap).** A protocol with a **mandatory argument** needs an
  explicit `tests/*.json`; ones with no arguments are auto-tested (`testing.md`).
- **argument-reference with no handler (WARN).** If you want the *value* a user chose, use
  `argument-value`, not `argument-reference` (`catalog-data-function-types.md`).
- **A mandatory/minimum-one argument unsatisfied** in a test → the protocol errors; supply the
  argument (satisfy a cohort with `categorical-all`).

## Build / runtime errors

- **"Unique parser incomplete values" / duplicate-key crash.** Usually the unique_key isn't
  actually unique at the chosen grain (two rows share it). Verify uniqueness in the source; if
  duplicates are legitimate, the grain is wrong (`entities.md`).
- **Datetime values silently dropped.** The `pattern` doesn't match the raw format, or the column
  mixes formats / partial dates. Verify the raw values; split mixed formats (`parsers.md`).
- **Transformer: "invalid entity key for entity_collection."** The `entity` values your script
  emitted don't match any value of the declared `entity_collection`. Confirm you keyed on the
  right identity collection and are emitting its exact values (`transformers.md`); `allow_null:
  true` tolerates strays.
- **Transformer: "cannot override existing collection."** A transformer may only **add** a
  collection, not replace one the config already built — rename it.
- **Plugin: "no package called 'X'."** The R/Python library isn't in that FC's build-container /
  environment; install it there (`r.md` / `python.md`).
- **A run that hangs or a query that "takes forever"** can be normal on a large FC — long runtimes
  are not automatically pathological. Validate logic on a bounded smoke-test subset before blaming
  performance.

## When two runs disagree

If a build is non-deterministic (an entity count or a "unique incomplete values" error that comes
and goes), suspect the **source changing under you** — a database row removed mid-build, a file
being rewritten — rather than the engine. Rebuild in a quiet window and compare the two logs'
per-table counts.

## The reflex, in order

1. Did `compile` pass? (references + coverage)
2. Did the **table load rows**? (log)
3. Is the collection in **`data_dictionary.tsv`**? (built or not)
4. Does the downstream name **match exactly**? (data_function / protocol)
5. Still stuck → raise `verbosity`, read `build.log` around the failure.
