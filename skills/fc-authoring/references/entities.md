# Entities — the grain

> The data model starts here (read `overview.md` first for the big picture). The entity grain
> is the one decision that constrains everything else in the FC. Get it right and the rest of
> the data model falls into place; get it wrong and every protocol counts the wrong thing.

## What an entity is

An **entity** is the unit of analysis of the FC. The data model is, at its core, one big
table — the **entity frame** — with **one row per entity**. Every protocol the FC serves
ultimately **counts, filters, and groups entities**: "how many entities match this cohort,"
"what is the average of this value across these entities," and so on.

So the first question is never "what columns do I have" — it is:

> **What is one row? What does a single entity represent?**

That choice is the **grain**.

## Grain: the decision that matters most

The same source data can be modeled at different grains, and each answers different
questions. Take the clinic example (`example-clinic-fc/data/`), which has three source
tables at three natural grains:

| Source table | Natural grain | One row is… |
|---|---|---|
| `patients` | coarsest | one person |
| `encounters` | middle | one clinic visit |
| `labs` | finest | one lab result within a visit |

If you make the **patient** the entity, "count of entities" means *number of people* — you
cannot ask "how many visits were in Cardiology," because visits are now multi-valued lists
hidden inside a patient row. If you make the **lab result** the entity, a single visit is
counted once per lab drawn — "number of entities in March" over-counts visits.

For this FC we choose the **encounter** as the entity: **one row per clinic visit.** It is
the grain most questions are about ("encounters by department," "encounters with an elevated
systolic reading"), and the other two grains attach to it cleanly (see below).

**How to choose the grain:** pick the level at which the FC's main questions are counted.
Everything coarser becomes an *attribute* of the entity; everything finer becomes an
*aggregate* onto the entity. If two candidate grains both seem essential and neither is an
aggregate of the other, that is a signal you may need **two FCs** — one at each grain — because
**one FC has exactly one entity grain**. Do not reach for that until the common case is exhausted.

## When the questions span multiple grains

Often the FC must answer questions at more than one grain — in the clinic, "how many
encounters were in Cardiology" (encounter grain) alongside "how many patients have ever had
an elevated systolic reading" (patient grain). At Tag.bio this is one of the very first decisions on a new
project. The word to keep straight is **aggregation**, which happens in two different places:

- **Build-time aggregation** collapses finer source rows to reach a coarser entity grain
  *when the FC is modeled* (rolling several labs up into one encounter).
- **Query-time aggregation** groups entity rows up to a coarser level *at analysis time*
  (counting distinct patients across many encounters).

Two clean architectures trade these off:

1. **One FC at the lowest grain.** Model a single product at the finest grain the questions
   need. No build-time aggregation — every source row is preserved as an entity, nothing is
   hidden, one product to maintain. The cost: any higher-grain question must **aggregate at
   query time**, and a naive count multi-counts (one patient's five encounters count as five,
   not one).

2. **Multiple FCs from the same repo/data at different grains.** Build and deploy more than
   one product from the same source and repository — say a patient-grain FC and an
   encounter-grain FC — each doing its own **build-time aggregation** to reach its grain. Each
   product then **counts once** at its grain with no query-time aggregation; you direct
   developers/users to the one that fits their question. The cost: several products to build,
   deploy, and maintain, and users must know which to pick.

The framing question to ask at the very start of a project:

> **What are the different levels of grain in this data, what questions and analyses will be
> run, and should this be one FC at the lowest grain (to prevent build-time aggregation and
> keep every row) or multiple FCs at different levels of grain (each aggregating at build time
> so analyses count once)?**

These two architectures are the whole menu — **an FC has exactly one grain**. There is no
middle path that mixes two grains inside a single product; when you truly need both, you build
two FCs (option 2). (What a single FC *can* have is more than one entity *source* at the **same**
grain — see below.)

## unique_keys: what makes one entity one entity

An entity is identified by its **unique_keys** — the column (or set of columns) whose
combination is unique per entity. For the clinic encounter:

```
entity:      encounter
unique_key:  [patient_id, encounter_date]
```

That composite key says "one entity per patient per visit-date." Composite keys are the
norm in real FCs — an entity is often "this subject, at this time" or "this subject, on this
side." (A single natural key also works: `encounter_id` alone is unique here and could be
the key. Composite keys are shown because they are the case people get wrong.)

The unique_key must be **genuinely unique** in the source at the chosen grain. If two source
rows share the key, they collapse into one entity — sometimes what you want (deduplication),
often a bug. Verify uniqueness before trusting the grain.

## entity_table vs other_tables

Two roles for source tables in the config:

- The **entity_table** is the source that *defines the grain*. Its rows become entities.
  Here: `encounters` → one entity per `[patient_id, encounter_date]`.
- **other_tables** are adjunct sources *joined onto* the existing entities to enrich them.
  They do **not** create entities; they attach values to entities that already exist.

The clinic FC:

| Table | Role | Attaches to the encounter as… |
|---|---|---|
| `encounters` | entity_table | the entity itself (Encounter Date, Department, Diagnosis) |
| `patients` | other_table (coarser) | patient attributes **broadcast** onto every encounter (Sex, Region, Age) |
| `labs` | other_table (finer) | lab results **rolled up** onto the encounter — each panel a numeric collection, each analyte its variable (`Lipid → LDL`); see the tuple-alignment note below |

