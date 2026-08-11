# tagbio-ai

AI enablement for building on — and analyzing — the Tag.bio / Flux platform.

Each subdirectory of `skills/` is a self-contained Claude Code **skill** — a set of
Markdown files that teach a Claude how to do one job well, with a worked example it can
read and copy.

## Skills

- **`skills/fc-authoring/`** — how to author a Flux data product (an "FC") from scratch:
  data modeling from CSV/SQL sources, entities, collections and variables, parsers,
  data_functions, protocols (the cohort builder and R/Python plugins), and transformers.
  Threaded throughout by a small fictional **clinic** example FC.
- **`skills/tagbio-analysis/`** — how to **consume** a deployed FC as an analyst: connect and
  authenticate, discover collections, pull a dataframe, filter server-side, join sibling products,
  and analyze the result honestly. Product- and tenant-agnostic — it names no host, no product, and
  no collection. Carries the data-access guardrails (consent, PHI attestation, no data values in
  the transcript).

The two are companions: **author** with the first, **query** with the second. Each states when to
hand off to the other.

## Using a skill

Three ways, in order of convenience.

**Install the plugin** — both skills, kept up to date by git:

```
/plugin marketplace add https://github.com/tag-bio/tagbio-ai
/plugin install tagbio
```

Use the **full HTTPS URL**. The `tag-bio/tagbio-ai` shorthand clones over SSH, which fails on a
machine with no GitHub SSH key — including most notebook environments. (`CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1`
is the other way to force HTTPS.)

The plugin name alone is enough; `tagbio@tagbio` is the equivalent fully-qualified form, needed only
if another marketplace you've added also ships a plugin called `tagbio`.

Skills then invoke as `/tagbio:fc-authoring` and `/tagbio:tagbio-analysis` (or load on their own,
from their descriptions).

To pick up a new release:

```
/plugin marketplace update tagbio      # pull this repo
/plugin update tagbio@tagbio           # then update the plugin — restart to apply
```

Note the asymmetry: `install` accepts the bare `tagbio`, but **`update` requires the qualified
`tagbio@tagbio`** and reports `Plugin "tagbio" not found` without it. Both steps are needed — the
first refreshes the catalog, the second installs from it.

Nothing is delivered until the plugin's `version` is bumped, so a merged content change alone will
not reach installed users. See [plugins/tagbio/README.md](plugins/tagbio/README.md).

**Install one skill on its own** — copy a `skills/<name>/` directory to `~/.claude/skills/<name>/`
(user-wide) or `<repo>/.claude/skills/<name>/` (per project). It keeps the bare `/<name>` command.
`skills/tagbio-analysis/INSTALL.md` covers this, including image-wide and shared-filesystem
distribution for a whole team.

**Just read it** — point a Claude at the skill directory, or hand it the `SKILL.md`. Nothing to
install. The `SKILL.md` is the spine: it states what to read, in what order, and pulls in the topic
files under `references/` on demand.

## Prerequisites

You can **read and learn** this skill with nothing installed. To actually **build and run** an FC:

- **Java** — the FC engine runs on the JVM (developed against Java 21).
- **The FC server jars** (`fc_csv_server`, `fc_sql_server`, …) — distributed under authorization,
  not public; see the server-jar table in `skills/fc-authoring/references/configuration-and-sources.md`.
  Authorized users obtain them by syncing the internal jar bucket with the AWS CLI (`aws s3 sync`),
  which requires an AWS profile with access (`AWS_PROFILE`).
- **The SDKs**, installed into the environment, for plugins and ad-hoc queries:
  R `tagbio` (<https://github.com/tag-bio/tagbio>) and Python `tagbiopy`
  (<https://github.com/tag-bio/tagbiopy>). Install these (e.g. `R CMD INSTALL` the R SDK; `pip
  install` the Python SDK), and ensure the Python SDK's **console scripts** (e.g.
  `connect_tagbio_py`) are on your **`PATH`** — the engine execs them by name.
- **Plugin libraries** beyond the SDKs go in each FC's `deploy/build-container.sh`. The example's
  plugins need R `plotly` and Python `plotly`, `papermill`, `nbconvert`.
- **Environment variables** used by the example `_shell_scripts/`: `TAGBIO_JARS` (jar directory),
  `TAGBIO_R_UTILS`, `TAGBIO_PY` (SDK locations).

The FC engine ships continuously (CI/CD) — there is no pinned version to target; you are always on
the **latest**. These docs describe stable concepts and syntax, but specific attributes or messages
can change under you. When something doesn't match, treat the **running engine as the source of
truth**: check its `help` output and validate with the fast `compile` loop
(`skills/fc-authoring/references/dev-loop.md`).

## Quick start — prove your setup

After learning the skill, verify the toolchain end-to-end against the shipped example. From
`skills/fc-authoring/example-clinic-fc/`, with the env vars above set (and the Python SDK's console
scripts on `PATH`), each command should exit cleanly and every protocol test should pass. Both the
**CSV** and **SQL** variants build the same data model and pass all 8 protocol tests:

```bash
# CSV variant
bash _shell_scripts/compile_local.sh          # validate config + protocols (no data)
bash _shell_scripts/build_archive.sh          # build the archive (8 encounters)
bash _shell_scripts/run_server.sh             # serve; run_tests in the manifest runs the 8 tests

# SQL variant (same model, sourced from a generated SQLite DB)
bash _shell_scripts/make_sqlite.sh            # build data/clinic.db from the CSV/TSV
bash _shell_scripts/compile_local_sql.sh
bash _shell_scripts/build_archive_sql.sh
bash _shell_scripts/run_server_sql.sh
```

`run_server` runs the tests **on startup, asynchronously** — wait for them; each writes a result
file under `_test_results/` (gitignored). Green means the whole loop works on your machine. This is
the recommended first thing to do after installing the prerequisites.

## Support

Email **support@tag.bio** for help with these skills, the SDKs, or a data product. Bugs and
suggestions for the skill content are also welcome as GitHub issues on this repo.

## License

Licensed under the Apache License, Version 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
Free to use, copy, and adapt, including in commercial products.

**Use at your own risk.** This material is provided "as is", without warranty of any kind. You
are responsible for what your AI agent does after using this skill — including any data it
accesses or actions it takes. The skill's own guardrails require obtaining informed consent
before accessing any data source; follow them.
