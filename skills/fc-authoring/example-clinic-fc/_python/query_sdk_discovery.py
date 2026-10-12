# Ad-hoc check (Python): data product and collection set discovery, head(n), collection-set selection,
# timestamp columns, and opt-in categories for single_valued categoricals.
#
# Requires tagbiopy >= 1.0.12 and an engine with single_valued (2.99.34+).
# Run after `bash _shell_scripts/run_server.sh` is up.

import pandas as pd

import tagbiopy
import tagbiopy.fc
from tagbiopy.fundamentals import CollectionSet

HOST = "http://localhost:8000"
fc = tagbiopy.fc.FC(host=HOST)

# Discovery: a localhost host lists itself; the toy has one collection set, Labs.
products = tagbiopy.list_data_products(host=HOST)
assert {"Name", "Title", "Description", "url"} <= set(products.columns), products.columns
assert len(products) == 1, "localhost lists one data product"
sets = fc.list_collection_sets()
assert "Labs" in sets, sets
print("collection sets:", ", ".join(sets))

# head(n): exactly n entities, the same ones for the same seed, a filter is respected.
first = fc.df.select("Encounter ID").head(3).run()
again = fc.df.select("Encounter ID").head(3).run()
other = fc.df.select("Encounter ID").head(3, seed=7).run()
cardio = fc.df.select("Department").where(("Department", "Cardiology")).head(2).run()
assert len(first) == 3, "head(3) returns 3 entities"
assert sorted(first["Encounter ID"]) == sorted(again["Encounter ID"]), "same seed, same entities"
assert sorted(first["Encounter ID"]) != sorted(other["Encounter ID"]), "different seed, different entities"
assert len(cardio) == 2 and set(cardio["Department"]) == {"Cardiology"}, "head() keeps the filter"

# CollectionSet: every Labs collection comes back in one pull.
labs = fc.df.select("Encounter ID", CollectionSet("Labs")).run()
assert {"Lab Panel", "Lab Analyte", "Lipid: LDL"} <= set(labs.columns), labs.columns

# Timestamps: numeric epoch milliseconds by default, datetime when the server runs native_timestamps=true.
dates = fc.df.select("Encounter Date").run()["Encounter Date"]
assert pd.api.types.is_numeric_dtype(dates) or pd.api.types.is_datetime64_any_dtype(dates), dates.dtype

# Opt-in categories: single_valued categoricals become 'category' only when asked; multi-valued stays text.
plain = fc.df.select("Department", "Conditions").run()
typed = fc.df.select("Department", "Conditions").run(categories=True)
assert plain["Department"].dtype == object, "default keeps plain strings"
assert isinstance(typed["Department"].dtype, pd.CategoricalDtype), "categories=True gives 'category'"
assert typed["Conditions"].dtype == object, "multi-valued Conditions stays a string"

print("PASS: discovery, head(n), collection sets, timestamps, opt-in categories")
