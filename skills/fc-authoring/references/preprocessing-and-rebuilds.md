# Preprocessing and rebuilds — put the mess in preprocessing

Real source data is messy. Files arrive with dates, vendor names and sample counts in their names.
New deliveries replace old ones, columns drift, and sometimes two vendors deliver the same kind of
data. This file covers **where that variability belongs**: in the preprocessing step that runs
**before** `build_archive`. It must never reach the config, the protocols or the deployment
descriptors.

## The rule

> **The FC definition is static. Preprocessing absorbs the variability.**

The **FC definition** is the config, the parsers, the protocols, `main.json`, `manifest.json` and
`deploy/deployments.yml`. It is versioned in git, and it describes a **stable** set of inputs: fixed
file names, fixed column names and fixed paths. A new data delivery changes the **data**. It does
not change the definition.

That gives three hard constraints:

1. **A build never edits JSON or YAML.** No script rewrites a parser's `file`, a manifest's
   `data_dir`, or a deployment's archive path to point at this week's delivery.
2. **A build never touches git.** Building or rebuilding an archive must leave the working tree
   clean. If a rebuild needs a commit, the variability is in the wrong place.
3. **Config changes are deliberate.** Change the config when the **data model** changes (a new
   collection, a new source table, a new grain). Don't change it because a file got renamed.

## What preprocessing does

Preprocessing is the scripts that fetch and prepare the source files before the build. By
convention they live in `_preprocess/` and are chained by one entry-point script. They:

- **Select the input.** Pick the file to use by a **rule** where you can (the newest by the date in
  its name, the one matching a pattern). A static path or URL in a preprocessing script is
  acceptable when no rule fits. When a vendor delivers a new file, editing a preprocessing script
  is expected; editing the config is not.
- **Normalize to stable names.** Copy or rename each selected file to the fixed name the config
  reads (`ihc.xlsx`, `guardant_response.csv`, `genes.tsv`), and normalize its columns and values
  if needed (dedup, reshape, recode). Whatever the source looked like, the build sees the same
  shape every time.
- **Record provenance as data.** Write down **what was selected** (the original file name, the
  release or data-cut date) somewhere the build reads, so it becomes a collection. Users then see
  where a number came from **in the product**, and nobody has to dig through a commit history for
  it. A simple pattern is a `<stable_name>.source.txt` sidecar per file. Preprocessing then adds a
  `Source File` column, and a parser turns it into a collection that apps can show.
- **Keep superseded inputs listed.** When a delivery is replaced, leave the old file name in a
  comment in the download script. That keeps the history readable without making it part of the
  build.

## Why it pays off

- **Rebuilds are cheap and safe.** A rebuild is `download → prepare → build_archive`, with no
  decisions and no diff. Anyone (or a scheduled job) can run it.
- **The schema becomes portable.** Because the config describes stable, normalized inputs, the same
  FC can be pointed at a **different source** (a new site, a new vendor, a public vs a private copy
  of the same schema) by writing a new preprocessing step. The config, protocols and apps are
  reused unchanged (`manifest.md` → "One repo, many instances"). The mess of each source stays in
  that source's preprocessing.
- **Review stays honest.** A diff to the config or protocols always means a real change to the data
  model or the apps, never a data refresh.

## Layout

```
fc-example/
  _preprocess/
    download_data.sh        # fetch the sources (static URLs/paths, or selection by rule)
    prepare_data.sh         # sets up the environment (e.g. a venv keyed on requirements.txt), runs prepare_data.py
    prepare_data.py         # normalize: stable names, cleaned/reshaped tables, provenance columns
    requirements.txt        # pinned deps for prepare_data.py
  _shell_scripts/
    download_and_prepare_data.sh   # the single entry point: download, then prepare
    build_archive.sh               # build_archive manifest=manifest.json
    run_server.sh                  # run_server manifest=manifest.json
    transfer_archive.sh            # deliberate push of a QC'd archive to its bucket
```

- Prepared data goes **outside the repo** (or into a gitignored folder), at the paths the manifest's
  `data_dir` and the config already name (`SKILL.md` → Guardrails: data is never committed).
- Keep a heavy step in the language it's written in. A Python or R prep script is fine; give it a
  thin bash wrapper so the whole chain still has one shell entry point. Don't port it to bash.
- Preprocessing runs **once per data refresh**, not on every build. It is not part of the
  `compile → build → serve` loop (`dev-loop.md`).

## Archives: a stable name, with history on the side

The same rule applies to the archive. Deployments read a **stable** archive key
(`<bucket>/<fc>-data/archive.ser`), so serving a new build never needs a config or deployment edit.
History is kept **next to** the stable archive, not by renaming it:

- `legacy_archive=true` on the **production** `build_archive.sh` makes the engine also write a
  permanent copy named `archive.ser.<uuid>.<server-version>`. The canonical `archive.ser` is still
  written as usual.
- `transfer_archive.sh` uploads both: the canonical `archive.ser`, which replaces the served one,
  and the UUID copy, which is retained. Any past build can then be retrieved by its UUID.
- Leave `legacy_archive` off for dev and test builds, so disposable builds don't fill the bucket.
- Keep the **build → QC → transfer** split. Running `transfer_archive.sh` is the developer's
  explicit "this archive is good enough to serve". Don't fold it into the build script. A test
  build must never overwrite what production serves.

## Anti-patterns

| Smell | Fix |
|---|---|
| A script `sed`s a file name or date into a parser or the manifest before each build | Rename the file to a stable name in preprocessing |
| A new data delivery needs a commit to the config | Move the selection into `_preprocess/` |
| The source file name or data date only exists in a commit message | Record it as a collection (a `.source.txt` sidecar → `Source File` column) |
| One parser per delivery (`..._v1`, `..._v2`) | Normalize every delivery to one stable file; keep the history in preprocessing comments |
| A dated archive file name in `deployments.yml` | Stable `archive.ser`; history through `legacy_archive` UUID copies |
| Build and upload to the served key in one step | Build, QC (`run_server` + tests), then `transfer_archive.sh` |

That completes the build path. Return to `SKILL.md` for the reading order and golden rules.
