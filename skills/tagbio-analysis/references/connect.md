# Connecting and authenticating

## Three connection targets

Which one you're talking to changes the auth rules and the API:

| Target | Host | Auth | Name the product? |
|---|---|---|---|
| **Deployed product** (the cluster) | `TAGBIO_BASE_URL`, or an external `https://…` host | **Yes** — API key | **Yes** — `"fc-<name>"` |
| **Local `run_server`** you started | `http://localhost:8000` | **No** | R: **no name**. Python: optional |
| **The build in progress** (inside a transformer) | `http://localhost:8000` | No | No |

The middle row is `local-fc.md`; the last belongs to `fc-authoring`.

## Credentials

`~/.tagbio.json` holds the key, and optionally the host:

```json
{ "TAGBIO_HOST_URL": "https://your-host", "TAGBIO_API_KEY": "email:uuid" }
```

- **Resolution order** (current SDKs): explicit argument → `~/.tagbio.json` → environment
  variable. **The file beats the env, per key.** Host is read from `TAGBIO_HOST_URL` or
  `TAGBIO_BASE_URL`.
- **In the notebook** the host is already in `TAGBIO_BASE_URL`, so the file needs only the key.
  **Off-cluster** put the external HTTPS host in the file too.
- **Hygiene:** no trailing slash on the host; `chmod 600 ~/.tagbio.json`; never commit or hardcode
  the key; rotate it if it leaks. Generate one in the front-end (account settings → API key) — the
  key alone authenticates, no browser session needed.
- The key's format is `email:uuid` and it is used as HTTP basic auth `username:password`.

> **Older SDKs read env-vs-file in opposite orders** (R env-first, Python file-first). If R and
> Python disagree about which server they reached, that's why — pass the host explicitly to settle it.

## Python

**Current SDK (tagbiopy ≥ 1.0.3), in the notebook** — everything resolves itself:

```python
import tagbiopy.fc

fc = tagbiopy.fc.FC(fc_name="fc-<name>")   # host from TAGBIO_BASE_URL, key from ~/.tagbio.json
fc.summary                                  # a PROPERTY — no parentheses
```

**Older SDK (0.9.x)** — bare `FC()` misroutes, and the SDK force-upgrades `http://` to `https://`,
which breaks against an http-only internal host (`SSL: WRONG_VERSION_NUMBER`). Patch the scheme
**before importing `FC`**, and pass host and key explicitly:

```python
import json, os
import tagbiopy.request as req
req.SCHEME = "http"                 # defeat the http->https coercion; MUST precede the FC import
from tagbiopy.fc import FC

HOST = os.environ["TAGBIO_BASE_URL"]
API_KEY = json.load(open(os.path.expanduser("~/.tagbio.json")))["TAGBIO_API_KEY"]

fc = FC(fc_name="fc-<name>", host=HOST, api_key=API_KEY)
fc.analysis_variables = []          # 0.9.x quirk: defaults to None; .select() raises AttributeError
```

Only patch `SCHEME` for an **http-only internal** host. Never do it for an external endpoint —
you'd be sending a live API key in cleartext.

## R

```r
library(tagbio); library(dplyr)

con <- tagConnect()                        # host from TAGBIO_BASE_URL / ~/.tagbio.json; key from the file
fc  <- tbl(con, "fc-<name>")               # NAME the product on a deployed cluster
summary(fc)                                 # a METHOD in R — with parentheses
```

`tagConnect()` reads `~/.tagbio.json` for both URL and key. For a localhost server, pass the host
and **omit the name**: `tagConnect(host_url = "http://localhost:8000")` then `tbl(con)`.

## Cross-SDK asymmetries — the ones that bite

Same platform, two SDKs, four gratuitous differences. Check this table when porting.

| Concern | R (`tagbio`) | Python (`tagbiopy`) |
|---|---|---|
| Describe collections | `summary(fc)` — a **method** | `fc.summary` — a **property** |
| Numeric column name | `Collection = Variable` | `Collection: Variable` |
| Product name on localhost | `tbl(con)` takes **no name** (errors if given) | `fc_name` optional |
| Plugin output path | `tag_result$output_path` | `tag_result.path` |
| Server-side filter | `filter(...)` (dplyr NSE) | `.where((...))` (tuple DSL) |

## Inside a plugin, connection comes only from the engine

If you are writing an FC **plugin** (not ad-hoc analysis), the plugin runner sets a
`TAGBIO_PLUGIN_CONTEXT` sentinel and the SDK **deliberately ignores `~/.tagbio.json` and the
ambient env** — a developer's key must never ride along into a plugin (privilege escalation, or
dialing the wrong server). The plugin's own-FC callback uses localhost; a call to another deployed
product carries the **invoking user's** token. To test such a plugin locally, set
`TAGBIO_PLUGIN_ALLOW_CONFIG=1` for that run. Details in `fc-authoring`.

## Verify the connection without pulling data

`summary` / `colnames` return **metadata only** — no entity rows — so they are the safe first call
and don't trip the consent guardrail the way a real pull does.
