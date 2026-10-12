"""List data products and collection sets, then look at a product through a small sample (Python).
Needs tagbiopy >= 1.0.12.

The listing calls move no data. head(n) and run() EXECUTE A REAL PULL (of n entities): under the
guardrails in ../SKILL.md, don't run them against a proprietary/regulated product without the
requester's attestation, and don't print the rows.

    python discover_and_sample.py fc-<name>      # a deployed product
    python discover_and_sample.py localhost      # a local run_server on :8000
"""
import sys

import pandas as pd

import tagbiopy
import tagbiopy.fc
from tagbiopy.fundamentals import CollectionSet

FC_NAME = sys.argv[1] if len(sys.argv) > 1 else "localhost"

# --- Connect ----------------------------------------------------------------------------------
if FC_NAME == "localhost":
    host = "http://localhost:8000"
    fc = tagbiopy.fc.FC(host=host)
else:
    host = None                                   # resolved from TAGBIO_BASE_URL / ~/.tagbio.json
    fc = tagbiopy.fc.FC(fc_name=FC_NAME)

# --- Discover (metadata only) -----------------------------------------------------------------
products = tagbiopy.list_data_products(host=host)  # Name, Title, Description, url, ...
print("data products on this cluster:", len(products))

sets = fc.list_collection_sets()                   # e.g. ['Labs']
print("collection sets:", ", ".join(sets) or "(none)")

# --- Sample (pulls n entities) ----------------------------------------------------------------
# head(n) is a reproducible sample of n entities (same seed, same entities), not "the first n".
# Put .where(...) before .head() to sample within a cohort.
if sets:
    family = fc.df.select(CollectionSet(sets[0])).head(25).run()
    print(f"{sets[0]!r} set: {family.shape[1]} columns on {len(family)} sampled entities")

# Single-valued categoricals as 'category' (opt-in); multi-valued columns stay "; "-joined strings.
names = fc.list_collections("categorical")
typed = fc.df.select(*names).head(25).run(categories=True)
print("category columns:", ", ".join(c for c in typed.columns if isinstance(typed[c].dtype, pd.CategoricalDtype)))
