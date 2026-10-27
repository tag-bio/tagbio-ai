# The manifest — one deployable instance

The **manifest** (`manifest.json`) ties a data product together: what to **build** (the data
model) and what to **serve** (the protocols), plus where the **archive** lives. A build
(`build_archive`), a serve (`run_server`), or a `compile` is pointed at a manifest.

> **The manifest is the current standard.** Every FC has a `manifest.json`, and it carries the
> product's identity (`data_product_definition`) and its build, serve and archive settings. An FC
> that is only a `main.json` (identity in `main.json`, deployed with `config:` + `main:`) is the
> **legacy** form. The engine still supports it for backward compatibility, so don't refactor an
> FC nobody is working on. But **when you work on an FC, bring it to the current standard**: add a
> manifest, move the identity into it, and switch `deployments.yml` to the manifest form below.
>
> **manifest.json and `deploy/deployments.yml`.** The manifest drives `compile` / `build_archive` /
> `run_server`, locally and in the cluster. **`deployments.yml`** is the **cluster** deployment
> descriptor (`governance.md`): one entry per served instance, adding the jar, JVM sizing, secrets
> and probes. It points at the manifest rather than repeating it:
>
> ```yaml
> fc-clinic:
>   fcCommand:
>     fcArgs:
>       command: run_server       # serve only; never try to build from the manifest's data_model
>       manifest: manifest.json   # identity, license, serve.main
>       archive: ./archive.ser    # overrides the manifest's build-time archive path
>       run_tests: "true"
> ```
>
> `archive` is overridden because the manifest's path is where the **build** writes, while the
> deployed container reads the archive its pipeline fetched (e.g. from the FC's bucket into
> `./archive.ser`).

## Shape

```jsonc
{
  // Identity. Lives here; main.json carries only protocols, tests and presentation.
  "data_product_definition": {
    "name": "fc-clinic",
    "title": "Clinic FC (example)",
    "entity_name_singular": "encounter",
    "entity_name_plural": "encounters",
    // The terms the data is used under, served by /s (see "Describing the product" below).
    "license": {
      "name": "CC0 1.0 (fictional example data)",
      "url": "https://creativecommons.org/publicdomain/zero/1.0/"
    }
  },

  // The BUILD side — inputs build_archive needs (gated OFF for run_server, which loads the archive).
  "data_model": {
    "config": "config/config.json",        // the data-model config (entities, parsers)
    "data_dir": "./",                       // base directory for CSV/TSV file paths
    "log": "build.log"                      // where the build writes its log
    // "transformers": "config/transformers.json",        // optional — see transformers.md
    // "sql_connection": "../connection/connection.json"  // for SQL sources (configuration-and-sources.md)
  },

  // The SERVE side — inputs run_server needs (gated OFF for build_archive).
  "serve": {
    "main": "main.json"                     // registered protocols + tests
    // "run_tests": "false"                 // defaults to true if omitted; set false to opt out
    // "hide_failed_arguments": "true"      // see below
  },

  // The immutable artifact that connects the two planes: build writes it, serve reads it.
  "archive": "archive.ser"
}
```

- **`data_model`** vs **`serve`** — the command gates which half is used: `build_archive` builds
  `data_model` and skips `serve`; `run_server` loads the `archive` and skips `data_model`;
  `compile` validates both without loading data.
