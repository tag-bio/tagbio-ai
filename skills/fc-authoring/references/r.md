# R with an FC — plugins and ad-hoc queries

R is used with an FC in two ways: **authoring a plugin** (the code an `external` protocol runs)
and **querying a product ad-hoc** (pulling data into an R session for exploration). Python is the
same story in `python.md`.

> The R SDK is the **`tagbio`** package — <https://github.com/tag-bio/tagbio> — installed into the
> FC environment (used by both plugins and ad-hoc scripts).

## Authoring an R plugin

An `external` protocol with `"sdk": "R"` invokes an R plugin file (`protocols/plugins/*.R`). A
plugin is a **function of `(tag_data, tag_result)`**:

```r
# protocols/plugins/plugin_bp.R
if (!require('plotly')) install.packages('plotly', repos = "http://cran.us.r-project.org")
require('plotly'); require('dplyr'); require('tidyr')

function(tag_data, tag_result) {
  # The analysis frame: one row per entity; columns are the protocol's analysis_variables
  # plus the row_name id collection.
  data <- tagbio::get_results(tag_data, row_name = "Encounter ID")

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
  `analysis_variables`, keyed by the id collection you name.
- **Output:** write to `tag_result$output_path` (for `output_type: "html"`, a download, etc.)
  and `return(tag_result)`.
- **Libraries:** a plugin runs in the FC's build/serve environment. Any package it uses must be
  available there — declare/install it (the `if (!require(...)) install.packages(...)` idiom, or
  the FC's container setup). A missing package fails the protocol at load time.

## R Markdown flavor

An R plugin can also be an **`.Rmd`** file with a `tagbio::tag_report` output block — the engine
knits it to HTML. Same `sdk: "R"` and `output_type: "html"`; `tag_data` is available to a chunk
via `tagbio::get_results()`. Example: `protocols/plugins/plugin_bp.Rmd` (protocol `rmd_bp`).

## Querying a product ad-hoc

To pull data into an R session — for exploration, QC, or a transformer — connect with the SDK
and use a dplyr-style `tbl` → `select` → `collect`:

```r
library(tagbio); library(dplyr)

# Deployed product: host_url + credentials (e.g. ~/.tagbio.json)
con <- tagConnect(host_url = Sys.getenv("TAGBIO_BASE_URL"))
df  <- tbl(con, "fc-clinic") %>%
         select(`Encounter ID`, Department, Systolic) %>%
         collect()          # a bare collect() with no select pulls nothing — always select first

# The LOCAL build currently being built (inside a transformer): no host_url, no table name
local <- tagConnect()
df_local <- tbl(local) %>% select(everything()) %>% collect()
```

- `tbl(con, "name")` targets a **deployed** named product; `tbl(con)` (no name) self-queries the
  **local** build in progress (`transformers.md`).
- Always `select(...)` the columns you want **before** `collect()`; a bare `collect()` returns
  nothing.

**Three connection targets:** a **localhost** FC you started with `run_server` —
`tagConnect(host_url = "http://localhost:8000")`, **no auth**; a **deployed** FC in the Tag.bio
cluster — `host_url` + **auth** (a named connection / `~/.tagbio.json`); and the **local build in
progress** inside a transformer — `tagConnect()` with no host and `tbl(con)` with no table name.
A runnable localhost example is in `example-clinic-fc/_r/query_clinic.R`.

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
- **Wrong `row_name`** — name an id collection that exists in the analysis frame.

Next: `python.md` — the same in Python.
