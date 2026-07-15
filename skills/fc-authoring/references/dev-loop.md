# The developer loop — edit, compile, build, serve, test

FC config is **schema-less and typo-tolerant**: a misspelled attribute is usually ignored, not
rejected, so a mistake shows up as a *missing collection* or a *failed protocol* much later. The
antidote is a **tight edit→check loop** with the fastest check that can catch each class of error.
Learn this early and run it constantly; it is the single biggest force-multiplier when authoring
in this format.

## Prerequisites for the loop (local dev)

The commands below and the example `_shell_scripts/*.sh` reference a few things you must have set up
locally. **In a deployed cluster the container provides all of this** (out of scope here); this is
just for running the loop on your own machine:

- **Java 21** on `PATH`.
- **`TAGBIO_JARS`** — a directory holding the FC engine jars (`fc_csv_server.jar` for CSV/TSV,
  `fc_sql_server.jar` for SQL). The scripts invoke `${TAGBIO_JARS}/fc_csv_server.jar`.
- **`TAGBIO_R_UTILS`** and **`TAGBIO_PY`** — the local checkouts of the R (`tagbio`) and Python
  (`tagbiopy`) SDKs, passed as `r_sdk=` / `python_sdk=` to `run_server` so plugins can run.
- For **Python plugins**, the SDK console scripts (`connect_tagbio_py`) must be on `PATH`.

The jars and SDKs are distributed under authorization (`configuration-and-sources.md`); point these
variables at wherever you installed them. `compile` and `build_archive` need only the jar;
`run_server` with plugin tests also needs the SDK vars and `PATH`.

## Bootstrapping a new FC from scratch

The minimal skeleton — the smallest thing that builds and serves:

```
my-fc/
  data/              # source CSV/TSV (or a SQL connection)
  config/
    config.json      # entity_table (the grain) + other_tables + parsers
    parsers/*.json
  protocols/         # one protocol + its data_functions (add as you go)
  main.json          # identity + registered protocols[] + tests[]
  manifest.json      # data_model (config, data_dir) + serve (main) + archive path
```

1. **Author the config directly — this skill is how.** Choose the **entity grain** (`entities.md`)
   first, then model outward: point tables at your sources, give collections human-readable English
   names, write real parsers (and joins), and skip columns you don't need. Copy the shapes from
   `example-clinic-fc/` — it *is* the reference skeleton — and start tiny, growing it under the loop.
2. Write a **`main.json`** (identity + an empty `protocols`/`tests` to start) and a **`manifest.json`**
   pointing `data_model.config` at your config and `serve.main` at main (`manifest.md`).
3. Run the loop: **`compile` → `build_archive`** until the data model is right, then add a protocol
   and a test and `run_server`.

Everything after this is filling in that skeleton; the reading order (`SKILL.md`) walks it in the
right sequence, entity grain first.

## The loop is how you *know* you're right

More than a build procedure, the loop is your **source of truth**. This matters especially for an AI
assistant, whose priors may not match the current engine:

- **The running engine is the oracle.** When your memory, an old FC, and a fresh `compile` disagree,
  **the compile wins.** Don't reason about whether an attribute exists or a reference resolves —
  *run it and read the output.* The engine names the exact offending JSON.
- **Verifying is cheaper than being wrong.** Running a check *feels* expensive, so there's a pull to
  reason instead. Resist it: a wrong guess costs far more to unwind than the seconds a `compile`
  takes. When unsure, run the loop.
- **Green ≠ correct.** A passing test only means the protocol **didn't crash** — not that it did what
  you intended (`testing.md`). Before you run, **state an observable expectation**, then check the
  output against it. *(Worked example: a "download all variants" toggle should* add *columns —
  verified by diffing the export headers, 0 genotype columns off vs 3 on. The green alone proved
  nothing.)*
- **Isolate one change.** When something breaks, change **one** thing and re-run, so the next result
  is attributable. Read the exact exception, not the general vicinity.
- **Let the engine confirm the current form.** Run `compile … verbosity=3d` periodically — the `d`
  flag reveals deprecation warns the default hides, so if any attribute has a newer replacement the
  engine **names it for you**. Treat any such warn as a to-fix.

## The loop, fastest check first

```
edit ──▶ compile ──▶ build_archive ──▶ run_server ──▶ test
        (seconds,     (loads data,      (serves the      (exercise
         no data)      writes archive)   protocols)       the apps)
```

Each stage catches a different class of error. Run the cheapest one that covers your change, and
only move outward when it passes.

