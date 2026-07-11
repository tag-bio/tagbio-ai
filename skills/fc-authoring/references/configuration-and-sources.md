# Configuration and sources — the config file

The **config** is the build-plane blueprint. It names the source tables, declares the entity
grain (`entities.md`), and maps source columns to collections and variables (`data-model.md`)
via **parsers**. This file covers the config's shape, how to load from **CSV/TSV** vs **SQL**,
and how adjunct tables **join** to entities. Parser-level detail (the parser types themselves)
is in `parsers.md`; here we care about structure. Every object shown inline below could equally
be a **file reference**, and JSON/YAML are interchangeable — see `files-and-value-resolution.md`.

## The config at a glance

A minimal single-file config for the clinic FC (JSON with comments is allowed; YAML works too):

```jsonc
{
  "data_dictionary": "data_dictionary.tsv",

  // The entity_table defines the grain. Its rows become entities.
  "entity_table": {
    "table": "data/encounters.csv",
    "unique_keys": ["patient_id", "encounter_date"],

    // Entity-table columns usable as join keys BEYOND the unique_keys — declared INSIDE the
    // entity_table object (not at the config top level).
    "foreign_keys": ["encounter_id"],

    // Parsers live INSIDE the table they read (see "Where parsers live" below).
    "parsers": [
      { "parser_type": "categorical", "column": "department", "collection": "Department" },
      { "parser_type": "numeric", "column": "systolic_bp",
        "collection": "Blood Pressure", "variable": "Systolic" }
      // … one parser per column you want to model
    ]
  },

  // Adjunct sources joined onto the entities (they do not create entities).
  // Each other_table REQUIRES a table_alias.
  "other_tables": [
    {
      "table": "data/patients.csv",
      "table_alias": "patients",
      "id_columns": { "patient_id": "patient_id" },       // broadcast (subset of the key)
      "parsers": [
        { "parser_type": "categorical", "column": "region", "collection": "Patient Region" }
      ]
    },
    {
      "table": "data/labs.csv",
      "table_alias": "labs",
      "id_columns": { "encounter_id": "encounter_id" },    // roll-up (via the foreign_key)
      "parsers": [
        { "parser_type": "numeric", "column": "result_value",
          "collection": { "parser_type": "categorical", "column": "panel" },     // name from data
          "variable":   { "parser_type": "categorical", "column": "analyte" } }   // see parsers.md
      ]
    }
  ],

  "null_indicators": ["NA", ""]   // "" makes any blank cell null — deliberate; drop it if blank is meaningful
}
```

Everything else in the skill is a variation on this skeleton.

(`data_dictionary` here — at the **config top level** — is an **output**, not an input: the build
writes a TSV listing every collection and variable it produced. It's a generated artifact — gitignore
it. **Watch the scope collision:** a `data_dictionary` on an individual **table** means something
different — an *input* `From,To` header-rename file (`catalog-table-types.md`). Same key name,
opposite roles; the level it sits at tells you which.)

## entity_table: the grain-defining source

- `table` — the source the entities come from (a **CSV/TSV file path** here; a **SQL table or
  query** for a database source — see below).
- `unique_keys` — the column(s) whose combination is one entity (`entities.md`). Verify
  uniqueness in the source.
- `foreign_keys` — optional; entity-table columns *beyond* `unique_keys` that adjunct tables may
  join on. **Declared inside the entity_table object** (not at the config top level).
- `parsers` — the column→collection mappings for this table (next section).

## Where parsers live

**Parsers sit inside the table object they read.** A parser reads a column of *its* table, so
nesting makes ownership obvious and the config directly traversable — and the parser needs no
`table_alias`, because its table is simply the one it is nested in.

Note the distinction: a **table object itself carries a `table_alias`** (`other_tables` require
one), but the **parsers nested inside it do not** — they inherit their table's identity. It is
the parser-level `table_alias` that the nested form removes, not the table-level one.

## other_tables: adjunct sources and how they join

An `other_table` attaches values to entities that **already exist**; it never creates
entities. Two fields do the work:

- `id_columns` — a `{ this_table_column: entity_key_column }` map. It says "match a row of
  this table to an entity by lining up these columns."
- `parsers` — the column→collection mappings, nested here just like the entity table.

How the map behaves depends on *which* entity keys it lines up with:

- **Broadcast (coarser table).** `patients` maps `{ "patient_id": "patient_id" }` — only part
  of the entity's `[patient_id, encounter_date]` key. One patient row therefore matches **all**
  of that patient's encounters, and its values (Region, Sex) repeat across them.
- **Roll-up (finer table).** `labs` maps `{ "encounter_id": "encounter_id" }`. But
  `encounter_id` is **not** one of the entity's unique_keys, so it must be declared in the
  top-level `foreign_keys` array to be joinable. Each lab row belongs to one encounter; the
  many lab rows per encounter become a multi-valued collection or an aggregate.

