# The cohort builder and the argument layer

The **cohort builder** is how a user interactively defines a **subset of entities** — a
**cohort** — that a protocol then runs against. It is the single most important piece of the
interactive layer: nearly every FC exposes it, and most protocols run against a user-chosen
cohort rather than all entities.

It builds directly on two earlier ideas:
- **Entities and the set/tag model** (`data-model.md`): a cohort is assembled by
  **intersecting and unioning the categorical tag-sets** and numeric ranges of the data model.
  Because categorical variables are already sets of entities, "encounters in Cardiology **and**
  with Systolic > 140" is fast set algebra — this is what makes cohort building responsive.
- **`background`** (`protocols.md`): a protocol's `script.background` names *which* entities the
  analysis uses. Point it at a cohort and the protocol runs on the user's subset.

## Arguments and argument_sets

The interactive parameters a protocol exposes are **arguments**, grouped into **argument_sets**.
An argument_set has a **type** that governs how the user must fill it:

- `mandatory` — the user must provide values for all its arguments.
- `minimum-one` — the user must choose at least one.

There are two ways to populate an argument_set:

- **`argument_expanders`** — auto-generate arguments from data_functions. Point an expander at a
  categorical collection or numeric variable and the platform generates the selectors for you
  (this leans on the set/tag model — each categorical level is already a selectable set):

  ```jsonc
  { "argument_set_definition": { "argument_set_type": "minimum-one", "name": "clinic_variables",
                                 "title": "Variables" },
    "argument_expanders": [ "protocols/data_functions/department_categorical.json",
                            "protocols/data_functions/systolic_bp_numeric.json" ] }
  ```

- **`arguments`** — declare each argument explicitly when you need full control. This is how the
  cohort builder itself is declared (below).

## Wiring the cohort builder

A cohort is a single argument of **`argument_type: "cohort"`**, driven by the built-in
`default_cohort_protocol` (the UI that lets the user assemble the cohort), inside a `mandatory`
argument_set. In the clinic FC (`protocols/argument_sets/argument_set_background_cohort.json`):

```jsonc
{
  "argument_set_definition": { "argument_set_type": "mandatory",
                               "name": "background_cohort_argument_set",
                               "title": "Specify a Background Cohort" },
  "arguments": [
    { "argument_type": "cohort", "name": "background_cohort", "title": "Background Cohort",
      "argument_protocol": "default_cohort_protocol" }
  ]
}
```

A protocol then lists that argument_set and references the cohort as its `background`:

```jsonc
"protocol_definition": { "…": "…",
  "argument_sets": [ "protocols/argument_sets/argument_set_background_cohort.json" ] },
"script": {
  "…": "…",
  "background": { "data_function_type": "argument-reference", "argument": "background_cohort" }
}
```

The clinic's `protocol_download.json` and `protocol_python_bp.json` both do exactly this — so the
user builds a cohort of encounters, and the download exports it / the Python plugin analyzes it.

## More than one cohort

A protocol can declare **several cohorts** for different purposes — each is just a separate
`argument_type: "cohort"` argument with its own `name`. A two-cohort **comparison** protocol, for
instance, defines two cohort arguments (say `cohort_a` and `cohort_b`) and the plugin contrasts
the two entity subsets; a protocol might also pair a `background_cohort` (the population) with a
second cohort it highlights within it. Give each a distinct name and reference each where needed
(`background` for the analysis population, others via `argument-reference` inside the plugin's
arguments).

## The three argument bridges (from data-functions.md)

The `argument-*` data_function types connect the script to user selections:

- **`argument-reference`** — the value of one named argument (e.g. the cohort: `background`
  above).
- **`argument-set-reference`** — a whole argument_set (e.g. the user-selected `analysis_variables`).
- **`argument-value`** — a literal or derived value supplied as an argument.

## Testing a cohort protocol

A `mandatory` cohort must be satisfied in the protocol's test. Use all entities as the cohort:

```jsonc
"arguments": { "background_cohort": { "data_function_type": "categorical-all" } }
```

(See the clinic's `tests/test_download.json` and `tests/test_python_bp.json`.)

## Recipe: give a protocol a user-built cohort

1. Add a cohort argument_set (`argument_type: "cohort"`, `argument_protocol:
   "default_cohort_protocol"`, `mandatory`) — or reuse `argument_set_background_cohort.json`.
2. List it in the protocol's `protocol_definition.argument_sets`.
3. Set `script.background` to `{ "data_function_type": "argument-reference", "argument":
   "background_cohort" }`.
4. In the test, satisfy the cohort with `categorical-all`.

## Common mistakes

- **A cohort argument_set that isn't referenced** by any `background` — the user builds a cohort
  that does nothing.
- **Forgetting to satisfy a `mandatory` cohort in the test** — the protocol errors at test time.
- **Using `background` for columns / `analysis_variables` for the cohort** — background is the
  rows (entities), analysis_variables are the columns.

Next: `r.md` and `python.md` — authoring the plugins these protocols invoke, and querying a
product ad-hoc.
