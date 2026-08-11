# Installing the `tagbio-analysis` skill

A Claude Code skill that teaches Claude how to query and analyze a **Tag.bio / Flux data product**
with the R (`tagbio`) or Python (`tagbiopy`) SDK. It is product- and tenant-agnostic: it contains no
host, no product name, and no collection names — those come from your environment and from a live
`summary`.

## Pick a channel

| Channel | For | Updates | Invoked as |
|---|---|---|---|
| **A. Plugin marketplace** | any Tag.bio user, anywhere | automatic (git) | `/tagbio:tagbio-analysis` |
| **B. Baked into the notebook image** | every user of the image, zero setup | image rebuild | `/tagbio-analysis` |
| **C. Tenant shared mount** | everyone on one deployment, today | re-run the installer | `/tagbio-analysis` |
| **D. Tarball** | air-gapped, one-off | manual | `/tagbio-analysis` |

The slash command is a convenience either way — Claude loads the skill from its description without
anyone typing one.

### A. Plugin marketplace (recommended)

Ships `tagbio-analysis` and `fc-authoring` together, from the public repo:

```
/plugin marketplace add https://github.com/tag-bio/tagbio-ai
/plugin install tagbio
```

Use the **full HTTPS URL**. The `tag-bio/tagbio-ai` shorthand clones over SSH and fails without a
GitHub SSH key; `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` is the other way to force HTTPS.

`/plugin install tagbio` resolves across your configured marketplaces; the fully-qualified
`tagbio@tagbio` is equivalent and only needed if another marketplace you've added also ships a
plugin named `tagbio`.

To update later:

```
/plugin marketplace update tagbio      # pull the repo
/plugin update tagbio@tagbio           # then the plugin — restart to apply
```

`update` **does** require the qualified `tagbio@tagbio`; with the bare name it reports
`Plugin "tagbio" not found`. And an update only appears if the release bumped the plugin's
`version` — a merged content change alone doesn't reach installed users.

### B / C / D — install into `~/.claude/skills`

Any of these lands the skill at `~/.claude/skills/tagbio-analysis/`, which keeps the bare
`/tagbio-analysis` name:

```bash
# D — from the tarball
mkdir -p ~/.claude/skills
tar -xzf tagbio-analysis.tar.gz -C ~/.claude/skills
ls ~/.claude/skills/tagbio-analysis/SKILL.md      # sanity check

# C — from your deployment's shared mount, if your administrator published it there
bash ~/tagbio-jupyter-shared/claude-skills/install.sh

# B — nothing to do; the image syncs it on shell start
```

The directory name **is** the skill name, so it must expand to exactly
`~/.claude/skills/tagbio-analysis/`. Start a new Claude Code session and use it:

```
/tagbio-analysis
```

Or just ask a data question ("what's in fc-<name>?") — the skill's description makes Claude load it
on its own.

### One more variant: per-repo

Put it at `<repo>/.claude/skills/tagbio-analysis/` and commit it — then it travels with the repo and
needs no per-user step. Useful for a data-product repo whose contributors all query the product.

### For administrators

`dist/` in this skill's distribution bundle carries what you need to publish channels B and C: the
image sync script and Dockerfile snippet, and the shared-mount publisher. Both are idempotent and
neither touches the base conda environment.

## Companion skill

`fc-authoring` — how to *build* a data product — is bundled in the **A** channel already. Installed
any other way, this skill can fetch it for you:

```bash
bash ~/.claude/skills/tagbio-analysis/scripts/install-companions.sh
```

That clones **github.com/tag-bio/tagbio-ai** (default `~/tagbio-ai`, override with `--dir` or
`TAGBIO_AI_DIR`) and symlinks every skill it ships into `~/.claude/skills/`. Idempotent, network-only
on the clone/pull, and it installs no SDKs and no jars. See `references/companion-skills.md`.

## What it expects from the environment

Nothing, to be *read*. To actually run a query it needs, in order of preference from the env:

| | Where it comes from | Notes |
|---|---|---|
| Host | `TAGBIO_BASE_URL`, else `TAGBIO_HOST_URL` in `~/.tagbio.json` | Preset in the Tag.bio notebook; off-cluster, set it yourself |
| API key | `~/.tagbio.json` → `TAGBIO_API_KEY` (`email:uuid`) | Generate in the front-end → account settings; `chmod 600` |
| SDKs | Preinstalled in the notebook (`TAGBIO_PY` / `TAGBIO_R_UTILS`) | Off-cluster, both repos are public: `pip install "git+https://github.com/tag-bio/tagbiopy@master"` and `remotes::install_github("tag-bio/tagbio", subdir="tagbio")` |
| Engine jars | `TAGBIO_JARS` (notebook only) | Optional — needed only to serve a product locally |

Verify all of it in one line — see `references/environment.md`.

## Contents

```
SKILL.md                        the spine: the analysis loop, golden rules, guardrails
INSTALL.md                      this file
references/environment.md       what the environment gives you; SDK version differences
references/connect.md           auth, the three connection targets, working recipes
references/discover.md          listing collections — do this before every query
references/data-model.md        entity grain, collections vs variables, missingness
references/query.md             select, server-side filter, column naming, payload limits
references/analysis-patterns.md collapse-then-join, longitudinal work, honest endpoints, charts
references/local-fc.md          serving a product locally with the engine jars
references/companion-skills.md  the public tagbio-ai repo and when to hand off to it
references/troubleshooting.md   symptom → cause
examples/                       runnable Python + R scripts (neutral toy vocabulary)
scripts/install-companions.sh   installs the fc-authoring companion skill
```

## Support

Email **support@tag.bio** for help with the skills, the SDKs, or a data product. Content bugs can
also go to <https://github.com/tag-bio/tagbio-ai/issues>.

## Note on the guardrails

`SKILL.md` ends with five non-negotiable guardrails, and they are the reason this skill is safe to
hand to every user: consent before any real data pull, explicit per-request attestation for
proprietary or regulated (PHI-shaped) products, never echo data values into the transcript, treat
extracts and cached pulls as sensitive, and never hardcode credentials. **Don't strip these when
adapting the skill for your organization** — tighten them if your data classification requires it.
