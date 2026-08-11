# The data model — just enough to analyze correctly

You don't need to know how the product was built, but four facts about its model change how you
write analysis code. (The full treatment is in the `fc-authoring` skill.)

```
entity (a row)  ->  collection (a named bucket of values on it)  ->  variable (an axis you analyze by)
```

## 1. The entity grain is what one row means

An FC is **one big table, one row per entity**. The **grain** is what a single entity represents —
a patient, a clinic visit, an eye, a sample, an image. Every count, filter, group, and average is
over entities.

**Find the grain first.** It's in the product's `entity_name_singular` / `entity_name_plural`
(visible via `fc.info` and in the UI's counts), and in its repo's README. Then:

- At **visit** grain, `nrow(df)` is **visits, not patients**. One patient with 30 visits contributes
  30 rows and will dominate any naive mean.
- At a **per-side or per-specimen** grain (eyes, kidneys, tumor blocks, aliquots), one person
  contributes several rows — **not** independent observations. Cluster or collapse accordingly.
- A product is **one grain only**. Sibling products at other grains are separate FCs that join on a
  shared key.

The practical consequence: **decide the unit your question is about, collapse to it, then analyze.**
See `analysis-patterns.md`.

## 2. A row can be heterogeneous

At event/visit grain, records are often **not uniform** — each row carries only the fields relevant
to what happened. A visit row might have a lab result *or* a medication name *or* a diagnosis code,
with the rest null. So:

- **Filter to the record type before aggregating.** Averaging a score across all rows silently
  divides by the wrong denominator.
- Null-heavy columns are usually **normal**, not a data-quality problem.

## 3. Categorical variables are sets, not vectors

The one thing that genuinely surprises data scientists.

A **numeric** variable behaves as expected: a column of values, one per entity — a vector.

A **categorical** collection is different. Each distinct **level** becomes a **one-hot membership
set**: the set of entities carrying that level. `Department == Cardiology` is not a value on each
row — it *is* the set of entities in Cardiology.

Why it matters to you:

- **Server-side filtering is fast set algebra** (intersection/union), which is why cohort filters on
  huge products return quickly.
- **Many-to-many is native.** An entity can hold several levels of one collection at once (a visit
  with two diagnoses is in two sets). So a categorical collection is not always a clean factor — it
  can be a **tag structure**, and a `value_counts()` over it can exceed the number of entities.
- **Exports flatten it back.** A CSV/dataframe extract typically merges a categorical collection's
  one-hot variables into a **single familiar column**, so what you receive usually *looks* like a
  factor. Just don't be surprised when a multi-valued one doesn't.

## 4. Missing means absent, not a level

An entity with no value for a collection is **not in** that collection at all — it is not a
`"missing"` category and not a `0`.

Consequences for every summary you compute:

- **The denominator is "entities that have a value here,"** not all entities. `mean()` and
  `value_counts()` are computed only over entities that have a value; dividing by
  `number_of_entities` understates a rate.
- **Absence is not evidence of a negative result.** "No value for lab X" can mean *not measured* or
  *measured and unrecorded* — you cannot tell from the column. Well-built products model this
  explicitly with a constant **"Has X" flag** on every tested entity; if one exists, use it as your
  denominator instead of inferring from the result column. If it doesn't, say so in your write-up
  rather than assuming.
- Selection on the outcome column is a real bias: restricting to entities *with* a result can turn
  a null finding into a spurious one.

## The `Unique ID` column comes free

The engine **automatically adds a `Unique ID` column** to every extract — the entity's unique-key
combination — even when you don't select it. It is the one guaranteed-unique value per row, so
every row is identifiable and you can always de-duplicate or check for an unexpected fan-out after
a join.

## Collection sets are tags, not folders

A product may group related collections under a **collection_set** (e.g. all lab collections tagged
`Labs`). It is a **flat tag** for search and bulk selection — no hierarchy, no namespace, and it may
span both numeric and categorical collections. Useful for "give me the whole family"; it tells you
nothing about type.
