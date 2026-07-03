# Python with an FC — plugins and ad-hoc queries

Python mirrors R (`r.md`): **authoring a plugin** for an `external` protocol, and **querying a
product ad-hoc**.

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
    tall = tag_data.df.melt(id_vars=["Department"],
                            value_vars=["Systolic", "Diastolic"],
                            var_name="measure", value_name="mmHg")
    fig = px.box(tall, x="Department", y="mmHg", color="measure")
    fig.write_html(tag_result.output_path)   # write output for output_type: html
    return tag_result
```

Key points:

- **Input:** `tag_data.df` is a **pandas DataFrame** — one row per entity, columns named by the
  protocol's `analysis_variables`.
- **Output:** write to `tag_result.output_path` (or set `tag_result.df` for a tabular result)
  and `return tag_result`.
- **Libraries:** the plugin runs in the FC's environment; every package it imports must be
  installed there, or the protocol fails at load. (Declare it in the FC's container setup.)

## Querying a product ad-hoc

The Python SDK connects to a deployed or local product and returns a pandas DataFrame — the same
shape as the R flow in `r.md` (connect → select columns → pull). Confirm the exact client import
for your SDK version; conceptually:

```python
# Deployed product (host + credentials), select the columns you want, pull a DataFrame.
# Mirrors the R tagConnect -> tbl -> select -> collect flow.
```

> **Guardrail:** before running an ad-hoc query against any product or source, obtain the user's
> **informed consent** — they must know Claude is about to access potentially sensitive or
> regulated data (see `SKILL.md` → Guardrails).

## Recipe: write a Python plugin

1. Create `protocols/plugins/plugin_<name>.py` with a `def fn(tag_data: TagbioData, tag_result:
   TagbioResult): …`.
2. Read the frame from `tag_data.df` (pandas).
3. Produce output, write to `tag_result.output_path` (or set `tag_result.df`); `return
   tag_result`.
4. Ensure every imported package is installed in the environment.
5. Reference the plugin from an `external` / `"sdk": "connect_tagbio_py"` protocol
   (`protocols.md`).

## Common mistakes

- **Importing a package not in the environment** — the protocol fails to load.
- **Expecting columns that aren't in `analysis_variables`** — `tag_data.df` only has what the
  protocol requested.
- **Not writing to `tag_result.output_path`** (or setting `tag_result.df`) before returning.

Next: `transformers.md` — computing new collections after load, and enriching from other
products.
