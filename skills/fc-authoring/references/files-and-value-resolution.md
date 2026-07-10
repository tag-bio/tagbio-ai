# Files, formats, and value resolution

An FC is configured by a tree of files — the config and the protocols. Before the structural
details, three conventions apply **everywhere** in that tree, in config and protocols alike.
They are why the same idea can be written many different ways — and why a strict
schema/linter for FC files is deceptively hard to write.

## 1. JSON and YAML are interchangeable

Any file, and any value, may be written as **JSON or YAML** — the platform reads both,
anywhere. JSON may include comments. Use whichever is clearer for the file at hand; a single
repo commonly mixes them.

> **Tooling caveat:** JSON-with-comments in a `.json` file breaks many standard linters,
> formatters, and editor schemas. The platform accepts it; the wider ecosystem may not — name such
> files `.jsonc`, or expect some tools to complain.

## 2. Values are resolved flexibly, not by strict type

An attribute does not demand one rigid value shape. The platform **infers** how to resolve a
value from what it finds, so the *expected* type and the *written* type need not match. The
two inferences to know:

- **A string where an object or array is expected → a file path.** If an attribute expects an
  object (or array) but the value is a string, the string is read as a **path to a file
  containing that value**. This is exactly how modular, referenced files work:

  ```jsonc
  "parsers": "config/tables/encounter_parsers.json"   // resolves to the array inside that file
  "parsers": [ { … }, { … } ]                          // identical result, written inline
  ```

- **An object where an array is expected → a one-element array.** If an attribute expects an
  array but a single object is given, the platform wraps it into a one-item array
  automatically:

  ```jsonc
  "other_tables": { … }        // treated as…
  "other_tables": [ { … } ]    // …this
  ```

More generally, this flexible resolution is **systemic** across config and protocols: a value
may be written inline, given as a file reference, or given in a shape the platform coerces to
what the attribute expects.

> **Consequence:** do not expect FC files to validate against a strict JSON schema, and be
> careful writing linters — a value's written type is not authoritative (a string may be a
> path; an object may stand in for an array). Read a file by **following its references**, not
> by assuming fixed types.

## 3. Mandatory vs unknown attributes — the silent-typo trap

The parser is strict in one direction and lenient in the other:

- **A missing mandatory attribute fails the compile.** Objects that require an attribute (a
  parser without a `collection`, a table without a `table`) are caught at build time.
- **An unknown attribute is silently ignored.** An attribute the object does not recognize is
  simply not parsed, and raises no error — so a **typo in an attribute name** (`collcetion`,
  `unqiue_keys`, `varaible`) is quietly dropped, and the value you intended never takes effect.

The failure mode is subtle: the build *succeeds*, but a collection is missing, a parser does
nothing, or a setting appears ignored — because a misspelled attribute was skipped. When
something you configured "isn't taking," **check the spelling of the attribute name first.** The
full "my collection didn't appear" checklist and how to read `build.log` are in
`troubleshooting.md`.

## 4. Inline vs modular — both work; modular is best practice

Because any object can be written inline *or* pulled from a referenced file, an FC can be built
anywhere on a spectrum:

- **Monolithic:** the entire config in one file, every object and array inline. Fully
  supported — some developers (especially those coming from single-file R/Python scripts)
  prefer it so they never have to go hunting through many small files.
- **Modular:** objects segregated into small, single-purpose files referenced by path — a
  table per file, a parser set per file, a protocol per file.

**Best practice is modular.** Segregating by topic, purpose, and scope keeps each file small
and single-purpose, makes ownership and reuse obvious, and lets one referenced object serve
several places. The monolithic form is allowed for comfort, not recommended at scale.

The rest of this skill shows the **modular** form — but remember that any referenced file could
equally be written inline, and vice versa. To the platform they are the same.

Next: `configuration-and-sources.md` — the config file that declares the entity_table, the
source tables (CSV/TSV and SQL), and how adjunct tables join.
