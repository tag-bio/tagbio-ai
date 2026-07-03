# Ad-hoc query against a running Clinic FC, with a quick analysis (Python).
#
# Two ways to connect:
#
#   LOCALHOST (used below): an FC you started yourself with run_server on this machine
#     (serving on localhost:8000). A local server needs NO authentication.
#
#   DEPLOYED (Tag.bio cluster): an FC running as a container in the Tag.bio deployment
#     cluster. That DOES require authentication — a named connection string / stored
#     credentials. See the commented alternative below.
#
# Run this after `bash _shell_scripts/run_server.sh` is up.
# NOTE: confirm the exact client import/calls against your installed Tag.bio Python SDK version.

import tagbiopy

# --- Connect to a LOCALHOST FC (no auth needed) ---
con = tagbiopy.connect(host_url="http://localhost:8000")

# --- Deployed alternative (requires auth + a named connection; do NOT hardcode credentials) ---
# import os
# con = tagbiopy.connect(host_url=os.environ["TAGBIO_BASE_URL"], connection="my_named_connection")

# Pull just the columns you need into a pandas DataFrame.
df = con.table("fc-clinic").select(["Department", "Systolic", "Diastolic"]).collect()

# Quick analysis: mean blood pressure by department.
summary = (
    df.groupby("Department")[["Systolic", "Diastolic"]]
      .agg(["mean", "count"])
)
print(summary)
