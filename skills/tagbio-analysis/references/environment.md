# The environment — what you already have

## In a Tag.bio notebook, everything is preinstalled

The `tagbio-notebook` image ships the whole toolchain, whoever the tenant is, so you can start
querying right away. Check that the SDKs are current before relying on this skill's idioms (below).

**The env vars are the contract; the paths below are the current image defaults.** Read the vars
rather than hardcoding a path — a different image build or a self-hosted deployment can place these
elsewhere.

| What | Env var | Usual path in the notebook |
|---|---|---|
| Python SDK (`tagbiopy`) source | `TAGBIO_PY` | `/tagbiopy` |
| R SDK (`tagbio`) source | `TAGBIO_R_UTILS` | `/tagbior` |
| FC engine jars (~10 of them) | `TAGBIO_JARS` | `/tagbio-jars` |
| Your tenant's platform host | `TAGBIO_BASE_URL` | — (set per deployment; often an internal, **http-only** cluster address) |
| API key | — | `~/.tagbio.json` |

Both SDKs are also **installed** into the base conda env, so `import tagbiopy` and
`library(tagbio)` work with no setup. Java 21 is on `PATH`, so the engine jars run — which means
you can also **build and serve a product locally** (`local-fc.md`).

**Never assume — print it.** One line establishes the whole environment, and takes a second:

```bash
echo "$TAGBIO_JARS $TAGBIO_PY $TAGBIO_R_UTILS $TAGBIO_BASE_URL"; ls "$TAGBIO_JARS"
python -c "import importlib.metadata as m; print('tagbiopy', m.version('tagbiopy'))"
Rscript -e 'cat("tagbio", as.character(packageVersion("tagbio")), "\n")'
ls ~/.tagbio.json                     # the key file — check it exists; never print its contents
```

An empty `TAGBIO_BASE_URL` means the host must come from `~/.tagbio.json` instead (`connect.md`);
a missing `TAGBIO_JARS` means the `local-fc.md` workflow isn't available here, which is not a
blocker for querying a deployed product.

## Use the latest SDKs

This skill describes the **current** SDKs, and the R (`tagbio`) and Python (`tagbiopy`) SDKs are
released separately. If an idiom here doesn't behave as described, first make sure both SDKs are
current. Both repos are public, so checking the latest versions needs no credentials:

```bash
curl -fsSL https://raw.githubusercontent.com/tag-bio/tagbiopy/master/src/tagbiopy/__init__.py | grep __version__
curl -fsSL https://raw.githubusercontent.com/tag-bio/tagbio/master/tagbio/DESCRIPTION | grep ^Version
```

Compare with what you have (the version lines in the check above). To update, clone the latest
versions of both repos and install from the clones:

```bash
git clone https://github.com/tag-bio/tagbiopy.git
pip install ./tagbiopy

git clone https://github.com/tag-bio/tagbio.git
Rscript -e 'if (!requireNamespace("remotes", quietly=TRUE)) install.packages("remotes"); remotes::install_local("tagbio/tagbio", dependencies=TRUE)'
```

The R package lives in a **`tagbio/` subdirectory** of its repo, hence `tagbio/tagbio`. To update
later, `git pull` in each clone and install again. Restart any running kernel or local `run_server`
afterwards so it picks up the new SDK.

**Where to install depends on who owns the environment.** On your own machine, install straight into
it. In a shared, platform-managed environment (such as a notebook image whose base env other people
and the kernel rely on), don't install over the managed SDK: put the newer one in a **venv** (next
section) and leave the base alone, and ask your administrator to update the image so everyone gets it.

## Installing anything else — use a venv

Do **not** `pip install` into the base conda env: it is platform-managed and shared, and breaking
it breaks the preinstalled SDKs and the kernel.

```bash
python -m venv ~/.venvs/analysis
~/.venvs/analysis/bin/pip install <package>
```

If the code must run under a Jupyter kernel, register the venv as a kernel rather than installing
into base:

```bash
~/.venvs/analysis/bin/pip install ipykernel
~/.venvs/analysis/bin/python -m ipykernel install --user --name analysis
```

Note the venv won't see the base env's `tagbiopy`; either `pip install /tagbiopy` into it too, or
keep SDK work in the base kernel and heavy third-party work in the venv.

## Off-cluster (your own laptop)

Three differences. **The host changes:** an in-cluster address (typically
`*.svc.cluster.local`) **will not resolve** from outside, so use your tenant's **external HTTPS
host** — ask your Tag.bio administrator for it if you don't know it. **Config carries more:** put
both host and key in `~/.tagbio.json` (`connect.md`), since there's no `TAGBIO_BASE_URL` set for you.
**Nothing is preinstalled**, so install the SDKs by cloning the latest versions of both repos
("Use the latest SDKs" above); `bash setup.sh --python --r` from a `tagbio-ai` checkout does the same
(`companion-skills.md`). Off-cluster you own the environment, so installing straight into it is fine.

The engine jars are distributed under authorization, so without them the `local-fc.md` workflow is
notebook-only — author and query locally, and run any jar step in the notebook.
