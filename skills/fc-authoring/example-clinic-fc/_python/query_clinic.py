# Ad-hoc query against a running Clinic FC, with a quick analysis (Python).
#
# Two ways to connect:
#
#   LOCALHOST (used below): an FC you started yourself with run_server on this machine.
#     Pass host="http://localhost:8000" exactly — the SDK treats that as localhost and needs
#     NO authentication. fc_name selects the product.
#
#   DEPLOYED (Tag.bio cluster): host is the cluster URL (https). That DOES require
#     authentication — an api_key / token (do NOT hardcode credentials). See the commented line.
#
# Run this after `bash _shell_scripts/run_server.sh` is up.

import tagbiopy.fc
from tagbiopy.fundamentals import Numeric

# --- Connect to a LOCALHOST FC (no auth needed) ---
fc = tagbiopy.fc.FC(fc_name="fc-clinic", host="http://localhost:8000")

# --- Deployed alternative (requires auth; supply an api_key/token, never hardcode it) ---
# import os
# fc = tagbiopy.fc.FC(fc_name="fc-clinic", host="https://your-cluster-host",
#                     api_key=os.environ["TAGBIO_API_KEY"])

# Build the query: pick columns and run(). A numeric variable is a Numeric(collection, variable);
# a categorical collection is just its name. .run() returns a pandas DataFrame.
df = fc.df.select(
    "Department",
    Numeric("Blood Pressure", "Systolic"),
    Numeric("Blood Pressure", "Diastolic"),
).run()

# A numeric variable comes back named "<Collection>: <Variable>" (the Python SDK's separator);
# strip the prefix so the analysis code reads as plain Systolic / Diastolic.
df = df.rename(columns=lambda c: c.replace("Blood Pressure: ", ""))

# Quick analysis: mean blood pressure by department.
summary = (
    df.groupby("Department")[["Systolic", "Diastolic"]]
      .agg(["mean", "count"])
)
print(summary)
