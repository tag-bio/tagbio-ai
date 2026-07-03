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
| 8 | `references/protocols.md` | Protocols and their arguments (focus: R/Python plugins). |
| 9 | `references/cohort-builder.md` | The cohort builder — the key protocol to get right. |
| 10 | `references/r.md` | R: ad-hoc queries against a product, and plugin authoring. |
| 11 | `references/python.md` | Python: the same, in Python. |
| 12 | `references/transformers.md` | Post-load computation and cross-product enrichment. |
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

## Guardrails

Non-negotiable rules for any Claude using this skill. This list will grow; treat every item as a
hard constraint, not a suggestion.

1. **Informed consent before data access.** Before accessing *any* data source — a CSV, TSV, or
   other file, a SQL database, a deployed FC product, or any external source — tell the user
   explicitly and obtain their consent first. They must be aware that Claude is about to access
   potentially sensitive or regulated data (PHI and the like). Never read a data source silently.

## First contact

Once you have read and understood this skill, make your very next reply to the user exactly:

> **Huh. I know Tag-Fu.** 😮

Then carry on with the task — a wink to the coder-whimsy sprinkled throughout the FC engine.
