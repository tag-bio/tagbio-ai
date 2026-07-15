# R with an FC — plugins and ad-hoc queries

R is used with an FC in two ways: **authoring a plugin** (the code an `external` protocol runs)
and **querying a product ad-hoc** (pulling data into an R session for exploration). Python is the
same story in `python.md`.

> The R SDK is the **`tagbio`** package — <https://github.com/tag-bio/tagbio> — installed into the
> FC environment (used by both plugins and ad-hoc scripts).

## Installing the R SDK into your own environment

For local / ad-hoc use (outside an FC container), clone the public repo and install from source — or
let **`setup.sh --r`** at the tagbio-ai repo root clone + install it for you:

```sh
git clone https://github.com/tag-bio/tagbio.git
Rscript -e 'if (!requireNamespace("remotes", quietly=TRUE)) install.packages("remotes"); remotes::install_local("tagbio/tagbio", dependencies=TRUE)'
```

The package lives at `tagbio/tagbio` inside the repo; `dependencies=TRUE` pulls its imports (httr,
dplyr, tidyverse, …).

## Authoring an R plugin

An `external` protocol with `"sdk": "R"` invokes an R plugin file (`protocols/plugins/*.R`). A
plugin is a **function of `(tag_data, tag_result)`**:

```r
# protocols/plugins/plugin_bp.R
if (!require('plotly')) install.packages('plotly', repos = "http://cran.us.r-project.org")
require('plotly'); require('dplyr'); require('tidyr')

function(tag_data, tag_result) {
  # The analysis frame: one row per entity; columns are the protocol's analysis_variables,
  # with the row_name collection used as the row names.
  data <- tagbio::get_results(tag_data, row_name = "Encounter ID")

  # A numeric variable arrives named "<Collection> = <Variable>" (e.g. "Blood Pressure =
  # Systolic"); drop the collection prefix so columns read as plain Systolic / Diastolic.
  names(data) <- sub("^Blood Pressure = ", "", names(data))

  tall <- data %>% tidyr::pivot_longer(c(Systolic, Diastolic),
                                       names_to = "measure", values_to = "mmHg")
  fig <- plot_ly(tall, x = ~Department, y = ~mmHg, color = ~measure, type = "box")

  htmlwidgets::saveWidget(fig, tag_result$output_path)   # write output for output_type: html
  return(tag_result)
}
```

Key points:

- **Input:** `tagbio::get_results(tag_data, row_name = "<id collection>")` returns the analysis
  frame — a data.frame with one row per entity, columns named by the protocol's
  `analysis_variables`. **The `row_name` collection must itself be one of the `analysis_variables`**
  (it is consumed as the row names) — include an id data_function in the protocol, or `get_results`
  errors with "Can't find column".
- **`Unique ID` is always there.** The engine **automatically adds a `Unique ID` column** (the
  entity's unique-key combination) to every extract — ad-hoc queries and plugin frames alike — even
  when it isn't in `analysis_variables`. It's the **one guaranteed-unique value per entity**, so
  every row is always identifiable.
- **Column naming:** a categorical collection is its own name (`Department`); a **numeric variable**
  is `"<Collection> = <Variable>"` — the R SDK's `" = "` separator (the **Python SDK uses `": "`**;
  `python.md`). Rename if you want plain columns.
- **Output:** write to **`tag_result$output_path`** (for `output_type: "html"`, a download, etc.)
  and `return(tag_result)`. (The **Python** SDK spells this attribute **`tag_result.path`** — the two
  SDKs differ here as well as on the column separator; watch it when porting between languages.)
- **Libraries:** a plugin runs in the FC's environment; any package it uses (here `plotly`) must be
  in the FC's **container image** via `deploy/build-container.sh` (`governance.md`), or the protocol
  fails at load with "no package called '<X>'". Locally, `if (!require(x)) install.packages(x)`
  works as a convenience.

## R Markdown flavor

An R plugin can also be an **`.Rmd`** file with a `tagbio::tag_report` output block — the engine
knits it to HTML. Same `sdk: "R"` and `output_type: "html"`; `tag_data` is available to a chunk
via `tagbio::get_results()`. Example: `protocols/plugins/plugin_bp.Rmd` (protocol `rmd_bp`).

## Querying a product ad-hoc

To pull data into an R session — for exploration, QC, or a transformer — connect with the SDK
and use a dplyr-style `tbl` → `select` → `collect`:

```r
library(tagbio); library(dplyr)

# LOCALHOST run_server FC (you started it): host_url is localhost, NO auth. A localhost server
# serves ONE product, so tbl(con) takes NO name.
con <- tagConnect(host_url = "http://localhost:8000")
df  <- tbl(con) %>%
         select(Department, `Blood Pressure = Systolic`) %>%
         collect()          # a bare collect() with no select pulls nothing — always select first

# Deployed product (Tag.bio cluster): host_url + credentials, and NAME the product.
con2 <- tagConnect(host_url = Sys.getenv("TAGBIO_BASE_URL"))   # auth via ~/.tagbio.json
df2  <- tbl(con2, "fc-clinic") %>% select(`Encounter ID`, Department) %>% collect()

# The LOCAL build currently being built (inside a transformer): no host_url, no name.
local <- tagConnect()
df_local <- tbl(local) %>% select(everything()) %>% collect()
```

