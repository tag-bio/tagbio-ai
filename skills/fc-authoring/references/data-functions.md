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

**collection-set** — a whole `collection_set` at once, optionally filtered by `data_type`, so a
protocol can expose an entire family of collections in one reference:

```json
{ "data_function_type": "collection-set", "collection_set": "Labs", "data_type": "numeric" }
```

**bundle** — groups several data_functions into one reference, so a protocol consumes them
together.

The clinic example includes `systolic_bp_numeric.json`, `department_categorical.json`, and
`labs_numeric_collection_set.json` under `protocols/data_functions/` (the last references the
`Labs` collection_set the lab parsers tag).

## The argument family (bridge to the interactive layer)

A second family — `argument-reference`, `argument-set-reference`, `argument-value` — connects
data_functions to the **interactive argument layer**: what a user selects at run time (a cohort
filter, a chosen variable). These only make sense alongside arguments, so they are covered with
`protocols.md` and `cohort-builder.md`.

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
- **Wrong `data_type` on a collection-set** — filters to the wrong or an empty subset.
- **Reinventing a reference** instead of reusing an existing data_function.

Next: `protocols.md` — the apps that consume these data_functions (focus: R/Python plugins).
