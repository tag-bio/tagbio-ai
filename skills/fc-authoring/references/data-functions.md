# Data functions — how protocols reference the data model

A **data_function** is a **named, reusable reference into the data model** that a protocol points
at instead of hard-coding a collection or variable name. It is the bridge between the data model
(collections/variables, `data-model.md`) and the protocols (the apps, `protocols.md`): protocols
and their arguments consume data_functions, and the build **compiles every data_function to a
valid data reference** — so a data_function naming a nonexistent collection fails the build (much
of what the auto-tests check).

Why the indirection: it decouples protocols from exact data-model names, lets one reference be
reused across many protocols, and gives the compiler one place to confirm every reference
resolves.

They live modularly, one per file, under `protocols/data_functions/`, referenced by path from
protocols and arguments.

## The common types

**numeric** — a numeric collection and one of its variables:

```json
{
  "data_function_type": "numeric",
  "collection": "Blood Pressure",
  "variable": "Systolic"
}
```

**categorical** — a categorical collection (its levels are the sets/tags from `data-model.md`):

```json
{ "data_function_type": "categorical", "collection": "Department" }
```

**collection-set** — a whole `collection_set` at once, so a protocol can expose an entire tagged
family of collections in one reference. By default it yields **all** collections in the set, of
**every** data type:

```json
{ "data_function_type": "collection-set", "collection_set": "Labs" }
```

`data_type` (`numeric` / `categorical` / `numeric-matrix` / `categorical-matrix`) is an **optional**
field, not required — you mainly need it when a collection-set feeds an **auto-generated argument**,
which can bind only one type at a time. When present it *also* restricts the members here to that one
type; a collection-set is not fundamentally a type filter. A misspelled `data_type` errors at compile:

```json
{
  "data_function_type": "collection-set",
  "collection_set": "Labs",
  "data_type": "numeric"
}
```

**bundle** — groups several data_functions into one reference, so a protocol consumes them
together.

**categorical-all** — a built-in reference meaning *all entities* (no filter). Common as a
`background` (run the protocol on everything) or to satisfy a mandatory cohort in a test
(`cohort-builder.md`).

**Data that may not exist yet: `allow_null: true`.** A `categorical`, `numeric` or matrix reference
to a collection or variable that isn't in the data throws ("Variable was not found within the
collection") and fails the protocol. With `"allow_null": true` it resolves to nothing instead, and
the protocol runs without it. Use it where the data arrives later, such as a measurement no
entity has yet, and have the app say what's missing; it picks the data up on the next build with no
change. The clinic example has no `Mean Arterial` blood pressure: without `allow_null` a download
asking for it fails, and with it the download returns the other columns:

```json
{ "data_function_type": "numeric", "collection": "Blood Pressure",
  "variable": "Mean Arterial", "allow_null": true }
```

The clinic example includes `numeric_collection_blood_pressure_systolic.json`, `categorical_collection_department.json`, and
`collection_set_labs.json` under `protocols/data_functions/` (the last references the
`Labs` collection_set the lab parsers tag). `protocol_lab_results.json` + `plugin_lab_results.R` are
the worked example that **consumes** that collection-set — the clearest demo of feeding a whole
tagged family into a plugin.

## Matrix data functions

A matrix reference names the collection, plus a `variable` to pick one matrix variable:

```jsonc
{ "data_function_type": "numeric-matrix", "collection": "Labs" }                                // every lab
{ "data_function_type": "categorical-matrix", "collection": "Procedures", "variable": "Surgery" } // one event
```

To slice or reshape a matrix, wrap the reference in one of these. Putting slicing attributes
(`criteria`, `columns`, `minimum`, `maximum`, `background`) directly on a plain reference is an
old form: it still works, but logs a deprecation warning. Use `matrix-slice` instead.

| data_function_type | Does | Key attributes |
|---|---|---|
| `matrix-slice` | keeps part of a matrix | `matrix` (required); `criteria` (the columns to keep, e.g. `numeric` gene references); `columns` (header names); `minimum`/`maximum` + `pattern` (a calendar window on datetime headers); `background` (entities: a `categorical` reference **with a `variable`**) |
| `matrix-transform-relative` | re-times the `criteria` matrices relative to each entity's anchor | the anchor is either `matrix` (an event, with `merge` `first`/`last` picking the occurrence) or `numeric` (a date variable); `start`/`end` window; `time_units` (`weeks`, `days`, `hours`, `minutes`, `seconds`) or `translate` (milliseconds per unit) |
| `numeric-matrix-to-numeric` | collapses each matrix variable to one number per entity | `criteria`, `merge` (`avg`, `sum`, `first`, `last`, `min`, `max`) |
| `categorical-matrix-to-numeric` | counts each entity's events | `criteria` |
| `categorical-matrix-to-categorical` | the entity *ever* had the event | `criteria` |
| `numeric-matrix-compound` | scores a gene set per entity | `matrix`, `operator: "gsea"`, `criteria` (the gene set), `bidirectional`, `background` |