This is why `foreign_keys` exists: it exposes entity-table columns **other than the
unique_keys** as legal join targets for adjunct tables. Choose the join key deliberately —
joining labs on `patient_id` instead of `encounter_id` would wrongly smear one visit's labs
across all the patient's visits.

## Joins — pulling extra columns into a table

Any table object can **inner-join** another table and pull in some of its columns via a `joins`
attribute, exposing them as **implicit columns** to that table's own parsers. Use it for lookups
— mapping a code to a label, attaching a reference value — when you want the joined columns
available to parse but do not want a separate entity mapping.

The toy's entity_table does this (`config/config.json`): each encounter's `department` is looked up
in `departments.csv` to pull a `floor`, which becomes the `Clinic Floor` collection.

```jsonc
{
  "table": "data/encounters.csv",
  "joins": [
    {
      "table": "data/departments.csv",
      "table_alias": "dept_lookup",
      "id_columns": { "dept": "department" },   // join_table_column : host_table_column (differently NAMED)
      "columns": ["floor"]                       // which join columns to pull in
    }
  ],
  "parsers": [
    // reference a joined column as "<join table_alias>.<column>" — NOT the bare name:
    { "parser_type": "categorical", "column": "dept_lookup.floor", "collection": "Clinic Floor" }
  ]
}
```

- **Inner join** on `id_columns` (`{ join_column: host_column }`) — host rows without a match are
  dropped. The two columns can be **differently named** (here `dept` ↔ `department`).
- **`columns`** lists exactly which join-table columns to expose (keep it minimal).
- **Reference a pulled column as `"<join table_alias>.<column>"`** in the host's parsers
  (`"dept_lookup.floor"`), not the bare column name.

> **Constraint (stated plainly):** the **join table must be unique on its `id_columns` key** — **at
> most one join row per host row**. One join row may serve **many** host rows (that's a normal
> lookup/dimension — fine); but if **several join rows match one host row**, only one is taken and
> *which* is undefined. When you genuinely need **many values per host row**, use an `other_table`
> (which maps a source onto entities), not a join.

Distinct from `other_tables`: a **join adds columns to a table**; an **other_table maps a whole
source onto entities**. Reach for a join for a lookup/dimension, an other_table for an adjunct
dataset.

## Transposed tables

Some sources are **transposed**: the **rows are features and the columns are entities**. This is
common in biomedical data — a VCF file has one row per genetic variant and **one column per
sample**, so the entity identifiers (sample IDs) live in the **column headers**, not in a column
of values.

To load a transposed file, a table object uses a **`transpose`** attribute *instead of*
`id_columns`. Its value is the **single foreign key** the entity-columns map to (only one is
allowed):

```jsonc
{
  "table": "data/genotypes.tsv",
  "delimiter": "\t",
  "transpose": "patient_id",      // column headers are patient_ids → map to entities
  "parsers": "config/parsers/genotypes.json"
}
```

- **No `id_columns`** — `transpose` replaces them, naming the entity key the columns map on
  (here `patient_id`, part of the entity's key, so genotypes broadcast to that patient's
  encounters).
- The usual file options apply: `delimiter`, `skip_lines`, `comment_character`, and
  `max_columns` (transposed biomedical files can have very many entity-columns).

Because the orientation is flipped, the parsers are the **`-row` variants** — each reads a *row*
(a feature) and maps its across-column values onto the column-entities. See `parsers.md`.

> Mental model: a normal table is *entities as rows, parsers read columns*; a transposed table
> is *entities as columns, `-row` parsers read rows*.

The clinic example includes one — `data/genotypes.tsv` (rows = genetic markers, columns =
patient IDs), loaded with `transpose: "patient_id"` and a `categorical-row` parser whose
`collection` is itself a nested parser reading the `gene` column, so each marker row becomes its
own collection (`APOE`, `BRCA1`, `TCF7L2`), broadcast to each patient's encounters.

## CSV/TSV vs SQL sources

The data model is **identical** regardless of where the data comes from; only how a table
names its source differs:

- **CSV / TSV:** `table` is a **file path** (relative to the data directory). The delimiter is
  inferred from the extension, or set it explicitly with a **`delimiter`** attribute on the table
  — `"\t"` for **TSV** (very common) or `"|"` for **pipe-delimited** files (occasionally seen).
  `null_indicators` (e.g. `"NA"`, `""`) mark missing values. **Note the empty string `""`:** it
  makes **every blank cell** count as missing — the right default for most sources, but a
  **deliberate** choice. If a blank is *meaningful* in your data (e.g. empty = "not yet assigned",
  distinct from a true unknown), **drop `""`** from `null_indicators` so blanks aren't silently
  discarded.
