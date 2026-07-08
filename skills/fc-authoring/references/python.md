# Python with an FC — plugins and ad-hoc queries

Python mirrors R (`r.md`): **authoring a plugin** for an `external` protocol, and **querying a
product ad-hoc**.

> The Python SDK is the **`tagbiopy`** package — <https://github.com/tag-bio/tagbiopy> — installed
> into the FC environment (used by both plugins and ad-hoc scripts).

## Authoring a Python plugin

An `external` protocol with `"sdk": "connect_tagbio_py"` invokes a Python plugin
(`protocols/plugins/*.py`). A plugin is a **function of `(tag_data, tag_result)`**, typed with
the SDK's `TagbioData` / `TagbioResult`:

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
- **Output:** write to **`tag_result.path`** (or set `tag_result.df` for a tabular result) and
  `return tag_result`. (The **R** SDK spells this attribute **`tag_result$output_path`** — the two
  SDKs differ here as well as on the column separator; watch it when porting between languages.)
- **Libraries:** the plugin runs in the FC's environment; every package it imports (here `plotly`)
  must be installed in the FC's **container image** via `deploy/build-container.sh`
  (`governance.md`), or the protocol fails at load with `no package called '<X>'`.

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
- **Localhost port (cross-SDK, CONFIRMED — alternate ports are R-only):** R connects to a localhost
  `run_server` on **any** port (`tagConnect(host_url="http://localhost:7999")`, `r.md`). **Python
  does not.** `tagbiopy` skips auth **only** when `host == DEFAULT_HOST` (*exactly*
  `http://localhost:8000`); any other host requires an API key **and** is force-rewritten to
  `https://` (`request.py` `_set_host`/`auth`) — so `http://localhost:7999` becomes
  `https://localhost:7999` and fails no-auth. `:8000` is effectively hardcoded for the localhost
  path. A prime candidate for the SDK-harmonization work.
- **Deployed credentials** work the same as R (`r.md`): the SDK reads **`TAGBIO_HOST_URL`** and
  **`TAGBIO_API_KEY`** from the environment, or from a **`~/.tagbio.json`** (or `~/.tagbio.yaml`)
  with those keys. So you usually don't pass `api_key` at all — `FC(fc_name="…")` picks it up. The
  explicit `api_key=os.environ[...]` form is just for when you'd rather pass it directly; **never
  hardcode the key**. (Ask your Tag.bio admin to issue one; localhost needs none.)
- Filter server-side with `.where((Collection, value))` chained before `.run()`.

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
