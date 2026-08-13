# Python with an FC — plugins and ad-hoc queries

Python mirrors R (`r.md`): **authoring a plugin** for an `external` protocol, and **querying a
product ad-hoc**.

> The Python SDK is the **`tagbiopy`** package — <https://github.com/tag-bio/tagbiopy> — installed
> into the FC environment (used by both plugins and ad-hoc scripts).

## Installing the Python SDK into your own environment

For local / ad-hoc use (outside an FC container), clone the public repo and `pip install` it — or let
**`setup.sh --python`** at the tagbio-ai repo root clone + install it for you:

```sh
git clone https://github.com/tag-bio/tagbiopy.git
pip install ./tagbiopy
```

`pip install` puts the SDK's **console script** (`connect_tagbio_py`, which `external` Python
protocols invoke) in your Python install's `bin`/`Scripts` dir — that dir isn't always on `PATH`
(common with `--user` or some venvs). If a Python plugin fails with "command not found," add it to
`PATH` (`python -m site --user-base` → `/bin`) or run inside the environment where it's installed.

## Authoring a Python plugin

An `external` protocol with `"sdk": "connect_tagbio_py"` invokes a Python plugin
(`protocols/plugins/*.py`). A plugin is a **function of `(tag_data, tag_result)`**, typed with
the SDK's `TagbioData` / `TagbioResult`:

> **How the entry function is found — by *signature*, not name.** The protocol names the *file*
> (`"plugin": "…/plugin_bp.py"`), not a function. The SDK loads the module and calls the function
> whose arguments are **exactly `(tag_data, tag_result)`** — so the name (`blood_pressure_report`
> here) is yours to choose. **Keep exactly one such function per file**; helper functions are fine as
> long as they don't share that signature. (The R plugin differs: the whole file evaluates to a
> single anonymous `function(tag_data, tag_result)`.)

```python
# protocols/plugins/plugin_bp.py
from tagbiopy.protocol import TagbioData, TagbioResult
import plotly.express as px


def blood_pressure_report(tag_data: TagbioData, tag_result: TagbioResult):
    # tag_data.df is a pandas DataFrame: one row per entity, columns = the analysis_variables.
    # A numeric variable arrives as "<Collection>: <Variable>" (see the note below); strip the
    # prefix so columns read as plain Systolic / Diastolic.
    df = tag_data.df.rename(columns=lambda c: c.replace("Blood Pressure: ", ""))
    tall = df.melt(id_vars=["Department"],
                   value_vars=["Systolic", "Diastolic"],
                   var_name="measure", value_name="mmHg")
    fig = px.box(tall, x="Department", y="mmHg", color="measure")
    fig.write_html(tag_result.path)   # write output for output_type: html
    return tag_result
```

Key points:

- **Input:** `tag_data.df` is a **pandas DataFrame** — one row per entity, columns named by the
  protocol's `analysis_variables`. A **categorical** collection is its own name (`Department`); a
  **numeric variable** arrives as **`"<Collection>: <Variable>"`** — e.g. `"Blood Pressure:
  Systolic"`. (The Python SDK uses a `": "` separator here; the **R SDK uses `" = "`** for the same
  thing — a known inconsistency between the two SDKs. Rename the columns if you want plain names.)
- **`Unique ID` is always there.** The engine **automatically adds a `Unique ID` column** (the
  entity's unique-key combination) to every extract — ad-hoc queries and plugin frames alike — even
  when it isn't in `analysis_variables`. It's the **one guaranteed-unique value per entity**, so
  every row is always identifiable.
- **Output:** write to **`tag_result.path`** (or set `tag_result.df` for a tabular result) and
  `return tag_result`. (The **R** SDK spells this attribute **`tag_result$output_path`** — the two
  SDKs differ here as well as on the column separator; watch it when porting between languages.)
- **Libraries:** the plugin runs in the FC's environment; every package it imports (here `plotly`)
  must be installed in the FC's **container image** via `deploy/build-container.sh`
  (`governance.md`), or the protocol fails at load with `no package called '<X>'`.
- **Ignore the bytecode.** Running a Python plugin drops `__pycache__/*.pyc` next to it, named for the
  interpreter (e.g. `plugin_bp.cpython-312.pyc`) — regenerated cruft that a broad `git add` will happily
  commit. Add `__pycache__/` and `*.py[cod]` to the repo's `.gitignore`. (Note the interpreter tag: a
  Python-version bump under you produces a *new* filename, so a rule scoped to an old name silently
  re-commits it — ignore the directory, not a specific file.)