These compose. "Max CRP within 14 days after first surgery" is a relative window inside a
collapse:

```jsonc
{ "data_function_type": "numeric-matrix-to-numeric", "merge": "max",
  "criteria": [ { "data_function_type": "matrix-transform-relative",
                  "matrix": { "data_function_type": "categorical-matrix", "collection": "Procedures", "variable": "Surgery" },
                  "merge": "first", "start": 0, "end": 14, "time_units": "days",
                  "criteria": [ { "data_function_type": "numeric-matrix", "collection": "Labs" } ] } ] }
```

**Gene-signature scores (`gsea`).** Scores are **signed** by default: positive when the set's
genes rank high in the entity, negative when they rank low. `"bidirectional": true` counts either
extreme as enrichment, so scores are unsigned. Always set a `background` when the matrix has a
`null_value`, so that entities without data get no score rather than a score computed from
zeros:

```jsonc
{ "data_function_type": "numeric-matrix-compound",
  "matrix": { "data_function_type": "numeric-matrix", "collection": "Expression Matrix", "variable": "Expression Matrix" },
  "operator": "gsea",
  "background": { "data_function_type": "categorical", "collection": "Has Expression Data", "variable": "Yes" },
  "criteria": [ { "data_function_type": "numeric", "collection": "Expression", "variable": "G1" },
                { "data_function_type": "numeric", "collection": "Expression", "variable": "G2" } ] }
```

**Matrices in downloads.**
- **Wide (the default):** one column per variable × header, named `Variable = header`
  (`CRP = 2024-01-09 07:00:00 UTC`, `Expression Matrix = G1`). An empty cell means no value.
  Categorical matrix cells are 1/0.
- **Tall:** pass the matrix as `key_value_matrix` to get one row per stored cell. The columns are
  `key-value collection`, `key-value variable`, `key` (the header) and `value` (numeric; 1 for
  categorical events). Use it for sparse or very wide matrices.
- **Parquet versus CSV:** Parquet types matrix cells as `double`. CSV rounds to display digits;
  Parquet doesn't, so `use_float` values show float precision (`3.0999999` where CSV shows `3.1`).

## The argument family (bridge to the interactive layer)

A second family — `argument-reference`, `argument-set-reference`, `argument-value` — connects
data_functions to the **interactive argument layer**: what a user selects at run time (a cohort
filter, a chosen variable). These only make sense alongside arguments, so they are covered with
`protocols.md` and `cohort-builder.md`.

Beyond these there is a **set-algebra** family (`set-intersection`, `set-union`,
`categorical-opposite`, `filter`, …) for composing cohorts from other cohorts. The full
enumeration — data-model types, the argument bridge, set algebra, and the `argument_type` /
`output_type` lists — is in **`catalog-data-function-types.md`** (load on demand).

## Recipe: expose a variable to protocols

1. Confirm the collection/variable exists in the data model (`parsers.md`) — the name must match
   **exactly**.
2. Write a data_function of the matching type (`numeric` / `categorical`) naming that collection
   (and variable), or a `collection-set` for a whole tagged family.
3. Reference it from the protocol or argument that needs it (`protocols.md`).
4. Rebuild; the compiler validates that it resolves.

## Common mistakes

- **Naming a collection/variable that doesn't exist** (or a typo) — the build fails to compile
  the reference. Names must match the data model exactly.
- **Adding `data_type` to a collection-set when you meant "all types"** — it's optional; omit it to
  get every collection in the set. A misspelled value errors at compile; a valid but mismatched one
  yields an empty subset.
- **Reinventing a reference** instead of reusing an existing data_function.
- **A gsea score without a `background` on a `null_value` matrix.** Entities with no data are
  scored from their zero rows. Use the "has data" flag (`parsers.md`).
- **A whole collection as a matrix `background`.** It needs a single `variable` (`"Yes"`); a bare
  collection errors with "requires a 'variable'".

Next: `composition.md` — the unifying idea that both parsers and data_functions **nest and compose**,
before we expose them as apps in `protocols.md`.
