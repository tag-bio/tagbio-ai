# Parsers — turning source columns into collections and variables

A **parser** typically reads one column of a source table and produces a **collection** (and,
for some types, one or more named **variables**) — but neither of those is a hard limit: many
parser types accept a `columns` attribute to read several columns, and a parser can emit
**multiple collections** (see "Beyond one column, one collection" below). Parsers live
**inside the table object they read** (`configuration-and-sources.md`), so they need no
`table_alias`. The clinic FC keeps each
table's parsers in its own file — `config/parsers/encounters.json`, `patients.json`,
`labs.json`.

This file covers the **four common parser types** that build almost any FC. The extended set is
enumerated in `catalog-parser-types.md`; reach for it only when these four do not fit.

Every parser has, at minimum, `parser_type`, `column`, and `collection`. Optional attributes
(`variable`, `map`, `pattern`, `transform`, `collection_set`, `null_indicators`) depend on the
type.

## categorical

Maps a column's values into a categorical collection; the **distinct values become the
variables** (so there is **no `variable` attribute** — the platform derives them).

```json
{ "parser_type": "categorical", "column": "department", "collection": "Department" }
```

`Department` yields `Cardiology`, `Endocrinology`, `Primary Care` as filter/group dimensions.

## numeric

Maps a numeric column to a **named variable** inside a collection. Give related measurements the
**same collection** and different `variable`s to group them (`data-model.md`):

```json
{ "parser_type": "numeric", "column": "systolic_bp",  "collection": "Blood Pressure", "variable": "Systolic" },
{ "parser_type": "numeric", "column": "diastolic_bp", "collection": "Blood Pressure", "variable": "Diastolic" }
```

One `Blood Pressure` collection, two axes (`Systolic`, `Diastolic`). A standalone numeric just
uses its own collection and variable (`age` → `Patient Age` / `Patient Age`).

## datetime

Parses a date column. `pattern` states the **input format** (Java-style, e.g. `yyyy-MM-dd`);
`transform` states what to produce:

- `transform: "timestamp"` — a sortable/filterable date value; give it a `variable`.
- `transform: "year-month-day"` — a human-readable **calendar-date string** (no `variable`).

```json
{ "parser_type": "datetime", "column": "encounter_date", "pattern": "yyyy-MM-dd",
  "transform": "timestamp", "collection": "Encounter Date", "variable": "Encounter Date" }
```

It is common to parse the **same date column twice** — once as `timestamp` (for filtering) and
once as `year-month-day` into a separate `… Calendar Date` collection (for display). They are
distinct collections, so the names must differ.

## categorical-map

Like `categorical`, but first **remaps raw values to readable labels** via `map`. Use it when
the source stores codes or abbreviations. No `variable` (it is categorical).

```json
{ "parser_type": "categorical-map", "column": "sex",
  "map": { "F": "Female", "M": "Male" }, "collection": "Sex" }
```

Values not present in `map` pass through unchanged unless you map them explicitly.

## Attribute reference

| Attribute | Used by | Meaning |
|---|---|---|
| `parser_type` | all | which parser |
| `column` | all | source column to read |
| `collection` | all | the collection to populate (human-readable English) |
| `variable` | numeric, datetime-`timestamp` | the named axis; **omit for categorical / categorical-map** (values become the variables) |
| `map` | categorical-map | `{ raw: label }` remapping |
| `pattern` / `transform` | datetime | input format / what to emit (`timestamp`, `year-month-day`) |
| `collection_set` | any | a tag grouping this collection with others (`data-model.md`) |

Naming obeys the uniqueness rules in `data-model.md` (collection names unique per type;
variable names unique within a collection).

## Beyond one column, one collection

Two capabilities, so you never assume a false limit:

- **Multiple input columns.** Many parser types accept a `columns` array in place of a single
  `column`, operating on several source columns at once (combining or matching across them).
- **Multiple output collections.** Where a `collection` value is expected you may nest **another
  parser object** (the flexible value resolution of `files-and-value-resolution.md`), so a
  single parser produces a *tree* of collections — even a plain `categorical` parser can.

The four common types cover the vast majority of columns; keep these two options in mind for the
cases that need them.

## Transposed tables use `-row` parsers

When a table is **transposed** — entities are columns, not rows (VCF and much biomedical data;
see `configuration-and-sources.md`) — its parsers are the **`-row`** variants, most commonly
**`categorical-row`** and **`numeric-row`**. Each reads a *row* (a feature) and maps its
across-column values onto the column-entities, with a `start` index marking where the
entity-columns begin (the leading columns are the file's fixed feature columns). Collections,
variables, and naming otherwise work the same.

## The extended set

The four above cover most columns. For splitting delimited cells, binning numerics, deriving
values from multiple columns, constant flags, and operator-based matching, see
`catalog-parser-types.md`.

## Recipe: add a parser for a column

1. Decide the **collection type**: label → `categorical` (or `categorical-map` if the raw
   values need cleanup); measurement → `numeric`; date → `datetime`.
2. Choose a **human-readable collection name**; for `numeric`/`datetime-timestamp`, choose the
   `variable` name too (group related measurements under one collection).
3. Add the parser object to that table's parser file.
4. Rebuild and confirm the collection appears with the expected values.

## Common mistakes

- **Putting a `variable` on a categorical parser.** Categorical collections derive variables
  from their values; a `variable` attribute is rejected.
- **Naming a collection after the database column** (`sys_bp` instead of `Blood Pressure`).
- **Wrong collection type** — a code stored as digits that you will *group by*, not average, is
  `categorical`, not `numeric`.
- **Colliding names** — two collections of the same type cannot share a name
  (`data-model.md`).

Next: `data-functions.md` — how protocols reference these collections and variables.
