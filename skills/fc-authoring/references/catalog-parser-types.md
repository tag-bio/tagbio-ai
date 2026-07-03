# Catalog — extended parser types

The four common types in `parsers.md` (categorical, numeric, datetime, categorical-map) build
almost any FC. This catalog lists the **extended** types for the cases they do not cover. Reach
here only when a common type does not fit, and **confirm the exact attribute names against a
working FC** — these appear less often and their options vary.

| parser_type | Use it when… | Produces |
|---|---|---|
| `categorical-delimited` | one cell holds several values joined by a delimiter (`"A;B;C"`) | a **multi-valued** categorical collection, one value per split token |
| `categorical-match` | a label depends on **matching** the raw value (equals, contains, range) rather than an exact remap | a categorical collection assigned by rule/operator (a richer `categorical-map`) |
| `categorical-static` | every row should carry a **constant** label (e.g. an always-on "Has X" flag used as a stable denominator) | a categorical collection with one fixed value on every entity |
| `categorical-transform` | a categorical value must be **derived** from a column (or columns) via a transformation | a categorical collection computed from the source |
| `numeric-bins` | a numeric column should become **labeled ranges** (age → `0–17`, `18–64`, `65+`) | a categorical collection of bins |
| `numeric-transform` | a numeric value needs a **transformation/expression** applied before storing | a numeric collection/variable |
| `numeric-compound` | one value must be **combined from multiple numeric columns** (sum, ratio, score) | a numeric collection/variable |

Notes:

- **Multi-valued output** (`categorical-delimited`, and any parser on a finer roll-up table)
  interacts with grain — a multi-valued collection can multi-count if analyzed carelessly
  (`entities.md`, `data-model.md`).
- **`categorical-static`** is the pattern for a **denominator** flag: mark every tested entity
  with a constant "Has X" so prevalence is counted over the tested set, never derived from the
  result column (which selection would corrupt).
- These extended types still obey the same core attributes (`parser_type`, `column`,
  `collection`, and `variable` for numeric outputs) and the naming rules in `data-model.md`.

## Transposed-table (`-row`) parsers

For **transposed** tables (`configuration-and-sources.md` → Transposed tables), parsers read
**rows** instead of columns:

| parser_type | Use it when… |
|---|---|
| `categorical-row` | a transposed row yields a categorical value/tag per entity-column |
| `numeric-row` | a transposed row yields a numeric value per entity-column |

A `start` attribute marks the first entity-column (leading columns are the file's fixed feature
columns). These take the same value-mapping options as their column-based counterparts, and (as
elsewhere) a `collection` value may itself be a nested parser object to emit many collections —
e.g. one collection per variant row, named from an `ID` column.

## Rule of thumb

When in doubt, prefer a common type plus a small transformer (`transformers.md`) over an exotic
parser — it is usually clearer.
