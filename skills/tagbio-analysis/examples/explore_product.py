#!/usr/bin/env python3
"""Connect to a deployed Tag.bio product and describe it — WITHOUT pulling entity rows.

This is the safe first script to run against an unfamiliar product: `summary` returns metadata
only (collection names, types, sizes), not data values, so it does not move patient data.

    python explore_product.py fc-<name>

Pulling actual rows is a separate, gated act — see the guardrails in ../SKILL.md.
"""
import json
import os
import sys

# --- Connect -----------------------------------------------------------------------------------
# Current SDK (tagbiopy >= 1.0.3) in the notebook: bare FC(fc_name=...) resolves host + key.
# Older SDK (0.9.x): the scheme patch must precede the FC import, and host/key are passed
# explicitly. Doing it this way works on both.
import tagbiopy.request as req

HOST = os.environ.get("TAGBIO_BASE_URL")
if HOST and HOST.startswith("http://"):
    req.SCHEME = "http"          # defeat the http->https coercion for an internal http-only host

from tagbiopy.fc import FC       # noqa: E402  (import must follow the SCHEME patch)

CFG = os.path.expanduser("~/.tagbio.json")
if not os.path.exists(CFG):
    raise SystemExit(
        f"{CFG} not found. Create it with your API key (and the host, if TAGBIO_BASE_URL is\n"
        '  unset): {"TAGBIO_HOST_URL": "https://your-host", "TAGBIO_API_KEY": "email:uuid"}\n'
        "  then chmod 600 it. Generate the key in the front-end under account settings."
    )
with open(CFG) as fh:
    cfg = json.load(fh)
HOST = HOST or cfg.get("TAGBIO_HOST_URL") or cfg.get("TAGBIO_BASE_URL")
API_KEY = cfg["TAGBIO_API_KEY"]          # never hardcode this
if not HOST:
    raise SystemExit("No host: set TAGBIO_BASE_URL, or put TAGBIO_HOST_URL in ~/.tagbio.json.")

fc_name = sys.argv[1] if len(sys.argv) > 1 else "fc-clinic"
fc = FC(fc_name=fc_name, host=HOST, api_key=API_KEY)
fc.analysis_variables = []               # 0.9.x quirk: defaults to None, breaks .select()

# --- Describe ----------------------------------------------------------------------------------
print(f"product: {fc_name}   host: {HOST}")
print(f"entities: {fc.number_of_entities}")        # a PROPERTY, not a method
print(f"info: {fc.info}")

summary = fc.summary                                # a PROPERTY, not a method
print(f"\n{len(summary)} collections")
# Verified columns: Collection | Collection Type | Size | Entities without data
print(summary["Collection Type"].value_counts())

# "Entities without data" is the missingness count per collection — the denominator you need.
sparse = summary.nlargest(5, "Entities without data")[
    ["Collection", "Collection Type", "Size", "Entities without data"]
]
print(f"\nsparsest collections (of {fc.number_of_entities} entities):\n{sparse}")

# Names only — never print data VALUES from a real product.
print("\ncollections:")
for name in sorted(set(summary["Collection"])):
    print(f"  {name}")

# --- Guard your selections against typos -------------------------------------------------------
available = set(summary["Collection"])
wanted = ["Department", "Blood Pressure"]
print("\nrequested and present:", [c for c in wanted if c in available])
print("requested but MISSING:", [c for c in wanted if c not in available])