## Jupyter notebook flavor

A Python plugin can also **papermill-run a notebook**: a small `.py` plugin
(`sdk: "connect_tagbio_py"`) executes a companion `.ipynb` and converts it to HTML via
`ipynb_to_html`. Example: `protocols/plugins/plugin_bp_ipynb.py` + `bp_report.ipynb` (protocol
`ipynb_bp`). The `.py` plugin passes the packet-file **path** into the notebook as the `fc_packet`
parameter; the notebook loads its frame with `TagbioData(fc_packet).df` (pass the path directly —
`TagbioData` builds the packet internally). This flavor needs **`papermill`** and **`nbconvert`**
in `build-container.sh` (beyond `tagbiopy`), and the SDK's console scripts on `PATH`.

## Querying a product ad-hoc

The Python SDK connects to a running product and returns a pandas DataFrame. A runnable
**localhost** example is in `example-clinic-fc/_python/query_clinic.py`:

```python
import tagbiopy.fc
from tagbiopy.fundamentals import Numeric, Categorical

# LOCALHOST run_server FC — host is exactly the localhost URL (the SDK treats it as localhost, no
# auth); fc_name selects the product.
fc = tagbiopy.fc.FC(fc_name="fc-clinic", host="http://localhost:8000")

df = fc.df.select(
        "Department",                              # a categorical collection: just its name
        Numeric("Blood Pressure", "Systolic"),     # a numeric variable: Numeric(collection, variable)
        Numeric("Blood Pressure", "Diastolic"),
     ).run()                                        # .run() returns a pandas DataFrame
```

- **Select with objects, not raw names:** a categorical collection is its **name**; a numeric
  variable is **`Numeric(collection, variable)`** (there is a matching `Categorical(...)`). `.run()`
  executes the query. The returned columns still carry the `": "` naming
  (`"Blood Pressure: Systolic"`) — rename if you want plain names.
- **Three connection targets** (mirroring `r.md`): a **localhost** `run_server` FC — pass
  `host="http://localhost:8000"` **exactly**, no auth; a **deployed** cluster FC — an `https://…`
  host with **auth** (`api_key`/`token`, never hardcoded); and the **local build in progress** inside
  a **Python transformer** — the build's own server on localhost with **no `fc_name`** (a single-FC
  server needs no name, the analog of R's `tbl(con)`). Transformers can be R or Python; the R
  self-query idiom is shown in `transformers.md`.
- **Cross-SDK difference:** on localhost Python's `FC()` accepts `fc_name` **or** omits it, whereas
  **R's `tbl(con, "name")` errors on localhost** — it takes no name there. Don't carry the R rule
  over to Python (or vice versa); it's the same class of asymmetry as `: ` vs `= ` and
  `.path` vs `$output_path`.
- **Localhost port (harmonized as of tagbiopy 1.0.1):** Python's `FC()` now treats **any** localhost
  host as no-auth http, matching R — `http://localhost:7999` works, not only `:8000`. (Earlier SDKs
  force-rewrote a non-8000 localhost to `https://` and demanded a key.)
