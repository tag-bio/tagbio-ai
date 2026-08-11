---
name: tagbio-analysis
description: >-
  Analyze data in a Tag.bio / Flux data product (an "FC") with the R (`tagbio`) or Python
  (`tagbiopy`) SDK: connect and authenticate, discover collections, pull dataframes, filter
  server-side, join across sibling products, and run the analysis. Use this when querying,
  exploring, extracting from, or analyzing a deployed Tag.bio data product — or serving one
  locally to query it. For *building* a data product (config, parsers, protocols, plugins),
  use the `fc-authoring` skill instead.
---

# Analyzing a Tag.bio Data Product

A **Tag.bio data product** — an **FC** — is a governed, versioned dataset served over an API,
with interactive apps on top. This skill is about **consuming** one as an analyst: connect,
find out what's in it, pull a dataframe, and analyze it correctly.

It is deliberately **product-agnostic and tenant-agnostic**: it names no host, no product, and no
collection. Collection names differ per product; never guess them — **discover them**
(`references/discover.md`). Everything site-specific comes from the environment (`TAGBIO_BASE_URL`,
`~/.tagbio.json`) or from a live `summary`. Examples throughout use the neutral toy vocabulary
(`fc-clinic`, `Department`, `Blood Pressure`) from the public `example-clinic-fc`.

> **Companion skills — check whether they're installed, and install them if not.**
> `fc-authoring` teaches how to *build* an FC (data model, parsers, protocols, plugins). It ships
> in Tag.bio's public repo **github.com/tag-bio/tagbio-ai**, alongside the runnable toy product
> this skill's examples borrow from. It may or may not be present in your environment:
>
> ```bash
> ls -d ~/.claude/skills/fc-authoring                                   # already wired in?
> bash ~/.claude/skills/tagbio-analysis/scripts/install-companions.sh   # clone + wire it up
> ```
>
> It installs as a **peer skill**, invoked by name (`/fc-authoring`). Load it alongside this one
> for anything touching the model — and see `references/companion-skills.md` for the hand-off
> rules, the offline `curl` fallback, and the per-product `_AI/about-this-data-product` skill that
> many product repos ship (the most specific source of all, and where product-specific collection
> names come from).

## The analysis loop

Five steps. Most mistakes come from skipping step 2 or 3.

```
1. CONNECT      host + API key           -> a connection to a named product
2. DISCOVER     summary / colnames       -> the real collection names and types
3. SELECT       the subset you need      -> never "everything"
4. PULL         collect() / .run()       -> a data.frame / pandas DataFrame
5. ANALYZE      in R or pandas           -> stats, models, charts
```

The single most important structural fact, which decides how you write steps 3–5: **an FC is one
big table with one row per entity.** The **entity grain** is what one row means — a patient, a
visit, an eye, a sample. Every count, filter, and average is over entities. If you don't know the
grain, you don't know what your `nrow()` means. See `references/data-model.md`.

## Reading order

| # | Read | Topic |
|---|------|-------|
| 1 | `references/environment.md` | **Start here.** What the Tag.bio notebook already gives you; SDK versions and their limits. |
| 2 | `references/connect.md` | Auth, the three connection targets, and the exact working connection recipe. |
| 3 | `references/discover.md` | Listing collections and their types — do this before every query. |
| 4 | `references/data-model.md` | Entity grain, collections vs variables, and why categoricals behave oddly. |
| 5 | `references/query.md` | Selecting, column naming, server-side filters, payload limits. |
| 6 | `references/analysis-patterns.md` | Collapse-then-join, longitudinal work, caching, honest endpoints. |
| — | `references/local-fc.md` | Serving an FC locally (`run_server`) and querying it — the notebook has the jars. |
| — | `references/companion-skills.md` | The public `tagbio-ai` repo: installing `fc-authoring`, and when to hand off to it. |
| — | `references/troubleshooting.md` | Symptom → cause for the errors you'll actually hit. |

## Golden rules

1. **Discover before you select.** Collection names are product-specific and case-sensitive; a
   guessed name fails or silently returns nothing. `summary` costs under a second.
2. **Never pull everything.** Selecting all collections on a large product streams every row of
   every column and dies on a ~2-minute gateway timeout. Select the subset you need. For a full
   export, use the product's **front-end download protocol** — it exports server-side.
3. **Know the grain before you aggregate.** At visit grain, "count of rows" is visits, not
   patients. Collapse to one row per subject *before* joining or testing.
4. **A numeric variable is `Collection` + `Variable`, and the two SDKs name it differently** —
   R `Collection = Variable`, Python `Collection: Variable`. This asymmetry causes real bugs
   when porting code. A **plugin** frame always carries the prefix; an ad-hoc `select()` may not
   (`query.md`).
5. **`summary["Size"]` is overloaded and is never a populated count** — level-cardinality for
   categoricals, variable-count for numerics (and for a genomics numeric it can exceed **24,000**,
   which is your column fan-out). In Python the populated count is
   `entity_count - Entities without data`, null for every numeric; **in R that column is inverted**
   and the populated count is `collection_entity_count` itself (`discover.md`). Misreading either is
   wrong by orders of magnitude, and the R/Python inversion is silent.
   **Also: the two SDKs' `summary` frames don't even share column names** — check them before
   porting any block between R and Python.
6. **Missing means absent, not a level.** Denominators are "entities that have a value here,"
   not all entities (`references/data-model.md`).
7. **Verify, don't recall.** The running product is the source of truth. When your memory and a
   fresh `summary` disagree, `summary` wins.

## Guardrails

Non-negotiable. Treat each as a hard constraint.

1. **Consent before data access.** Before running *any* query that pulls real data from a
   deployed product, tell the user plainly what you are about to access and get their agreement.
   **Writing and explaining query code is always fine; executing it is the gated act.**

2. **For proprietary or regulated (PHI-shaped) products, require explicit attestation** — per
   request, not as a standing waiver. The requester must affirm, in their own words:
   - **Authorization** — they may access this product's data;
   - **Compliant environment** — where the code runs and where the data will land is approved for
     this data's classification, and the AI tool in use is covered by the appropriate agreement
     (BAA / DPA);
   - **Boundary** — the pulled data won't be sent to, cached by, or displayed in any system not
     covered by that agreement.

   Until all three are given: **hand back the code, do not run it.** This does not apply to a
   non-sensitive demo product or a local `localhost` dev build.

3. **Never echo data values.** Report **counts, column names, dtypes, and structure** — not rows.
   Printing a `head()` of a patient table puts PHI in the transcript. Prefer `df.shape`,
   `df.columns`, `value_counts()` on a non-identifying field, and aggregate summaries.

4. **Treat extracts as sensitive.** A written CSV/parquet, a cached pickle, and a notebook's saved
   output cells all carry the data. Keep them out of git, out of shared directories, and clear
   notebook outputs before committing.

5. **Never hardcode or commit credentials.** The API key lives in `~/.tagbio.json`
   (`chmod 600`), never in a script, notebook, config, or commit. Rotate it if it leaks.
