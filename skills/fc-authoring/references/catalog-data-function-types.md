# Catalog — data_function types

`data-functions.md` teaches the common data_functions (numeric, categorical, collection-set,
bundle, categorical-all) and explains the argument family in prose. This catalog **enumerates**
the full set for reference. As with the parser catalog, reach here when a common type doesn't fit,
and **confirm the exact attribute names against a working FC** — the rarer types vary.

Recall the role: a data_function is a **named reference the compiler must resolve** against the
data model or the argument layer (`data-functions.md`). They live under
`protocols/data_functions/`, one per file, referenced by path.

## Data-model references (resolve to collections/variables)

| data_function_type | Resolves to | Key attributes |
|---|---|---|
| `numeric` | a numeric collection + one variable | `collection`, `variable` |
| `categorical` | a categorical collection (all its levels) | `collection` |
| `boolean` | a two-state categorical treated as true/false | `collection` (+ which level is true) |
| `collection-set` | a whole tagged family of collections at once | `collection_set`, optional `data_type` |
| `categorical-all` | **all entities** (no filter) — a universal background/cohort | none |
| `categorical-enum` | an explicit enumerated set of levels from a collection | `collection`, the levels |
| `constant` | a fixed literal value (number/string) passed to a protocol | the value |
| `flux-name` | a literal collection/variable **name** (not its data) | the name |

## The argument bridge (resolve at run time, `protocols.md` / `cohort-builder.md`)

| data_function_type | Meaning |
|---|---|
| `argument-reference` | the data function produced by the argument's **handler function** — a server-side transform of the user's selection into a data function (a filter pick → the matching entity set). Requires the argument to have a `handler`. |
| `argument-set-reference` | the same, for a whole named **argument_set** (all its arguments' handlers combined) — a reusable constraint wrapper |
| `argument-value` | the argument's **raw value** as it arrives from the API, substituted *in place of* a data function — **not** run through a handler |

> **`argument-reference` vs `argument-value` — the common trip.** Use **`argument-reference`** when
> the argument has a **handler** that turns the selection into a data function (the normal case for
> filters in a cohort builder). Use **`argument-value`** when you want the value *itself*: either a
> plain **string** the attribute accepts, or — the key case — a **`background`/cohort**, whose value
> *is already a data function* (the FC sends the cohort definition to the client and the client
> sends it back), so it is passed through by value, not via a handler. A cohort `background` therefore
> uses **`argument-value`**; the compiler warns if you point an `argument-reference` at an argument
> that has no handler.

## Set algebra (compose cohorts/collections from others)

| data_function_type | Produces |
|---|---|
| `set-intersection` | entities in **all** of the referenced sets (AND) |
| `set-union` | entities in **any** referenced set (OR) |
| `set-operation` | a general set op (difference, etc.) — **rarely needed**; `set-intersection` and `set-union` already cover the two common cases |
| `set-combinations` | combinatorial subsets across referenced sets |
| `categorical-opposite` | the **complement** of a categorical set (NOT) — see the nuance below |
| `filter` | a set filtered by a predicate/another reference |
| `bundle` | groups several data_functions into one reference consumed together |
| `categorical-batch` / `categorical-array` | apply/collect over **many** categorical references at once |

**`set-intersection` (AND) and `set-union` (OR) are the two workhorses.** Each takes a `criteria` of
data_functions and combines the **entity sets** they resolve to. The toy ships a real, tested one —
the cohort builder's background ANDs its filter sections:

```jsonc
// protocol_cohort.json — the shipped, tested example (Department=Cardiology → 3 of 8 entities)
{ "data_function_type": "set-intersection",
  "criteria": "protocols/argument_reference_sets/argument_reference_set_cohort.json" }
```

`set-union` is identical with OR semantics — swap the type and the same criteria yields "in **any**
section" instead of "in **all**." Crucially, the sets being combined almost always come from
**argument selections** (a filter's handler resolves the user's pick to an entity set), *not* from
static whole-collection references: a bare `{ "data_function_type": "categorical", "collection":
"APOE" }` is *every* entity that has an APOE value (i.e. everyone), so unioning two of those is a
no-op. Reach for `set-operation` only for the odd difference/other op the two workhorses don't cover.

> **`categorical-opposite` has a null trap.** A categorical collection's entities can be `Positive`,
> `Negative`, **or neither** — an entity with *no* value in that collection is in **none** of its
> tag-sets (`data-model.md`, missing-value semantics). So the opposite of `Positive` is **"every
> entity not tagged Positive"** = `Negative` **plus the un-valued (null) entities** — *not* "all the
> `Negative` ones." If you want only the other explicit level, reference **that level directly**
> (`{ "data_function_type": "categorical", "collection": "…", ... }` naming `Negative`), not the
> complement. Use `categorical-opposite` only when you genuinely mean "everything outside this set,
> nulls included."

## Related enumerations

**`argument_type`** (the interactive controls a protocol exposes): `cohort`, `categorical`,
`categorical-checkbox`, `categorical-checkbox-filter`, `categorical-radio` /
`categorical-radio-filter`, `categorical-paste`, `categorical-input`, `numeric-range`,
`static-numeric`, `timestamp-range`, `boolean` / `boolean-null`, `static-categorical` /
`static-radio`. **`arguments.md` documents each — the control it produces and when to use it** —
along with argument_sets, `argument_expanders`, and handlers.

**`output_type`** (what a protocol/plugin returns): `html` (a widget/report — the common one),
`csv`, `parquet`, `png`; and the notebook cell types a Jupyter plugin emits — `execute_result`,
`stream`, `display_data` (`python.md`).

## Rule of thumb

Prefer `numeric` / `categorical` / `collection-set` and the argument bridge for almost everything.
Reach for the set-algebra types only when composing cohorts from other cohorts — and verify the
exact shape against a real protocol before copying.