- **Deployed credentials** come from a **`~/.tagbio.json`** (host + key), the same file R uses:
  ```json
  { "TAGBIO_HOST_URL": "https://your-host", "TAGBIO_API_KEY": "<your-key>" }
  ```
  On **tagbiopy >= 1.0.1** a bare **`FC(fc_name="fc-x")`** resolves host + key from this file correctly
  (appends the `/fc-svc/<name>/` path and tolerates a trailing slash on the host):
  ```python
  fc = tagbiopy.fc.FC(fc_name="fc-x")     # host + key from ~/.tagbio.json
  ```
  (On older SDKs bare `FC` misrouted the URL and 405'd; if you're stuck on one, read the file and pass
  `host=cfg["TAGBIO_HOST_URL"], api_key=cfg["TAGBIO_API_KEY"]` yourself.) Still keep the **host without a
  trailing slash** as hygiene, and **never hardcode the key.** Prefer the **file over environment
  variables**: it's per-machine and unambiguous, and the two SDKs currently read env-vs-file in
  **opposite order** (R env-first, Python file-first), so a stray env var can send R and Python to
  different hosts. (Ask your Tag.bio admin for a key; localhost needs none.)
- **In a plugin, connection/auth come ONLY from the engine packet — never `~/.tagbio.json`.** The plugin
  runner (`connect_tagbio_py` / `connect_tagbio.R`) sets a `TAGBIO_PLUGIN_CONTEXT` sentinel, so the SDK
  refuses the config file inside a plugin (a developer's key must not ride along — that would be a
  privilege escalation). A plugin's own-FC callback uses localhost (no auth); a call to **another**
  deployed FC carries the **invoking user's token** (`parameters$token` in R). To locally test a plugin
  that pulls from a remote FC, set **`TAGBIO_PLUGIN_ALLOW_CONFIG=1`** to opt back into your
  `~/.tagbio.json` for that run (both SDKs). Introduced tagbiopy 1.0.1 / tagbio 1.1.67.
- **Discover before you select:** `fc.summary` (a **property** — no parentheses) returns a DataFrame
  describing every collection (name, type, size); `fc.list_collections("categorical")` / `("numeric")`
  list names by type. Use them to choose columns instead of guessing. (R spells the describe call
  `summary(fc)` — a method; another small cross-SDK asymmetry.)
- **Select only what you need on a large deployed product.** Every selected collection streams all
  entity rows, and selecting *all* collections can exceed the server's ~2-minute gateway timeout and
  fail. Discover, select a subset, `.run()`. For a **full-data download, use the product's front-end
  download protocols** — server-side export, faster than any SDK `.run()`.
- **Filter server-side with `.where(...)`** chained before `.run()` — a cohort/background the engine
  applies, so you pull only the matching entities. Each condition is a tuple; combine multiple with
  `'AND'`/`'OR'` between them:
  - **Categorical:** `.where(("Department", "Cardiology"))`
  - **Numeric compare:** `.where(("Blood Pressure", "Systolic", ">", 120))` — a 4-tuple
    `(collection, variable, operator, value)`; operators `= != < <= > >=`.
  - **Not-null:** `.where(("Metabolic", "HbA1c", "not null"))` — a 3-tuple; keeps entities that
    *have* a value. `'is null'` is **not** offered (the engine can't do a numeric null match yet).
  Needs `tagbiopy >= 1.0.6`. (R writes these as dplyr `filter(!is.na(...))`, etc. — see `r.md`.)

> **Guardrail:** before running an ad-hoc query against any product or source, obtain the user's
> **informed consent** — they must know Claude is about to access potentially sensitive or
> regulated data (see `SKILL.md` → Guardrails).

## Recipe: write a Python plugin

1. Create `protocols/plugins/plugin_<name>.py` with a `def fn(tag_data: TagbioData, tag_result:
   TagbioResult): …`.
2. Read the frame from `tag_data.df` (pandas).
3. Produce output, write to `tag_result.path` (or set `tag_result.df`); `return
   tag_result`.
4. Ensure every imported package is installed in the environment.
5. Reference the plugin from an `external` / `"sdk": "connect_tagbio_py"` protocol
   (`protocols.md`).

## Common mistakes

- **Importing a package not in the environment** — the protocol fails to load.
- **Expecting columns that aren't in `analysis_variables`** — `tag_data.df` only has what the
  protocol requested.
- **Not writing to `tag_result.path`** (or setting `tag_result.df`) before returning.

Next: `transformers.md` — computing new collections after load, and enriching from other
products.
