# Protocols — the apps that serve the data product

A **protocol** defines an **app in the UI** that is also invocable as an **API method**. It runs
either a **native** (embedded) method or an **external** R/Python **plugin**, against a subset of
entities, using chosen collections/variables, and returns output (a chart, table, report,
download).

This skill focuses on **`method: external`** — custom R/Python plugins — because that is what you
author. **Native methods** (embedded algorithms and visualizations) exist and are common in real
FCs, but they're driven by the front end and can't be usefully described from the FC codebase
alone — **a dedicated treatment is TBD** (a future addition). For now, if you're extending an FC
that already uses native-method protocols, lean on the front end and existing examples. A few
built-in **utility** methods also exist — notably `method: "download"`, which exports the cohort's
data (the example's `download` protocol uses it).

## The two parts of a protocol

```jsonc
{
  "protocol_definition": {
    "name": "python_bp",                      // unique id
    "title": "Blood Pressure Report (Python)",
    "description": "Blood pressure distributions for a chosen cohort, rendered by a Python plugin.",
    "argument_sets": [                        // user-customizable parameters (cohort-builder.md)
      "protocols/argument_sets/argument_set_background_cohort.json"
    ]
  },

  "script": {
    "method": "external",                     // native | external
    "sdk": "connect_tagbio_py",               // "R" or "connect_tagbio_py"
    "plugin": "protocols/plugins/plugin_bp.py",
    "output_type": "html",

    "background": {                           // WHICH entities (rows) — the cohort
      "data_function_type": "argument-value",  // a cohort is passed by value (cohort-builder.md)
      "argument": "background_cohort"
    },

    "analysis_variables": [                   // WHICH collections/variables (columns)
      "protocols/data_functions/categorical_collection_department.json",
      "protocols/data_functions/numeric_collection_blood_pressure_systolic.json",
      "protocols/data_functions/numeric_collection_blood_pressure_diastolic.json"
    ]
  }
}
```

- **`protocol_definition`** — metadata plus `argument_sets`: the parameters exposed to the user. It
  can also carry an **`asset`** — a thumbnail image (a file in the FC's `assets/` directory) shown on
  the app's tile in the UI; an **argument_set** can carry an `asset` too (`arguments.md`). And
  **access attributes**: **`groups`** (restrict who may run this protocol) and **`download_groups`**
  (restrict who may convert its result into a raw **download** — an export gate, so everyone can see a
  summary but only some can export rows). See `governance.md`.
- **`script`** — what runs. Three fields carry the weight — **`method`**, **`background`**,
  **`analysis_variables`**:
  - **`method`** — **always required.** `external` (an R/Python plugin) or `native` (embedded);
    plus utility methods like `download`. With `external`, add `sdk` (`"R"` or
    `"connect_tagbio_py"`), `plugin` (the plugin file), and `output_type` (`html`, a download, …).
  - **`background`** — the **subset of entities** the analysis runs on: the *rows*, i.e. the
    **cohort**. Usually an `argument-value` referencing a cohort argument so the user chooses it —
    this is where the cohort builder plugs in (`cohort-builder.md`; a cohort is passed by value, not
    via a handler). **Defaults to all entities** if omitted.
  - **`analysis_variables`** — the **collections/variables** the analysis uses: the *columns*.
    A list of **data_functions** (`data-functions.md`) — fixed ones referenced by path, or
    user-selectable ones via an `argument-set-reference`. **Defaults to all collections** if
    omitted (rarely what you want — name the columns you need).

So the three define a **dataframe**: `background` picks the **rows**, `analysis_variables` the
**columns** — plus a **`Unique ID`** column the engine always adds automatically (the entity's
unique-key combination, the one guaranteed-unique value per row), even if you don't list it. For
`method: external`, **the R/Python SDK extracts that dataframe into memory *before* the plugin
runs**, and the plugin reads it from its input parameter (`tag_data` — via `get_results()` in R,
`tag_data.df` in Python) rather than querying anything itself. Authoring the
plugin is `r.md` / `python.md`.

## Method types

`method` names **which kind of query** the protocol runs over the data model. A handful matter:

- **`external`** — an R/Python **plugin**. The flagship; what you author (`r.md` / `python.md`).
- **`entity`** — returns a **set of entities**, i.e. a **cohort**. This is the method the **cohort
  builder** uses (`protocol_cohort.json` → `cohort-builder.md`). Reach for it whenever a protocol's
  job is to *define a subset* rather than analyze one.
- **`download`** — a built-in utility that **exports** the cohort's data (the toy's `download`
  protocol). A "download everything" app is always worth shipping.
- **`summary`** — a built-in visualization/summary; also the method many **argument_protocols** run
  under.
- **`collection`** / **`variable`** — used almost exclusively by the **argument layer**: the
  auto-generated `argument_protocol` behind a filter fetches its options or values with one of these.
- **`native`** — other embedded methods (front-end-driven; TBD, above).

The nuance worth internalizing: **`argument_expanders` autogenerate an `argument_protocol` for each
filter, and that helper protocol has a `method` too** — usually `summary` / `collection` / `variable`.
So those methods surface not because you write them directly, but because the argument machinery
generates them (`arguments.md`). You mostly hand-write `external`, `entity`, and `download`.

## Arguments and argument_sets

The user-customizable parameters (a cohort filter, a chosen variable) are **arguments**, bundled
into **argument_sets**, and reached from the script via the `argument-*` data_function types
(`argument-set-reference`, `argument-reference`, `argument-value`). Because they only make sense
interactively, they are covered in depth with the **cohort builder** (`cohort-builder.md`), the
most important protocol to get right.

## Registering protocols: main.json

A **top-level** protocol — an app the user launches directly — must be listed in the FC's **main
file** (`main.json`), which also carries the product's identity and its tests:

```jsonc
{
  "data_product_definition": { "name": "fc-clinic", "title": "…",
                               "entity_name_singular": "encounter", "entity_name_plural": "encounters" },
  "protocols": [ "protocols/protocol_bp_by_department.json" ],
  "tests":     [ "tests/test_bp_by_department.json" ]
}
```

**Helper protocols don't go here.** A protocol referenced by **file path** from another protocol —
an **`argument_protocol`** (a cohort builder, a filter's value-fetcher), a handler protocol, etc. —
is **discovered and registered automatically** as the compiler traverses the protocols that
reference it. So `protocol_cohort.json` is *not* in `main.json`, yet it works: the cohort argument
points at it by path and the compiler picks it up. (Historically protocols were referenced by a
name **string**, which the compiler couldn't follow, so everything had to be registered in
`main.json`; **file-path** references made helper protocols self-discovering. List only the
user-launched apps in `protocols[]`.)

An **optional** `overview_protocol` field designates a default **data-overview** view — the
landing protocol shown when the product opens, declared separately from `protocols`. The clinic
example omits it; when present, a good overview summarizes the entities and headline variables at
a glance.

Every top-level protocol should have at least one test; the build auto-registers and auto-tests the
file-referenced helper protocols too (`data-functions.md`, `testing.md`).

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

Next: `arguments.md` — the interactive argument types, argument_sets, expanders, and handlers
that protocols expose (and that the cohort builder is built from).