### 1. `compile` — validate config + protocols WITHOUT loading data (seconds)

```bash
java -Xmx4g -jar ${TAGBIO_JARS}/fc_csv_server.jar compile manifest=manifest.json
```

Parses the config, registers and compiles every protocol, and checks test coverage — then exits.
It does **not** read the source data, so it is fast and safe to run after every edit. It catches:

- JSON/YAML that won't parse, and unresolved file references;
- a `data_function` naming a **collection/variable that doesn't exist** (the compiler resolves
  every reference — `data-functions.md`);
- a protocol referencing a missing argument/plugin;
- a protocol with **no test** (coverage gap).

The example ships this as `_shell_scripts/compile_local.sh`. **Run it after any config, parser,
data_function, or protocol edit.**

### 2. `build_archive` — load the data and write the archive

```bash
java -Xmx4g -jar ${TAGBIO_JARS}/fc_csv_server.jar build_archive manifest=manifest.json verbosity=4
```

Reads the sources, applies the parsers, runs transformers, and writes the immutable archive. This
is where **data-dependent** problems surface: a parser that produced nothing, a join key that
didn't match, a transformer error, a duplicate unique key. Read `build.log` and the per-table
report lines; confirm the collections you expect appear in the generated `data_dictionary.tsv`
(`configuration-and-sources.md`). Higher `verbosity` (0–5) means more detail.

### 3. `run_server` — serve the protocols locally

```bash
java -Xmx4g -jar ${TAGBIO_JARS}/fc_csv_server.jar run_server manifest=manifest.json \
    r_sdk=${TAGBIO_R_UTILS} python_sdk=${TAGBIO_PY}
```

Loads the archive and serves the API + UI on `localhost:8000` (default). Use it to actually click
through the cohort builder and the plugin apps, and to point an ad-hoc R/Python query at
`http://localhost:8000` (`r.md`, `python.md`). Plugin protocols need the R/Python SDKs on the
paths shown. **`run_server` is unauthenticated — never bind it beyond localhost with real data**
(`governance.md`).

Startup runs in order: **load the archive → run the auto-tests (below) → begin serving `/q`
queries.** The query API is live only once that third step is reached — the UI and an ad-hoc SDK
query both connect only after the auto-tests complete. On a large FC (many arguments and
`data_function`s produce many autogenerated tests) that window can run to minutes, so a query fired
the instant the process starts simply won't connect yet — wait for serving to begin.

### 4. `test` — auto-run the protocol tests

The engine **auto-tests every protocol that takes no arguments** (including the many autogenerated
`argument_protocol`s), and runs any **explicit** `tests/*.json` you wrote for protocols with a
mandatory argument. A test today just checks the protocol **runs without crashing** — a failure
**takes the whole server process down** (a delayed kill, not a soft failure — see `testing.md` for
the full behavior and why that's the intended production safeguard); a pass writes its `output`
(gitignored) to eyeball. Force a run with
`run_tests=true` (implied when `main.json` sets `tests`); add `die=true` to run everything then
exit (handy in CI). Full detail and the test JSON schema are in `testing.md`.

## Handy flags

| flag | does |
|---|---|
| `verbosity=0..5` | log detail (append `d` to see deprecation notices) |
| `die=true` | run all processes, then stop the server (one-shot builds/tests) |
| `run_tests=true` | run the registered tests (or set `run_tests: "true"` in the manifest `serve` block) |
| `log=build.log` | send output to a file instead of the console |

## Housekeeping: detecting cruft

As an FC grows, parsers, data_functions, and protocols get orphaned — referenced by nothing. Run the
engine with **`cruft=true`** to get a **report** of unused collateral without changing anything:

```bash
java -Xmx4g -jar ${TAGBIO_JARS}/fc_csv_server.jar manifest=manifest.json cruft=true
```

The example ships this as `_shell_scripts/cruft_detector.sh`. `cruft=purge` will **delete** what it
finds — useful for cleanup, but review the `cruft=true` report first and commit beforehand, since it
removes files. Good to run before a release so the repo carries only what it uses.

## Recipe: after any change

1. `compile` — did every reference still resolve and every protocol keep a test?
2. If the change touched **data** (parser, source, transformer): `build_archive` and check the
   collection appears in `data_dictionary.tsv`.
3. If it touched a **protocol/plugin**: `run_server` and exercise it, or `run_tests=true`.
4. When stuck, read `build.log` and see `troubleshooting.md`.

Keep this loop open the whole time you author — everything else in the skill assumes you are
validating as you go.
