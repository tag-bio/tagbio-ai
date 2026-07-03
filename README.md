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
