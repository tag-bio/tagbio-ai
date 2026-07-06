# Collections and variables — the values on entities

Entities (`entities.md`) are the **rows** of the data model. This file is about what fills
those rows — **collections** — and what you analyze by — **variables**.

The whole chain, to keep in view:

```
source column  ->  parser  ->  collection (+ optional variable)  ->  data_function  ->  protocol
```

This file covers the middle: collections and variables. Parsers are in `parsers.md`,
data_functions in `data-functions.md`.

## Collections: the values on entities

A **collection** is a named bucket of values attached to entities — think of it as a column
in the entity frame. Each entity may have **one value, no value, or several values**;
collections can be **multi-valued**. A collection has a type — categorical (labels/text),
numeric, or date/time.

Clinic examples (`example-clinic-fc/`):

| Collection | Type | Source | Notes |
|---|---|---|---|
| `Encounter Date` | date | `encounters.encounter_date` | the entity's own date |
| `Department` | categorical | `encounters.department` | one label per encounter |
| `Diagnosis` | categorical | `encounters.diagnosis` | one label per encounter |
| `Patient Region` | categorical | `patients.region` (broadcast) | one value, repeated across the patient's encounters |
| `Patient Age` | numeric | `patients.age` (broadcast) | one value per encounter |
| `Blood Pressure` | numeric | `encounters.systolic_bp`, `encounters.diastolic_bp` | one collection grouping the `Systolic` and `Diastolic` variables |
| `Lab Result` | numeric | `labs.result_value` (roll-up) | multi-valued — one value per lab drawn; pair with `Lab Analyte` to know which |

**Naming rule:** collection names are **human-readable English** — `Encounter Date`, not
`enc_dt`. This is non-negotiable; the names are the analyst-facing surface of the product.

**Multi-valued collections** are normal. An encounter with both an LDL and an HDL lab has two
values in a single `Lab Result` collection; whether you model that as one multi-valued
`Lab Result` or as separate `LDL Result` / `HDL Result` collections is a design choice
(`parsers.md`). Multi-valued collections interact with grain — a value repeated by broadcast
(`Patient Region`) counts once per entity, but a genuinely multi-valued collection can
multi-count if analyzed carelessly (`entities.md`).

## Variables: the dimensions you analyze by

A **variable** is a named analytical dimension the FC's protocols can **filter, group, and
aggregate by**. A **collection contains one or more variables**, and how they arise depends on
the collection's type:

- A **numeric or date** collection holds one or more **explicitly named** variables, each a
  measurable axis. A single collection often *groups related measurements*: a `Blood Pressure`
  collection holds a `Systolic` variable and a `Diastolic` variable (from the
  `systolic_bp`/`diastolic_bp` columns), and you filter `Systolic > 140` or average
  `Diastolic`. This grouping is exactly why variable names only need to be unique *within* a
  collection (see Naming and uniqueness below).
- A **categorical** collection's **distinct values** are its variables, generated
  automatically — a `Department` collection yields `Cardiology`, `Endocrinology`,
  `Primary Care`, … which you filter or group by.

Not every collection needs variables you analyze by — some are carried only to be displayed or
exported (an identifier, say).

> Mental model: a **collection** is a *named group of values on the entity*; a **variable** is
> *one dimension you slice the entities by*.

## Categorical variables are sets, not vectors

A crucial architectural point — and the one most likely to surprise a data scientist.

A **numeric** variable behaves like a named **column of values** — a *vector*, one value per
entity — which is why numerics bundle naturally into a collection (`Blood Pressure` holding
`Systolic` and `Diastolic`).

A **categorical** variable does not work that way. When a categorical column is parsed, each
distinct **level** becomes a variable that is a **one-hot encoding**, and internally that
variable is a **set**: the entities that have that level. `Department == Cardiology` is not a
value sitting on each row — it is *the set of encounters in Cardiology*.

This is deliberate and powerful:

- **Slicing is set algebra.** `variable == Cardiology` is random-access retrieval of that set,
  and combining criteria is fast **union / intersection** of sets — the core of why cohort
  building and filtering are fast.
- **Many-to-many is native.** An entity can belong to several level-sets at once (an encounter
  with two diagnoses is in two sets), handled by the very same machinery as the ordinary
  mutually-exclusive one-to-many case.

The mental-model shift: a data scientist expects a categorical *variable* to be a **factor**
carrying all its levels. Here, the **collection** is the factor; each **variable** is one
level's membership **set** — a **tag**. (When the values are many-to-many with entities, the
collection is less a clean factor than a tag structure.)