- **`archive`** — the versioned, immutable output (`overview.md`).
- **`data_product_definition`** — the product's **identity**: `name` (the id used in URLs/API and to
  address it, e.g. `tbl(con, "fc-clinic")`) and `title` plus the **`entity_name_singular` /
  `entity_name_plural`** — the noun the **UI** uses when it labels and counts entities ("8
  **encounters**", "this **encounter**"). Set them to your grain's real-world noun; they are
  cosmetic but user-facing.
- **Describing the product:** `description` (shown in the UI), `links` (a list of URLs, e.g. the data
  sources), `owner`, and **`license`**, the terms the data is used under. All are served by `/s`,
  so the UI, SDKs and AI clients can read them. `license` is an object of string fields (a plain
  string is shorthand for `{"name": ...}`); declare whatever the source's terms need, e.g.
  `{"name": "...", "url": "...", "attribution": "...", "commercial_use": "not allowed",
  "redistribution": "not allowed"}`. Set it whenever the data comes with terms or required
  attribution.
- **`prompts`** (optional): starter questions the product answers well, offered by AI clients over
  the FC's MCP endpoint (`mcp.md`). A list of strings, or objects with `text` plus optional `name`,
  `title`, `description`.
- **Identity lives in the manifest, not `main.json`.** A legacy FC may still carry
  `data_product_definition` in `main.json`. The engine accepts it there, and when both are set the
  **manifest wins**. Don't keep two copies: when you bring an FC to the standard, move the block
  into the manifest and delete it from `main.json`. A second instance that needs a different title
  gets its own manifest (below).
- **`run_tests` and `hide_failed_arguments` live only in the manifest's `serve` block** —
  unlike identity, `main.json` does not carry either (a leftover key there is ignored, with a
  one-time startup warning). `hide_failed_arguments` marks any argument whose auto-test fails as
  invalid and hides it from the front end, instead of failing the whole protocol — useful when one
  FC serves several similar-but-not-identical schemas (e.g. several data products built from one
  codebase) and an argument valid for one instance doesn't exist in another, as long as it's
  optional.
- **`main.json` also controls front-end presentation.** Beyond `overview_protocol`, `protocols`
  (registered) and `tests`, it has two grouping maps the UI renders:
  - **`categories` = the collections** the user sees as **tiles**. Organize by **app *type*** (e.g.
    *Instant Reports*, *Summaries*, *Downloads*, *Customizable Reports*). A protocol belongs to
    **exactly one** collection.
  - **`tags` = the right-hand filter checkboxes.** Organize by **data *type*** (e.g. *Response*,
    *Mutations*, *IHC*, *Clinical*, *Adverse Events*). A protocol may carry **multiple** tags.
  When you register a new protocol, add it to **one category and its appropriate tag(s)** — an
  unplaced protocol still runs but is hard for users to find.
- **Cloud-served products** add storage coordinates at the **top level** (bucket + auth) so the
  archive can be fetched from S3 / GCS / Azure; pick the matching server jar
  (`configuration-and-sources.md`).

## One repo, many instances

A single repo can define **several deployable instances**, each its own **manifest** (and its own
deployment entry, `governance.md`). What varies between instances lives in the **manifest**, not
necessarily in the config — and this is deliberately flexible:

- **Same config + same main, different source.** For an FC built around a common **schema**, one
  instance can source from a **public** dataset and another from a **private** one — identical
  `config` and `main.json`, different manifests (different source/connection, archive, deployment).
  The data model and the apps are the same; only where the data comes from differs.
- **Different config, same grain.** A **fixed-date snapshot** vs a live build, or a differently
  filtered source, is a second manifest pointing at a **different config** at the *same* grain.
- **Different config, different grain = a genuinely different FC.** A different entity grain means
  different `unique_keys`, hence a different config (`entities.md`: one FC has one grain). It is
  still just another manifest in the same repo.

So "another FC" is really "another manifest/deployment"; whether it reuses the config and main or
swaps them is up to you. (When several instances share one `main`, every collection that `main`'s
protocols reference must exist in **every** instance's build.)

## Versioning

The archive is **immutable once written**. Deployments read a **stable** archive name
(`archive.ser`), so a new build is served without editing any config. History is kept beside it:
`legacy_archive=true` on the production build also writes a permanent `archive.ser.<uuid>.<version>`
copy, and the transfer script uploads both. To serve or roll back to a specific past build, point an
instance's `archive` at that UUID copy. See `preprocessing-and-rebuilds.md` for the full pattern
and why archive names, like file names, stay stable.

## Where it's used

- `_shell_scripts/build_archive.sh` → `build_archive manifest=manifest.json`
- `_shell_scripts/run_server.sh` → `run_server manifest=manifest.json`
- `_shell_scripts/compile_local.sh` → `compile manifest=manifest.json` (fast, no data load)

Next: `preprocessing-and-rebuilds.md` — keeping the definition static while the data changes.
