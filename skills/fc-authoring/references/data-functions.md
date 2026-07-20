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
{ "data_function_type": "numeric", "collection": "Blood Pressure", "variable": "Systolic" }
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
{ "data_function_type": "collection-set", "collection_set": "Labs", "data_type": "numeric" }
```

**bundle** — groups several data_functions into one reference, so a protocol consumes them
together.

**categorical-all** — a built-in reference meaning *all entities* (no filter). Common as a
`background` (run the protocol on everything) or to satisfy a mandatory cohort in a test
(`cohort-builder.md`).

The clinic example includes `numeric_collection_blood_pressure_systolic.json`, `categorical_collection_department.json`, and
`collection_set_labs.json` under `protocols/data_functions/` (the last references the
`Labs` collection_set the lab parsers tag). `protocol_lab_results.json` + `plugin_lab_results.R` are
the worked example that **consumes** that collection-set — the clearest demo of feeding a whole
tagged family into a plugin.

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

Next: `composition.md` — the unifying idea that both parsers and data_functions **nest and compose**,
before we expose them as apps in `protocols.md`.