An other_table declares how it maps to entities via its key columns. A coarser table
(`patients`) maps on a **subset** of the entity's keys (`patient_id` only) — one patient row
fans out to all that patient's encounters ("broadcast"). A finer table (`labs`) maps on the
full grain (its rows belong to a specific encounter) and its many rows per entity become a
multi-valued collection or an aggregate. The exact mapping syntax is in
`configuration-and-sources.md`; the mental model is what matters here:

> The entity_table sets the grain. Everything coarser broadcasts down onto it; everything
> finer rolls up onto it.

## How this looks in the config (sketch)

Just enough to connect the idea to the file — full schema in `configuration-and-sources.md`:

```jsonc
{
  "entity_table": {
    "table": "encounters",                    // defines the grain
    "unique_keys": ["patient_id", "encounter_date"],
    "foreign_keys": ["encounter_id"]          // extra join key for finer tables (inside entity_table)
  },
  "other_tables": [
    { "table": "patients", "table_alias": "patients",
      "id_columns": { "patient_id": "patient_id" } },      // broadcast (subset of key)
    { "table": "labs", "table_alias": "labs",
      "id_columns": { "encounter_id": "encounter_id" } }   // roll-up (via foreign_key)
  ]
}
```

## Multiple entity *sources* at the same grain (`entity_tables`)

A single FC still has **one grain**, but that grain's entities may arrive **split across several
sources**. For that, the config takes a plural **`entity_tables`** — the tables are **unioned**
into one entity set, and they must therefore **share the same `unique_keys`**:

```jsonc
{
  "entity_tables": [
    { "table": "encounters_2023", "unique_keys": ["patient_id", "encounter_date"] },
    { "table": "encounters_2024", "unique_keys": ["patient_id", "encounter_date"] }
  ]
}
```

This is **not** a way to mix grains — every entity_table here is the *same* encounter grain, just
sourced from more than one file/table. (Different grains → different FCs, above.)

### When a finer grain has tuples that must stay aligned

Roll-up (a finer child table onto the entity) can lose **tuple alignment**: if a parent owns several
child records whose fields must stay together (a lab result *with its* analyte, a mutation *with its*
allele frequency), flattening each field into its own parallel list breaks the pairing — value #3 of
one list no longer reliably matches value #3 of another. Three fixes, in order of preference:

1. **Let each child name its own collection/variable from the data.** When the child rows are an
   `(attribute, value)` pair, a nested parser can derive the collection and variable *names* from the
   attribute column, so each value lands in its own variable and pairing is automatic — *and the value
   keeps its type*. The toy's labs do exactly this: `labs.panel` → the numeric collection (`Lipid`),
   `labs.analyte` → the variable (`LDL`), so `Lipid → LDL = 142` is unambiguous and still numeric
   (`parsers.md`, dynamic naming). This is *not* values-as-schema — the names come from the data, so a
   new analyte just appears. **Prefer this whenever the child is attribute-keyed.**
2. **Combine the paired fields into a single tuple-carrying value** on the coarse grain — one
   "Result with Unit" collection whose every value carries the whole tuple (`"LDL 142 mg/dL"`). The
   fallback when the tuple has several fields that don't reduce to one attribute→variable mapping; note
   the value becomes categorical, so you lose numeric analysis on it.
3. **Build a separate FC at the finer grain** (option 2 above), where that child *is* the entity and
   its fields are plain per-entity collections. Reach here when the finer grain is important enough to
   analyze in its own right — the case where you need it kept numeric *and* paired at that grain.

There is no in-between that keeps two grains in one product — resist inventing one.

## Common mistakes

- **Choosing the grain to match the data you have, not the questions you'll ask.** Start
  from the questions the FC must answer, then pick the grain those are counted at.
- **A non-unique unique_key.** Duplicate keys silently merge rows into one entity. Check.
- **Modeling a finer grain as the entity "to keep all the detail."** You keep the detail as
  aggregates/collections on the coarser grain; you do not need a row per lab to serve
  lab values on an encounter.
- **Trying to put two grains in one FC.** An FC has exactly one grain. If a parent owns several
  child tuples whose fields must stay aligned, first give each its own dynamically-named
  collection/variable (or combine them into single tuple-carrying values) on the coarse grain; if
  the finer grain truly must be analyzed on its own, that is a **separate FC**, not a second entity
  table.

## Recipe: define the entity grain of a new FC

1. List the questions the FC must answer. Note what each one **counts** ("visits,"
   "patients," "results").
2. Pick the grain those counts live at. That table is your **entity_table**.
3. Write the **unique_key** — the minimal column set unique at that grain — and verify
   uniqueness in the source.
4. Classify every other source table as **coarser** (broadcast) or **finer** (roll-up)
   relative to the entity, and note which entity keys each maps on.
5. If a finer grain carries aligned tuples the entity cannot flatten, name each from the data
   (dynamic collection/variable) or combine them into single values first; if it must be analyzed
   in its own right, plan a **separate FC** at that grain (an FC has exactly one grain —
   `entity_tables` unions *same-grain* sources only).

Next: `data-model.md` — how the values you just attached (collections and variables) are
actually defined.