> Practical note: CSV / dataframe **exports** from an FC typically **merge** the one-hot
> variables of a categorical collection back into a single column, so an export looks like the
> familiar factor column even though internally it is a set of tags.

> **Scale caveat:** parsing a **high-cardinality identifier** (e.g. a unique `Encounter ID`) as
> `categorical` makes one set per distinct value — fine for a few thousand entities, a real cost at
> millions. Parse an ID only if you need it for display/output, and don't expose it as an analysis
> variable. (Overall memory is tuned at serve time with `-Xmx` — see `governance.md`; the model
> above is the bigger lever than the heap.)

> **Missing values at query time.** A missing value is an **absence**, not a level. An entity with
> no value for a numeric collection is simply **not in** that collection's vector; an entity with
> no categorical value is **in none** of that collection's tag-sets — it is not a "missing" tag.
> So a numeric summary or a categorical count is computed **only over entities that have a value**,
> and the right denominator is "entities with a value here," not all entities. When "was this even
> measured?" matters (a test run on only a subset), model it **explicitly** — a constant "Has X"
> flag on every tested entity (`catalog-parser-types.md` → `categorical-static`) — rather than
> inferring it from the presence or absence of a result.

## collection_set: a tag for grouping, not a container

A **collection_set** is a **flat tag** attached to collections for search, filtering, and bulk
exposure — *not* a hierarchical container. Tagging `Lab Panel`, `Lab Analyte`, and
`Lab Result` with a `Labs` set lets a protocol pick up all of them at once (a data_function
can expand over the whole set — see `data-functions.md`). But because it is only a tag:

- it **cannot disambiguate or segregate** collections — it provides no namespace, so it can
  never make two otherwise-colliding names coexist;
- a single set tag may be applied to **both numeric and categorical** collections; the tag
  says nothing about type. Collections and collection_sets are **many-to-many** — a
  collection may carry several set tags, and one set tags many collections.

Reach for a collection_set when a family of collections should be selectable or analyzable
together — but treat it as a label, not a folder.

## Naming and uniqueness

The platform enforces specific name-uniqueness rules. Getting them wrong causes collisions at
build time, so design names with them in mind.

- **Collection names are unique across the data model — per type.** No two collections may
  share a name, with one exception: a **numeric** collection and a **categorical** collection
  may share a name. (A collection is effectively identified by name *and* type.) This
  exception is useful on purpose — for example a numeric `Patient Age` (the value) alongside a
  categorical `Patient Age` (age bands) — but lean on it deliberately, not by accident.
- **Variable names are unique within their collection, not globally.** Two different
  collections `A` and `B` may each contain a variable named `C`; a variable name only has to
  be unique among the variables of its own collection.
- **Collection sets provide no namespace** (they are flat tags — see above), so they cannot be
  used to separate collections that would otherwise collide by name and type.

## Clinic recap

| Source column | Collection | Variable(s) |
|---|---|---|
| `encounters.encounter_date` | `Encounter Date` | date axis (filter by period) |
| `encounters.department` | `Department` | distinct values — `Cardiology`, `Endocrinology`, … |
| `encounters.diagnosis` | `Diagnosis` | distinct values |
| `encounters.systolic_bp` | `Blood Pressure` | `Systolic` |
| `encounters.diastolic_bp` | `Blood Pressure` | `Diastolic` |
| `patients.region` | `Patient Region` | distinct values (broadcast) |
| `patients.age` | `Patient Age` | numeric axis |
| `labs.result_value` | `Lab Result` | numeric axis (multi-valued) |
| `encounters.encounter_id` | `Encounter ID` | none — carried for identity/output, not analysis |

## Common mistakes

- **Naming collections after database columns.** Always human-readable English.
- **Making every collection a variable.** Expose as variables only what users actually
  analyze by; the rest clutters the analysis surface.
- **Ignoring multi-value at the wrong grain.** A multi-valued collection can multi-count;
  know whether a collection is single-valued (or broadcast) before you analyze by it.
- **Treating a collection_set as a container.** It is a flat tag — it groups collections for
  search and exposure but gives no namespace and no hierarchy, and cannot separate two
  collections that collide by name and type.

Next: `configuration-and-sources.md` — the config file that declares the entity_table, the
source tables (CSV/TSV and SQL), and how adjunct tables join.
