# Companion skills — the public `tagbio-ai` repo

This skill (`tagbio-analysis`) covers **consuming** a data product. It has a companion that covers
**building** one, and it lives in Tag.bio's public, Apache-2.0 repo:

**https://github.com/tag-bio/tagbio-ai**

```
tagbio-ai/
├── setup.sh                     # clones the R + Python SDK repos; optional install
└── skills/
    └── fc-authoring/            # the companion skill
        ├── SKILL.md
        ├── references/*.md      # entities, parsers, protocols, transformers, dev-loop, …
        └── example-clinic-fc/   # a runnable toy FC (the `fc-clinic` / Department /
                                 #   Blood Pressure vocabulary used in this skill's examples)
```

`fc-authoring` is the **upstream authority** on the data model: entities/grain, collections vs
variables, parsers, protocols, plugin authoring, and the build/serve dev loop. Where this skill
summarizes the model (`data-model.md`), that file is the full treatment.

## Is it installed here?

```bash
ls "${TAGBIO_AI_DIR:-$HOME/tagbio-ai}/skills"          # the checkout
ls -d ~/.claude/skills/fc-authoring                     # wired in as a loadable skill
ls -d "$(dirname "$(dirname "$PWD")")/fc-authoring" 2>/dev/null   # sibling, if this skill came from the repo
```

**Three ways this skill can reach you, and they change the answer:**

| You got `tagbio-analysis` as… | `fc-authoring` is… |
|---|---|
| the `tagbio` **plugin** (`/plugin install tagbio`) | **already installed** — same plugin. Invoke `/fc-authoring` |
| a directory **inside a `tagbio-ai` checkout** (`skills/tagbio-analysis/`) | **already on disk** as `../fc-authoring` — read it in place; wire it up only if you want `/fc-authoring` |
| a standalone `~/.claude/skills/tagbio-analysis/` (tarball, image, shared mount) | **probably absent** — install it below |

## Install / update it

**Easiest, if the marketplace is reachable** — this installs `tagbio-analysis` *and*
`fc-authoring` together and keeps them updated by git:

```
/plugin marketplace add https://github.com/tag-bio/tagbio-ai
/plugin install tagbio
```

Use the **full HTTPS URL**, not the `tag-bio/tagbio-ai` shorthand: the shorthand clones over SSH,
which fails on a machine with no GitHub SSH key (the notebook usually has none). The plugin name
needs no `@marketplace` suffix unless it's ambiguous across your marketplaces.

**Otherwise**, the skill ships a script that clones (or fast-forward updates) the repo and wires
every skill it contains into `~/.claude/skills/`. It is idempotent and touches nothing else — no SDK
install, no jars, no changes to the base environment:

```bash
bash ~/.claude/skills/tagbio-analysis/scripts/install-companions.sh
# --dir <path>   checkout location (default $TAGBIO_AI_DIR, else ~/tagbio-ai)
# --copy         copy the skills instead of symlinking (if symlinks aren't picked up)
# --no-clone     wire up an existing checkout only; never touch the network
```

Start a new Claude Code session afterwards so the new skill is discovered.

## Using it from here

Once installed, `fc-authoring` is a **peer skill**, not a subdirectory of this one — invoke it by
name (`/fc-authoring`, or the Skill tool) and read its files directly. When the work spans both,
load both: this skill for the query/analysis side, `fc-authoring` for anything touching the model.

Hand off to `fc-authoring` when the task is:

- changing what a product contains — config, parsers, data_functions, transformers;
- writing or debugging a **protocol / plugin** (a different connection contract — see the plugin
  note in `connect.md`);
- the build/serve loop beyond the three commands in `local-fc.md`;
- "the collection I need doesn't exist" — that is a model change, not a query fix.

**Not installed and can't be?** The repo is public, so a single file can be read over HTTP without
a checkout:

```bash
curl -fsSL https://raw.githubusercontent.com/tag-bio/tagbio-ai/main/skills/fc-authoring/SKILL.md
curl -fsSL https://raw.githubusercontent.com/tag-bio/tagbio-ai/main/skills/fc-authoring/references/parsers.md
```

The `SKILL.md` reading-order table lists every reference file, so fetch the spine first and then
only the topic you need. If there's no network either, say plainly that the authoring guidance
isn't available rather than reconstructing it from memory.

## Getting help

For anything about these skills, the SDKs, or a data product — email **support@tag.bio**. Content
bugs can also go to <https://github.com/tag-bio/tagbio-ai/issues>. Report what `summary` actually
returned, never the data values.

## Pull before you rely on it

The SDKs, this skill, and `tagbio-ai` are all moving. Re-running
`install-companions.sh` fast-forwards the checkout (and refuses to clobber local edits). Do that
before quoting authoring behavior, and prefer a fresh `summary` over any documented example — the
running product is always the source of truth.

## A product's own skill

Many data products ship a third skill in their own repo, at
**`_AI/about-this-data-product/`** — it names that product's grain, join keys, and collection
families in its own jargon. It is the most specific of the three and, for questions about that
product, the most reliable. **Load it alongside this one** whenever you're working on a product
whose repo you have. This skill deliberately contains no product-specific collection names, so
that file (or a live `summary`) is where they come from.
