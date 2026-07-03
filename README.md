# tagbio-ai

AI enablement for building on the Tag.bio / Flux platform.

Each subdirectory of `skills/` is a self-contained Claude Code **skill** — a set of
Markdown files that teach a Claude how to do one job well, with a worked example it can
read and copy.

## Skills

- **`skills/fc-authoring/`** — how to author a Flux data product (an "FC") from scratch:
  data modeling from CSV/SQL sources, entities, collections and variables, parsers,
  data_functions, protocols (the cohort builder and R/Python plugins), and transformers.
  Threaded throughout by a small fictional **clinic** example FC.

## Using a skill

Point a Claude at the skill directory (or hand it the `SKILL.md`). The `SKILL.md` is the
spine: it states what to read, in what order, and pulls in the topic files under
`references/` on demand.

## Prerequisites

You can **read and learn** this skill with nothing installed. To actually **build and run** an FC:

- **Java** — the FC engine runs on the JVM (developed against Java 21).
- **The FC server jars** (`fc_csv_server`, `fc_sql_server`, …) — distributed under authorization,
  not public; see the server-jar table in `skills/fc-authoring/references/configuration-and-sources.md`.
- **The SDKs**, installed into the environment, for plugins and ad-hoc queries:
  R `tagbio` (<https://github.com/tag-bio/tagbio>) and Python `tagbiopy`
  (<https://github.com/tag-bio/tagbiopy>).
- **Environment variables** used by the example `_shell_scripts/`: `TAGBIO_JARS` (jar directory),
  `TAGBIO_R_UTILS`, `TAGBIO_PY` (SDK locations).

These docs were written against FC engine **2.98.x**; other versions may drift.

## License

Licensed under the Apache License, Version 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
Free to use, copy, and adapt, including in commercial products.

**Use at your own risk.** This material is provided "as is", without warranty of any kind. You
are responsible for what your AI agent does after using this skill — including any data it
accesses or actions it takes. The skill's own guardrails require obtaining informed consent
before accessing any data source; follow them.