- **`tbl(con)` with NO name** targets the **single product a localhost `run_server` serves** — and,
  with no host_url at all, the **local build in progress** in a transformer (`transformers.md`).
  **`tbl(con, "name")`** is only for a **deployed** cluster that hosts many named products. (Passing
  a name to a localhost server errors.)
- **Cross-SDK difference:** this no-name rule is **R-specific**. The **Python** SDK's `FC()` accepts
  an `fc_name` on localhost too (or omits it) — so don't assume the R form when porting (`python.md`).
  It's the same class of asymmetry as `= ` vs `: ` and `output_path` vs `.path`.
- **Credentials for a deployed FC** come from the env vars **`TAGBIO_HOST_URL`** and
  **`TAGBIO_API_KEY`**, or a **`~/.tagbio.json`** file in your home directory with the same two keys:

  ```json
  { "TAGBIO_HOST_URL": "https://your-cluster-host", "TAGBIO_API_KEY": "<your-api-key>" }
  ```

  Then `tagConnect()` picks them up with no arguments. **Lock the file down — `chmod 600
  ~/.tagbio.json`** (it holds a live key any process could otherwise read), keep it **out of the
  repo**, and rotate/revoke the key if it leaks. Never commit or hardcode the key; localhost needs
  none. (The Python SDK reads the same file — `python.md`.)
- Always `select(...)` the columns you want **before** `collect()`; a bare `collect()` returns
  nothing. To pull **everything**, use `select(everything())`.
- **The SDK's dplyr/dbplyr layer is a PARTIAL shim** (it grew around specific use cases), so don't
  assume the full framework is wired. In particular, on **any localhost FC** — both a `run_server`
  dev serve *and* the build-in-progress self-query — **`colnames(fc)` comes back empty**, so
  `all_of(colnames(fc))`, tidy-eval injection (`!!sym(x)`), and broader verbs are **not** reliable.
  **Select columns by literal name** (backticks for spaces/pipes, e.g.
  `` select(`Encounter ID`) ``) or `everything()`. Enumerating with `colnames(fc)`
  works **only on a deployed product**. Keep to `tbl()` → `select(<literal names>)` → `collect()`.
- **Column naming:** a **categorical** collection is selected by its own name (`` `Department` ``);
  a **numeric variable** is exposed as **`` `Collection = Variable` ``** — e.g.
  `` `Blood Pressure = Systolic` `` — using the SDK's `qdelim` (` = ` by default). Selecting the
  bare variable name (`` `Systolic` ``) will not resolve.

**Three connection targets:** a **localhost** FC you started with `run_server` —
`tagConnect(host_url = "http://localhost:8000")`, **no auth**; a **deployed** FC in the Tag.bio
cluster — `host_url` + **auth** (a named connection / `~/.tagbio.json`); and the **local build in
progress** inside a transformer — `tagConnect()` with no host and `tbl(con)` with no table name.
A runnable localhost example is in `example-clinic-fc/_r/query_clinic.R`.

**Localhost ports aren't limited to 8000.** `run_server … port=7999` serves on any port, and
`tagConnect(host_url = "http://localhost:7999")` connects to it **no-auth** — so you can serve and
query **several localhost FCs at once**: a second FC as a *dependency* (a transformer pulling
another product served locally, `transformers.md`), or two FCs side-by-side for plugin
development. **This is R-only: the Python SDK hardcodes `:8000` for the localhost no-auth path
(confirmed — any other host requires auth and is forced to https), see `python.md`.**

> **Guardrail:** before running an ad-hoc query against any product or source, obtain the user's
> **informed consent** — they must know Claude is about to access potentially sensitive or
> regulated data (see `SKILL.md` → Guardrails).

## Recipe: write an R plugin

1. Create `protocols/plugins/plugin_<name>.R` as `function(tag_data, tag_result) { … }`.
2. Pull the frame with `tagbio::get_results(tag_data, row_name = "<id collection>")`.
3. Produce the output and write it to `tag_result$output_path`; `return(tag_result)`.
4. Ensure every library used is installed in the environment.
5. Reference the plugin from an `external` / `"sdk": "R"` protocol (`protocols.md`).

## Common mistakes

- **A bare `collect()`** with no `select` — pulls no columns.
- **Using a library not in the environment** — the protocol fails to load.
- **Omitting the `row_name` id collection from `analysis_variables`.** The single most common plugin
  error: `get_results(row_name = "Encounter ID")` needs "Encounter ID" among the protocol's
  `analysis_variables`, or it fails with "Can't find column". (The Python `.df` doesn't use a
  `row_name`, so the two languages' `analysis_variables` legitimately differ here.)
- **Wrong `row_name`** — name an id collection that actually exists in the analysis frame.

Next: `python.md` — the same in Python.