- **SQL:** each `table` names a **database table** (or a query result) reached over a **SQL
  connection**, instead of a file path. The entity_table and other_tables, unique_keys,
  foreign_keys, id_columns, transpose, and parsers all work **exactly the same** on top of it.

Start with CSV/TSV — it is how most first FCs are built. Moving to SQL later changes only the
source declaration, not the model.

### A concrete SQL variant (shipped and runnable)

The example FC ships a **complete SQL mirror** of the CSV toy — same entities, same collections —
so you can see every moving part:

1. **A database.** `_shell_scripts/make_sqlite.sh` loads the same `data/*.csv` / `.tsv` into a
   SQLite DB (`data/clinic.db`) with tables `patients`, `encounters`, `labs`, `genotypes`.
2. **A connection** — `config/connection_sql.json`, a flat object naming the driver + database:

   ```json
   { "jdbc": "jdbc:sqlite:", "url": "data/clinic.db", "fetch_size": 10000 }
   ```

3. **A config** — `config/config_sql.json`, identical to `config.json` except each `table` now
   names a **database table** rather than a file (`"table": "encounters"` instead of
   `"table": "data/encounters.csv"`), and there is no `delimiter`. The `unique_keys`,
   `foreign_keys`, `id_columns`, `transpose`, and the **same parser files** are reused unchanged.
4. **A manifest** — `manifest_sql.json`, which points `data_model.config` at `config_sql.json` and
   adds **`sql_connection: "config/connection_sql.json"`**. Everything served (main, protocols,
   tests, transformers) is unchanged.
5. **Build it with the SQL jar:** `_shell_scripts/build_archive_sql.sh` runs `make_sqlite.sh` then
   `fc_sql_server.jar build_archive manifest=manifest_sql.json`. The result is byte-for-byte the
   same data model as the CSV build — 8 encounters, the transposed genotypes, the transformer's
   `Hypertension Stage` — proving the model is source-agnostic.

> For a **server database** (Postgres, MySQL, …) only `connection_sql.json` changes — the `jdbc`
> prefix and a `url` carrying the host, with credentials kept **outside the repo**. A table can
> also draw from a `.sql` **query** file (`"query": "config/sql_queries/foo.sql"`) and a
> **named** connection when you need to shape or join in the database first (see
> `catalog-table-types.md`).

**Server jars.** The engine ships as one jar per source/deployment backend; pick the one that
matches:

| jar | use for |
|---|---|
| `fc_csv_server` | local CSV/TSV files |
| `fc_sql_server` | SQL databases — **and** CSV/TSV, so it is the superset for mixed sources |
| `fc_s3_server` / `fc_gcp_server` / `fc_azure_server` | serving an archive stored in S3 / GCS / Azure Blob |

The clinic example uses `fc_csv_server`. (The jars are distributed under authorization; obtaining
them is outside this skill.)

`fc_csv_server` needs no extra configuration — it reads local files. **`fc_sql_server`
additionally needs a SQL connection** (remote address + credentials), and the **cloud jars need
their storage coordinates** (bucket + auth); these are supplied via the manifest (or on the CLI),
not in the config itself.

## Scaling up: one file per table

The single-file config above is ideal while there are a few tables. As an FC grows to many
tables, split each table into its **own file** and have the config list the paths:

```jsonc
{
  "entity_tables": ["config/tables/encounters.json"],
  "other_tables":  ["config/tables/patients.json", "config/tables/labs.json"]
}
```

Each `config/tables/*.json` file is exactly one table object — `table`, keys, and its nested
`parsers` — the same content, just externalized for readability. Nothing about the model
changes.

## Recipe: wire a new source table into an FC

1. Decide the table's **role**: does it define the grain (entity_table) or enrich existing
   entities (other_table)?
2. Point `table` at the source (CSV/TSV file path, or SQL query + connection).
3. For an other_table, write `id_columns` mapping its column(s) to the entity key(s). If the
   join column is not a `unique_key`, add it to the entity_table's `foreign_keys`.
4. Decide broadcast vs roll-up from *which* keys you mapped (subset → broadcast; full/finer →
   roll-up).
5. Add the `parsers` (see `parsers.md`) inside the table object.

## Common mistakes

- **Joining on the wrong key.** A coarser key broadcasts (and can multi-count); pick the key
  that matches the adjunct table's true grain.
- **Forgetting `foreign_keys`.** An other_table can only join on a `unique_key` or a declared
  `foreign_key`; a join column that is neither will not resolve.
- **Hoisting parsers to the config root.** Author them nested in their table.
- **Assuming SQL and CSV need different models.** Only the source declaration differs.

Next: `parsers.md` — the parser types that turn source columns into the collections and
variables these tables expose.
