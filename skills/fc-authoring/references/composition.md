# Composition — the pattern that runs through everything

If you learn one structural idea about FCs, learn this: **the platform is built from small pieces
that nest inside each other.** Almost anywhere a component takes a value, that value can be *another
component of the same kind* (or a reference to one). You do not memorize a big catalog of special
cases — you learn a handful of primitives and the rule that they **compose**.

It is the same idea as a grammar of graphics (ggplot layers) or a data pipeline (dplyr `%>%`): a
few verbs, combined without limit. Master the verbs and the nesting rule, not the combinations.

## Where composition shows up

**Parsers nest (build plane).** A parser reads a column into a collection — but the `collection`
and `variable` slots can each hold *another parser* that derives the name from the data, and
`columns` can hold nested parsers too. The toy's labs are the worked example: a numeric parser whose
`collection` is a `categorical` parser on `panel` and whose `variable` is a `categorical` parser on
`analyte`, so one parser fans out into `Lipid → LDL`, `Metabolic → HbA1c`, … (`parsers.md`, Dynamic
naming). A `categorical-compound` nested inside `collection` builds a `Panel | Analyte` name. Parser
inside parser.

**Data_functions nest and chain (serve plane).** A data_function names a slice of the data model —
and its slots take other data_functions. The toy's cohort builder ships one: `protocol_cohort.json`'s
background is a `set-intersection` whose `criteria` is a reference set that in turn references the
individual categorical filters (`data-functions.md`, `cohort-builder.md`). The general query-time form
is the **`filter`** data_function — it wraps a `criteria` data_function (the set to filter) plus a
`filters` predicate list (the test to apply). That is exactly **the data_function analog of a parser's
`where`**: a predicate composed onto a reference. Real protocols nest these several levels deep
(a slice of a matrix, of a filtered cohort, of a combination…); you build them the same way you read
them — from the inside out.

**Argument_sets compose too.** A cohort ANDs several `argument-set-reference`s together; a protocol
composes argument_sets; `argument_expanders` generate the leaf arguments (`arguments.md`). Same shape,
one level up.

## Why this matters for authoring

- **Reach for the primitive, then nest** rather than hunting for a bespoke type. Need a name from the
  data? Nest a parser in `collection`. Need a filtered cohort? Wrap a `criteria` in a `filter`.
- **Read inside-out.** A scary-looking nested data_function is just primitives wrapped in primitives;
  find the innermost reference and work outward.
- **The catalogs are a vocabulary, not a checklist.** `catalog-parser-types.md` and
  `catalog-data-function-types.md` list the verbs; composition is the grammar that combines them.

Next: `protocols.md` — where composed data_functions get exposed as apps.
