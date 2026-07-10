# Catalog — table types and attributes

`configuration-and-sources.md` teaches the table objects you use constantly (entity_table,
other_table, transposed, joins) and CSV-vs-SQL. This catalog is the **reference enumeration** of
table *roles* and the *attributes* a table object can carry. As elsewhere, **confirm exact names
against a working FC** — some attributes are rare and their options vary.

## Table roles

| Role | Declared as | Creates entities? | Keyed by |
|---|---|---|---|
| **Entity table** | `entity_table` (or `entity_tables: [...]` for many) | **Yes** — its rows are the entities | `unique_keys` |
| **Other table** | an item in `other_tables` | No — attaches values to existing entities | `id_columns` (or `transpose`) |
| **Join (dimension)** | a `joins` entry inside another table | No — pulls columns into the host table | `id_columns` (lookup) |

- **`entity_tables` (plural)** lets more than one source contribute entities **to the same grain**
  — the rows are unioned into one entity set, so every listed table must share the **same**
  `unique_keys`. Use it when the entities of one grain arrive split across sources. It is **not** a
  way to combine different grains: **an FC has exactly one grain**, and a different grain is a
  **separate FC** (`entities.md`).

## Source attributes (where the rows come from)

| attribute | For | Meaning |
|---|---|---|
| `table` | CSV/TSV | file path to the source (relative to `data_dir`) |
| `table` + `connection` | SQL | `table` points at a `query` (often a `.sql` file); `connection` supplies host + credentials |
| `query` | SQL | the SQL text/file the table draws from |
| `connection` | SQL | the named database connection (address, auth) |
| `delimiter` | CSV/TSV | field delimiter — `"\t"` for TSV, `"|"` for pipe (else inferred from extension) |
| `skip_lines` | flat files | number of leading lines to skip before the header |
| `comment_character` | flat files | lines starting with this are ignored |
| `max_columns` | wide/transposed | raise the column cap for very wide files (common with transposed biomedical data) |
| `null_indicators` | any | tokens (e.g. `"NA"`, `""`) that mark a missing value |

## Mapping / shaping attributes

| attribute | Meaning |
|---|---|
| `table_alias` | the table's name; **required on every `other_table` and `join`** (not on nested parsers) |
| `unique_keys` | the column(s) whose combination is one entity (entity tables) |
| `foreign_keys` | entity-table columns beyond `unique_keys` that adjunct tables may join on — **declared inside the entity_table object** |
| `id_columns` | `{ this_table_column: entity_key_column }` — how an other_table/join lines up (subset of key → broadcast; finer key → roll-up) |
| `transpose` | for transposed sources: the single entity key the **column headers** map to (replaces `id_columns`) |
| `joins` | inner-join another table and pull specific `columns` in as implicit columns for this table's parsers (one-to-one or one-to-many only) |
| `include` | restrict which **columns** the table loads |
| `data_dictionary` | a `From,To` CSV that **renames source columns to canonical names before parsing**; **many→one is allowed** — map several files' differently-named columns onto one name so a *single* parser targets it (e.g. `visit_dt` / `enc_date` / `admit_date` all → `encounter_date`). The workhorse for unioning many same-grain files whose columns are named inconsistently |
| `where` | a **row predicate** — load only rows matching it (e.g. one type of record); lets you define **two tables over the same source** with different filters (`files-and-value-resolution.md`) |
| `parsers` | the column→collection mappings, nested in the table (`parsers.md`) |

A **`where`** predicate is written as a **match object** — the same shape as a `categorical-match`
parser: a `column`, an `operator`, and a `value`. Rows that don't match are dropped:

```jsonc
"where": { "parser_type": "categorical-match", "column": "is_latest_record",
           "operator": "=", "value": "true" }
```

(A `where` can sit on a **table** to filter its rows, or on an individual **parser** to filter just
that parser's rows. Operators are the `categorical-match` set — `=`, `contains`, ranges, etc.,
`catalog-parser-types.md`.)

> `where` and a second table definition over the same file are the idiomatic way to split one
> source into differently-filtered tables — cleaner than one over-complicated parser set.

## Rule of thumb

Most FCs need only `entity_table` + a few `other_tables`, CSV `table` paths, `delimiter` for TSV,
and `id_columns`. Reach for `entity_tables`, `joins`, `where`, or the SQL `query`/`connection`
pair when the data actually requires it — and copy the shape from a working FC.
