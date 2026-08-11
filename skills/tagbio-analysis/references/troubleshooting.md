# Troubleshooting — symptom to cause

## Connection and auth

| Symptom | Cause and fix |
|---|---|
| `SSL: WRONG_VERSION_NUMBER` | An old `tagbiopy` force-upgraded `http://` → `https://` against an http-only internal host. Set `tagbiopy.request.SCHEME = "http"` **before importing `FC`** (`connect.md`). Internal hosts only — never for an external endpoint. |
| HTTP **405** on a bare connection | Older SDK misrouting the URL, or an ambient host hijacking resolution. Pass `host=` and `api_key=` explicitly. |
| **401 / 403** | Missing or stale API key, or no access to that product. Check `~/.tagbio.json` holds `TAGBIO_API_KEY` as `email:uuid`; regenerate in the front-end. |
| Host won't resolve off-cluster | `*.svc.cluster.local` is internal-only. Use the external HTTPS host in `~/.tagbio.json`. |
| R and Python reach **different servers** | Older SDKs read env-vs-file in opposite orders. Pass the host explicitly to settle it. |
| Connection refused on localhost | `run_server` hasn't finished startup — it loads the archive and runs auto-tests **before** serving. Wait, and check the process is still alive (a failed test kills it). |

## Selecting and pulling

| Symptom | Cause and fix |
|---|---|
| `TypeError: can't multiply sequence by non-int of type 'float'` doing arithmetic on `summary` | `Size`, `Entities without data`, and `info["entity_count"]` arrive as **comma-formatted strings**. Coerce with `pd.to_numeric(str(x).replace(",", ""))` (`discover.md`). |
| A rate computed from `summary["Size"]` is absurdly small | `Size` is **not** a populated count — it's level-cardinality for categoricals, variable-count for numerics. In Python use `entity_count - Entities without data`; **in R the populated count is `collection_entity_count` directly** — that same subtraction there gives you the missing count (`discover.md`). |
| `Entities without data` is `NaN` for a numeric collection | Expected — the server doesn't report numeric missingness. Pull the column and count nulls. |
| Columns are `"X: X"` in a plugin but `"X"` in an ad-hoc pull | Not a bug: the plugin frame always applies `"<Collection>: <Variable>"`, and a single-variable numeric often names its variable after the collection. Normalize both cases (`query.md`). |
| `TypeError` from inside `select()` | A name that isn't a collection in **this** product. Intersect against `fc.summary` / `colnames(fc)` first (`discover.md`). |
| A sibling product 403s or 502s while others work | The registry lists products your key can't reach (**403**) and ones registered but not currently serving (**502**). Neither is an SDK fault — report and move on. |
| `AttributeError` on `.select()` (tagbiopy 0.9.x) | `fc.analysis_variables` defaults to `None`. Set `fc.analysis_variables = []` before selecting. |
| A bare `collect()` returned **every column** | Verified on tagbio 1.1.77: no `select()` means **pull everything**, silently. Always `select()` first (`query.md`). |
| `.where(...)` ran fine but nothing was filtered | **tagbiopy 0.9.x: `.where()` exists and silently no-ops.** Check by row count, never by `hasattr`. Filter client-side (`environment.md`). |
| R: `Column 'Collection' doesn't exist` reading `summary()` | R uses **snake_case** (`collection`, `collection_type`, `collection_size`, `collection_entity_count`). Python-shaped code fails here (`discover.md`). |
| Missingness looks inverted between R and Python | It is. Python's `Entities without data` counts entities **without** a value; R's `collection_entity_count` counts those **with** one. They're complements (`discover.md`). |
| `KeyError: 'Unique ID'` | The auto-added key column is **product-dependent** — some products add `Unique ID`, others their own key (e.g. `Sample ID`). Resolve it, don't hardcode (`data-model.md`). |
| One numeric selection returned thousands of columns | Expected on a genomics product — `Size` is the fan-out factor and can exceed 24,000. Select individual `Numeric(coll, var)` axes (`discover.md`). |
| A numeric column "doesn't exist" | You selected the bare variable name. A numeric needs collection **and** variable — `Numeric(coll, var)` / `` `Coll = Var` ``. |
| Column names have `= ` or `: ` prefixes | Expected — R uses `Collection = Variable`, Python `Collection: Variable`. Strip with `sub()` / `.rename()`. |
| `No method asJSON S3 class: request` (R) | A **masked 504** — the gateway timed out (~2 min). You selected too much. Select fewer collections, or use the front-end download protocol. |
| `RemoteDisconnected` (Python) | Same class of problem, usually a **high-cardinality free-text column** bloating the payload. Drop it; look for the standardized sibling column. |
| Row count equals `number_of_entities` | No filter was applied — your `where`/`filter` didn't take effect. |
| `colnames(fc)` returns empty | Normal on a **localhost** serve. Select by literal name, or read `data_dictionary.tsv`. |
| "is null" filter errors | The engine has no server-side null match. Use **not-null**, or filter client-side. |
| `summary`/`.where` missing entirely | SDK too old. Check versions against the table in `environment.md`. |

## Results that look wrong

| Symptom | Cause and fix |
|---|---|
| A mean is dominated by a few subjects | You're at **event grain** — heavy utilizers contribute many rows. Collapse to one row per subject first (`analysis-patterns.md`). |
| Rate looks too low | Wrong denominator: you divided by all entities instead of **entities with a value** (`data-model.md`). |
| A join multiplied the rows | The "one" side wasn't unique, or you joined on the wrong-grain key. Check `is_unique` on both sides and use `validate="one_to_one"`. |
| Join match rate is near zero | Wrong key name (they differ subtly across sibling products) or wrong grain. Re-discover the key in each product. |
| `value_counts()` sums above the entity count | A **multi-valued** categorical — an entity can hold several levels at once (`data-model.md`). |
| A column is almost entirely null | Usually **normal** at event grain — rows are heterogeneous. Filter to the record type. |
| Dates in 1900 or 3025 | Sentinel/outlier values in the numeric timestamp. Prefer the calendar-date string; clip to a sensible window and report the count dropped. |
| Effect appears then vanishes with another endpoint | Read the outcome-definition section of `analysis-patterns.md` — this is the expected behavior of cross-sectional vs incident endpoints, not a coding error. |
| A collection you expected isn't there | It wasn't built. Confirm against `data_dictionary.tsv` (local) or `summary` (deployed). If it's genuinely missing from the model, that's an `fc-authoring` change. |

## The reflex, in order

1. **Did `summary` / `colnames` list the name, spelled exactly?**
2. **Did you `select()` before `collect()`/`.run()`?**
3. **Do the SDK versions support the idiom you used?** (`environment.md`)
4. **Is your row count the grain you think it is?**
5. **Is your denominator "entities with a value"?**
6. Still stuck on a local build → read the build log and `data_dictionary.tsv` (`local-fc.md`).
