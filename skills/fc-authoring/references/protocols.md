# Protocols — the apps that serve the data product

A **protocol** defines an **app in the UI** that is also invocable as an **API method**. It runs
either a **native** (embedded) method or an **external** R/Python **plugin**, against a subset of
entities, using chosen collections/variables, and returns output (a chart, table, report,
download).

This skill focuses on **`method: external`** — custom R/Python plugins — because that is what you
author. Native methods exist (embedded algorithms and visualizations) but are best understood by
using them in the front-end; they are out of scope here.

## The two parts of a protocol

```jsonc
{
  "protocol_definition": {
    "name": "bp_by_department",              // unique id
    "title": "Blood Pressure by Department",
    "description": "Systolic/diastolic distribution across departments.",
    "asset": "assets/chart.png",
    "argument_sets": [                        // user-customizable parameters (cohort-builder.md)
      "protocols/argument_sets/argument_set_department.json"
    ]
  },

  "script": {
    "method": "external",                     // native | external
    "sdk": "R",                               // R | Python
    "plugin": "protocols/plugins/plugin_bp.R",
    "output_type": "html",

    "background": {                           // WHICH entities (rows) — the cohort
      "data_function_type": "argument-set-reference",
      "argument_set": "department"
    },

    "analysis_variables": [                   // WHICH collections/variables (columns)
      "protocols/data_functions/systolic_bp_numeric.json",
      "protocols/data_functions/department_categorical.json"
    ]
  }
}
```

- **`protocol_definition`** — metadata plus `argument_sets`: the parameters exposed to the user.
- **`script`** — what runs:
  - `method` / `sdk` / `plugin` — run this R or Python plugin file.
  - `output_type` — what it returns (`html`, a download, etc.).
  - **`background`** — the **subset of entities** the analysis runs on: the *rows*, i.e. the
    **cohort**. Usually an `argument-set-reference` so the user chooses it — this is where the
    cohort builder plugs in (`cohort-builder.md`). Omit it and the protocol runs on all entities.
  - **`analysis_variables`** — the **collections/variables** the analysis uses: the *columns*.
    A list of **data_functions** (`data-functions.md`) — fixed ones referenced by path, or
    user-selectable ones via an `argument-set-reference`.

So a protocol wires three things together: a **plugin** (the code), a **background** (which
entities), and **analysis_variables** (which columns). The plugin receives that
entities × variables slice and returns output — authoring the plugin itself is `r.md` / `python.md`.

## Arguments and argument_sets

The user-customizable parameters (a cohort filter, a chosen variable) are **arguments**, bundled
into **argument_sets**, and reached from the script via the `argument-*` data_function types
(`argument-set-reference`, `argument-reference`, `argument-value`). Because they only make sense
interactively, they are covered in depth with the **cohort builder** (`cohort-builder.md`), the
most important protocol to get right.

## Registering protocols: main.json

Protocols do nothing until registered in the FC's **main file** (`main.json`), which also carries
the data product's identity and its tests:

```jsonc
{
  "data_product_definition": { "name": "fc-clinic", "title": "…",
                               "entity_name_singular": "encounter", "entity_name_plural": "encounters" },
  "overview_protocol": "protocols/protocol_overview.json",
  "protocols": [ "protocols/protocol_bp_by_department.json" ],
  "tests":     [ "tests/test_bp_by_department.json" ]
}
```

The **`overview_protocol`** is the product's default **data-overview** view — the landing
protocol shown when the product is opened. It is declared separately from `protocols` so it can
serve as the entry point; a good overview summarizes the entities and headline variables at a
glance.

Every registered protocol should have at least one test; the build auto-registers and auto-tests
internal protocols too (`data-functions.md` on the compile-time validation).

## Recipe: add an external (plugin) protocol

1. Write the **plugin** (`r.md` / `python.md`).
2. Write the **protocol** JSON: `protocol_definition` (name/title/argument_sets) + `script`
   (`method: external`, `sdk`, `plugin`, `output_type`, `background`, `analysis_variables`).
3. Point `background` and `analysis_variables` at **data_functions** (fixed) or
   `argument-set-reference`s (user-chosen).
4. **Register** it in `main.json` and add a test.
5. Rebuild/serve and open it in the UI.

## Common mistakes

- **Forgetting to register** the protocol in `main.json` — it won't appear.
- **No `background`** when you meant to run on a cohort — it silently runs on all entities.
- **`analysis_variables` naming data the model doesn't have** — the referenced data_function
  fails to compile.
- **Reaching for a native method** to teach a Claude — author external plugins instead.

Next: `cohort-builder.md` — the argument layer and the key protocol every FC needs.
