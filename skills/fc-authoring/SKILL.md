---
name: fc-authoring
description: >-
  Author a Flux data product (an "FC") from scratch or extend one: data modeling from
  CSV/TSV or SQL sources, entities (the grain), collections and variables, parsers,
  data_functions, protocols (the cohort builder and R/Python plugins), and transformers.
  Use this when building, configuring, or debugging a Flux FC repository.
---

# Authoring a Flux Data Product (FC)

An **FC** is a Flux data product: it turns source data into a **versioned, immutable data
product** that is served as a set of API-driven analytical apps. One FC lives in **one git
repository**. This skill teaches how to build one from nothing.

Work through the reference files in the order below. Do not skip ahead: each topic assumes
the previous one. **Entities come first and matter most** — the entity grain is the single
decision that constrains everything downstream.

## The mental model: two planes

An FC has a **build plane** and a **serve plane**, connected by the archive.

```
 SOURCE DATA          BUILD PLANE                    SERVE PLANE
 (CSV / SQL)   ->  config -> data model  -> ARCHIVE -> protocols -> API / apps
                   (entities, collections)  (.ser,     (cohort builder,
                                             immutable)  R/Python plugins)
```

- **Build** (`build_archive`): read source data, apply the config to produce the data
  model (entities + their collections/variables), optionally run transformers, and write
  an immutable, versioned **archive**.
- **Serve** (`run_server`): load an existing archive, compile the **protocols** (the apps),
  and serve them over an API. Serving never rebuilds the data.

The archive is the contract between the two planes: build writes it, serve reads it.

> **Read `references/dev-loop.md` early and keep it open.** FC config is schema-less and
> typo-tolerant, so mistakes surface late. The `compile → build → run_server → test` loop — the
> fast `compile` check most of all — is how you catch them. Validate as you go.

> **Where are the engine jars? Match the work to the environment — a missing *local* jar is not a
> blocker.** The build/serve dev loop (`compile` / `compile_local`, `build_archive`, `run_server`,
> tests) run the Flux **engine jars**. `tagbio-ai/setup.sh` fetches them into
> `example-clinic-fc/_jars/` (the default; override with `TAGBIO_JARS`) — **the public download URL is
> being finalized and lands shortly; until then, drop the jars there by hand** (deliberate, tracked
> placeholder — not broken). An environment may therefore not have them locally yet. That splits
> the work three ways:
> - **Ad-hoc query** (`r.md` / `python.md` → a deployed production FC over the SDK) needs **no jars**
>   and works anywhere. Self-contained; the primary path for a consumer/analyst.
> - **Authoring** config and R/Python plugins is just editing files — **no jars needed** either.
> - **Running** the jar steps (`compile_local`, `build_archive`, `run_server`, tests) **requires the
>   jars.** If they're not present locally, **do NOT try to run them locally — they'll fail.**
>   Instead, **produce the scripts/commands and guide the developer to run those steps in the
>   Tag.bio-provided remote Notebook environment, which has the jars.**
>
> So never treat "no local jars" as broken: **query and author locally, and hand jar-execution to the
> Notebook.** (A jar-distribution mechanism will be documented here in the future.)

## Reading order

| # | Read | Topic |
|---|------|-------|
| 1 | `references/overview.md` | **Start here.** What Tag.bio, a data product, and an FC are; how one is used and built. |
| 2 | `references/entities.md` | **Entities — the grain.** The most important modeling decision. |
| 3 | `references/data-model.md` | Collections vs variables — the values on entities. |
| 4 | `references/files-and-value-resolution.md` | JSON/YAML, flexible value resolution, inline vs modular — applies to config **and** protocols. |
| 5 | `references/configuration-and-sources.md` | The config; loading from CSV/TSV and SQL; joining adjunct tables. |
| 6 | `references/parsers.md` | How parsers turn source columns into collections and variables. |
| 7 | `references/data-functions.md` | How protocols reference the data model. |
| 8 | `references/composition.md` | **The unifying idea** — parsers and data_functions nest and compose. |
| 9 | `references/protocols.md` | Protocols and their arguments (focus: R/Python plugins). |
| 10 | `references/arguments.md` | The interactive argument types, argument_sets, expanders, handlers. |
| 11 | `references/cohort-builder.md` | The cohort builder — the key protocol to get right. |
| 12 | `references/r.md` | R: ad-hoc queries against a product, and plugin authoring. |
| 13 | `references/python.md` | Python: the same, in Python. |
| 14 | `references/transformers.md` | Post-load computation and cross-product enrichment. |
| 15 | `references/manifest.md` | The manifest — ties build + serve, where the archive lives, versioning. |
| — | `references/dev-loop.md` | **Practical, read early.** The edit→compile→build→serve→test loop. |
| — | `references/testing.md` | The test JSON, when tests run, how failures surface. |
| — | `references/governance.md` | Deployment, `run_server` auth, `auth_groups`, versioned deploys. |
| — | `references/troubleshooting.md` | Reading `build.log`; "my collection didn't appear" checklists. |
| — | `references/catalog-*.md` | Full enumerations of parser / table / data_function types — load on demand. |

