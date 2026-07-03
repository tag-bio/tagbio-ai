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
aggregate of the other, that is a signal you may need a second entity table — but do not
reach for that until the common case is exhausted.

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

(There is also a within-one-FC middle path — a second entity table for a finer grain whose
tuples must stay aligned — noted below; it keeps one product but adds a grain inside it.)

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
| `labs` | other_table (finer) | lab results **rolled up** onto the encounter as the multi-valued `Lab Result` (+ `Lab Analyte`) |

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

## Common mistakes

- **Choosing the grain to match the data you have, not the questions you'll ask.** Start
  from the questions the FC must answer, then pick the grain those are counted at.
- **A non-unique unique_key.** Duplicate keys silently merge rows into one entity. Check.
- **Modeling a finer grain as the entity "to keep all the detail."** You keep the detail as
  aggregates/collections on the coarser grain; you do not need a row per lab to serve
  lab values on an encounter.
- **Forcing two grains into one entity.** If a parent owns several child tuples whose fields
  must stay aligned, that finer grain may deserve its own entity table — but confirm the
  coarse grain genuinely cannot express it first.

## Recipe: define the entity grain of a new FC

1. List the questions the FC must answer. Note what each one **counts** ("visits,"
   "patients," "results").
2. Pick the grain those counts live at. That table is your **entity_table**.
3. Write the **unique_key** — the minimal column set unique at that grain — and verify
   uniqueness in the source.
4. Classify every other source table as **coarser** (broadcast) or **finer** (roll-up)
   relative to the entity, and note which entity keys each maps on.
5. Only if a finer grain carries aligned tuples the entity cannot flatten, consider a second
   entity table.

Next: `data-model.md` — how the values you just attached (collections and variables) are
actually defined.
