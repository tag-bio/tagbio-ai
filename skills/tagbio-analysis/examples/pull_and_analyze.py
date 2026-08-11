#!/usr/bin/env python3
"""Pull a small dataframe from a Tag.bio product and summarize it — the full analysis loop.

⛔ THIS EXECUTES A REAL DATA PULL. Under the guardrails in ../SKILL.md, do not run it against a
proprietary/regulated product until the requester has attested to authorization, a compliant
environment, and the data boundary. Writing and reading this code is always fine.

    python pull_and_analyze.py

Edit COLLECTIONS to match what `explore_product.py` showed for YOUR product — the names below
are from the fc-authoring toy product and will not exist elsewhere.
"""
import json
import os

import pandas as pd

import tagbiopy.request as req

HOST = os.environ.get("TAGBIO_BASE_URL")
if HOST and HOST.startswith("http://"):
    req.SCHEME = "http"

from tagbiopy.fc import FC                              # noqa: E402
from tagbiopy.fundamentals import Categorical, Numeric  # noqa: E402

FC_NAME = "fc-clinic"
CACHE = os.path.expanduser(f"~/.{FC_NAME}_cache.pkl")   # an extract: keep out of git, delete when done

CFG = os.path.expanduser("~/.tagbio.json")
if not os.path.exists(CFG):
    raise SystemExit(f"{CFG} not found — see examples/explore_product.py for the format.")
with open(CFG) as fh:
    cfg = json.load(fh)

# --- Pull (cached) -----------------------------------------------------------------------------
if os.path.exists(CACHE):
    df = pd.read_pickle(CACHE)
    print(f"loaded cache: {CACHE}")
else:
    fc = FC(fc_name=FC_NAME, host=HOST or cfg.get("TAGBIO_HOST_URL"),
            api_key=cfg["TAGBIO_API_KEY"])
    fc.analysis_variables = []

    # Select ONLY what you need. Discover the real names first (explore_product.py).
    available = set(fc.summary["Collection"])
    for needed in ("Department", "Blood Pressure"):
        if needed not in available:
            raise SystemExit(f"'{needed}' is not a collection in {FC_NAME} — re-run discovery")

    df = fc.df.select(
        Categorical("Department"),                     # categorical: the collection name
        Numeric("Blood Pressure", "Systolic"),         # numeric: (collection, variable)
        Numeric("Blood Pressure", "Diastolic"),
    ).run()
    df.to_pickle(CACHE)          # pickle, not parquet — pyarrow may not be installed

# The Python SDK returns numerics as "<Collection>: <Variable>". Strip defensively (not by
# positional assignment — a collection can expand into more sub-variables than you expect).
df = df.rename(columns=lambda c: c.replace("Blood Pressure: ", ""))

# --- Report structure, not rows ----------------------------------------------------------------
print(f"\nshape: {df.shape}")
print(f"columns: {list(df.columns)}")
print(f"nulls per column:\n{df.isna().sum()}")

# --- Analyze -----------------------------------------------------------------------------------
# The denominator is entities that HAVE a value, not all entities. count() gives exactly that.
summary = df.groupby("Department")[["Systolic", "Diastolic"]].agg(["mean", "median", "count"])
print(f"\nby department (count = entities with a value):\n{summary}")

# Guard against the grain trap: if this product were event-grain, these rows would be events,
# not subjects, and the means would be weighted by how often each subject appears. `Unique ID`
# is added automatically to every extract, so you can always check for a fan-out.
if "Unique ID" in df.columns:
    print(f"\nrows: {len(df)}   distinct entities: {df['Unique ID'].nunique()}")