Spine in one line: **entities → data model → sourced & parsed → referenced (data_functions)
→ exposed (protocols, cohort builder) → coded (R/Python) → post-processed (transformers).**

## The worked example

Every reference file uses one small, fictional **clinic** FC, in `example-clinic-fc/`:

- **Source tables:** `patients`, `encounters`, `labs` (tiny CSVs in `example-clinic-fc/data/`).
- **Entity grain:** one **encounter** (a patient visit). Everything else — patient
  attributes, lab results — is attached to or aggregated onto that grain.

It is deliberately generic. When you build a real FC, copy its shape, not its domain.

## Golden rules (details in the reference files)

1. **Decide the entity grain first.** It determines what every protocol counts and filters.
2. **Collection names are human-readable English** ("Encounter Date"), never raw database
   column names (`enc_dt`).
3. **Config is the data model; protocols are the apps.** Keep the two separate in your head.
4. **Build is immutable and versioned.** A rebuild produces a new archive; serving never
   changes data.
5. **Prefer the common types; reach for the catalog only when the common ones do not fit.**
6. **JSON and YAML are interchangeable, and values resolve flexibly** — a string can be a file
   path to the value, an object can stand in for a one-element array. Don't expect strict-schema
   validation. See `files-and-value-resolution.md`.
7. **Prefer verification over recall.** The running engine is the source of truth: when your memory
   and a fresh `compile` disagree, **the compile wins**. Run the loop, read the output, and treat a
   passing test as "didn't crash," not "correct." See `dev-loop.md`.

## Guardrails

Non-negotiable rules for any Claude using this skill. This list will grow; treat every item as a
hard constraint, not a suggestion.

1. **Informed consent before data access.** Before accessing *any* data source — a CSV, TSV, or
   other file, a SQL database, a deployed FC product, or any external source — tell the user
   explicitly and obtain their consent first. They must be aware that Claude is about to access
   potentially sensitive or regulated data (PHI and the like). Never read a data source silently.

2. **Never echo data values.** Do not print, quote, log, or paste **data values** into your
   responses. Report on data at the level of counts, column names, and structure — not rows.
   Reading a patient CSV to "help debug" and then quoting a row puts PHI into the transcript.

3. **Treat build/serve artifacts as sensitive.** `_test_results/*` (rendered protocol output),
   `build.log` (can contain raw source values from a failing parser), and `data_dictionary.tsv`
   (the built collections/variables) can all carry real data. Don't open and paste their contents;
   don't share them outside the environment.

4. **Never commit data or its byproducts.** No source data files, archives (`*.ser`), logs
   (`build.log`), `data_dictionary.tsv`, or diagnostic output go into git — for a real FC these are
   PHI or leak it. Keep them gitignored. (The example FC ships tiny **synthetic, fictional** clinic
   data purely to be runnable and to teach; a real FC's data is **never** committed. Treat the toy
   as the exception that states the rule.)

5. **Never hardcode or commit credentials.** API keys, tokens, **SQL connection details**
   (host/user/password in a `sql_connection` file), and **cloud storage auth** (S3/GCS/Azure keys
   and secrets) come from environment variables or an out-of-repo source (`~/.tagbio.json`, a
   secret store / `secretRef`) — **never** written into a config, a connection file, a protocol, a
   script, or otherwise committed to the repo (`governance.md`). A connection file that carries real
   credentials stays out of git; the toy's `connection_sql.json` is committable only because it
   points at a local SQLite path with no secret.
