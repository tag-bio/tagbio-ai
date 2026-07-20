# Start here — Tag.bio, data products, and FCs

Before any mechanics, the big picture: what Tag.bio is, what a data product is, what an FC is,
how a data product is **used**, and how one is **built**. Everything later in this skill is a
detail of the last question.

## What is Tag.bio?

Tag.bio is a platform for building and serving **data products**: a governed, versioned dataset
paired with interactive analytical apps, so that domain experts can ask and answer questions of
their data without writing code — while analysts and engineers can go deeper programmatically
against the same product.

## What is a data product?

A data product is a single dataset, **modeled once and served many ways**:

- **Governed and versioned** — an immutable, reproducible snapshot of the data. Rebuilding
  produces a new version rather than mutating the old one, so results are always traceable to a
  known state.
- **Modeled** — raw source data reshaped into one consistent analytical model (**entities**
  with **collections** and **variables**) that carries human-readable names, not raw database
  columns.
- **Served** — exposed as interactive apps plus programmatic access, over an API.

The value is that everyone works from the *same* modeled, versioned view — no one re-derives the
dataset in their own spreadsheet or script.

## What is an FC?

An **FC** is Tag.bio's unit of a data product — one data product, in **one git repository**.
(The name comes from the engine, Flux / FluxCapacitor.) The repo holds three things:

- the **configuration** that models the source data into entities/collections,
- the **protocols** that serve it as apps,
- and the **build** that produces the versioned archive.

Throughout this skill, "FC" simply means "a Tag.bio data product."

## How do you *use* a data product?

Once served, users interact with it without ever touching the data model:

- **Protocols** — configurable analytical apps (charts, tables, statistical tests) that answer
  specific questions.
- **The cohort builder** — a user defines a subset of entities (e.g. "encounters in Cardiology
  in 2024"), and every protocol runs against that cohort.
- **Programmatic access** — analysts query the same product from **R or Python** for ad-hoc
  work, against a deployed product or a local build.

Every one of these ultimately **counts, filters, and groups entities** — which is exactly why
the entity grain (the next topic) is the most important modeling decision.

### How a protocol answers a question

The whole runtime, at author altitude, is one loop over the modeled entities:

1. **Which entities?** The user's **cohort** (a protocol's `background`) selects a subset — the
   rows. An empty cohort is all entities.
2. **Which values?** The protocol's **`analysis_variables`** name the collections/variables — the
   columns. Together, rows × columns define a **dataframe**.
3. **Do what?** The protocol's **`method`** runs over that dataframe — an R/Python **plugin**, a
   built-in query (a cohort, a download), or a native visualization — and returns a result.
4. **Arguments** the user set (filters, a chosen variable, a toggle) simply **constrain steps 1–2**
   before the method runs; the client polls until the result is ready.

That is the entire serve-plane model. Everything in this skill — parsers, data_functions, methods,
arguments — is a detail of building the pieces this loop consumes. (The engine's internal request
machinery is out of scope here; you author at this altitude.)

## How do you *build* a data product?

Building has two connected planes, joined by the archive:

```
 SOURCE DATA          BUILD PLANE                    SERVE PLANE
 (CSV / SQL)   ->  config -> data model  -> ARCHIVE -> protocols -> API / apps
                   (entities, collections)  (versioned, (cohort builder,
                                             immutable)   R/Python access)
```

1. **Model the data (config).** Declare the entity grain, point at the source tables (CSV/TSV or
   SQL), and map columns to collections and variables via parsers.
2. **Build the archive (`build_archive`).** The engine reads the sources, applies the config,
   optionally runs transformers, and writes an **immutable, versioned archive**.
3. **Serve it (`run_server`).** Load the archive, compile the protocols, and serve them over an
   API for the apps and SDK access above. Serving never rebuilds the data.

The rest of this skill walks that build path in order — starting with the single most important
decision, the **entity grain** (`entities.md`).

Next: `entities.md` — the entity grain, the decision everything else hangs off of.
