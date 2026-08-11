# The environment — what you already have

## In a Tag.bio notebook, everything is preinstalled

The `tagbio-notebook` image ships the whole toolchain, whoever the tenant is. **Do not run an SDK
`setup.sh` or clone the SDK repos** — you already have them, and the public jar-download URL in
`tagbio-ai/setup.sh` is still a placeholder.

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

## Check your SDK versions — the two SDKs are not in lockstep

Behavior changed meaningfully across recent SDK releases, and an image can lag. **Check the
versions before trusting any documented idiom**, including the ones in this skill.

| Feature | Needs | If your SDK is older |
|---|---|---|
| Bare `FC(fc_name=...)` resolves host+key from `~/.tagbio.json` | tagbiopy ≥ 1.0.1 | Pass `host=` and `api_key=` explicitly (`connect.md`) |
| Any-localhost-port treated as no-auth http | tagbiopy ≥ 1.0.1 | Only `:8000` works; other ports get forced to `https` |
| Reads `TAGBIO_BASE_URL` from the env | tagbiopy ≥ 1.0.3 / tagbio ≥ 1.1.69 | Read the host yourself and pass it in |
| Server-side `.where(...)` filters | tagbiopy ≥ 1.0.6 | Filter the returned frame client-side |
| Server-side `filter()` pushdown (R) | tagbio ≥ 1.1.74 | Filter after `collect()` |

**A concrete lag to expect:** an image may carry a **0.9.x `tagbiopy`** alongside a current
**1.1.x `tagbio`**. On 0.9.x, none of the Python rows above hold — and additionally it
**force-upgrades any non-localhost `http://` to `https://`**, which fails against an http-only
internal host with `SSL: WRONG_VERSION_NUMBER`. The workaround is in `connect.md`.

## Updating the SDKs

The notebook image ships a purpose-built updater. **Check it's there before recommending it** — it
comes with the image, not with this skill:

```bash
ls ~/notebook-environment-setup/update-sdks.sh                # present?

bash ~/notebook-environment-setup/update-sdks.sh              # both, from master
bash ~/notebook-environment-setup/update-sdks.sh --py-only    # Python only
bash ~/notebook-environment-setup/update-sdks.sh --r-only     # R only
```

It force-syncs the SDK repos and installs **the package only** (`--no-deps`), so it is safe inside
pinned environments. Three things to know: it needs **git access to the `tag-bio` SDK repos**
(credentials on the box — if your environment lacks them the updater will fail on the fetch, which
is a permissions issue, not a broken script); you must **restart any running kernel or
`run_server`** afterwards to pick up the change; and an SDK upgrade can change connection behavior,
so re-read the version table above after updating.

If the updater isn't present, or you can't reach those repos, **work with the SDK you have** — the
version table tells you which idioms to avoid, and every one of them has a client-side fallback.
Don't `pip install` an SDK over the platform-managed one to chase a feature.

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
host** — ask your Tag.bio administrator for it if you don't know it. **Nothing is preinstalled:**
clone and install the SDKs yourself — `bash setup.sh --python --r` from a `tagbio-ai` checkout does
both (`companion-skills.md`), or install by hand (`pip install` the Python SDK into a venv;
`R CMD INSTALL` / `remotes::install_local` the R one). **Config carries more:** put both host and
key in `~/.tagbio.json` (`connect.md`), since there's no `TAGBIO_BASE_URL` set for you.

The engine jars are distributed under authorization, so without them the `local-fc.md` workflow is
notebook-only — author and query locally, and run any jar step in the notebook.
