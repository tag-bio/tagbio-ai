# MCP — every FC is an MCP server

A running FC answers the [Model Context Protocol](https://modelcontextprotocol.io) at **`/m`**
(JSON-RPC 2.0 over HTTP POST). An AI client such as Claude can list the FC's analyses as tools,
read about the data product, and run analyses, with nothing else to deploy. The FC describes
**only itself**: one FC, its own protocols. Cross-product catalogs, user sign-in and billing belong
to the platform's MCP gateway, which can combine many FCs' tools.

Needs an engine with the MCP endpoint (it arrives with the release after 2.100.6).

## Connect

Point an MCP client at the FC's `/m`. For a local dev FC (any port, including `port=auto`):

```bash
claude mcp add --transport http fc-clinic http://localhost:8000/m
```

## What the client sees

| MCP | From the FC |
|---|---|
| `initialize` | name, title, version, and instructions built from the data product's description, entity count and **license** (from `/s`) |
| `tools/list` | one tool per **visible** protocol, plus `argument_values` |
| `tools/call` | runs the protocol as a protocol instance (exactly as the UI would) |
| `resources/read fc://about` | the data product's details (`/s`) |
| `resources/read fc://protocols` | every protocol with its full argument definitions (`/p`) |
| `resources/read fc://data-model`, tool `data_model` | the data model: what one entity is, every collection (type, values, entities with a value), and any collection's values with counts |
| `prompts/list`, `prompts/get` | the starter questions in your data product definition's `prompts` |

**Tool schemas come from your argument sets.** Each argument becomes a typed input:

| Argument type | Tool input |
|---|---|
| `static-radio` / `static-categorical` with `options` | an enum (one value / a list) |
| `categorical-radio(-filter)`, `categorical-input` | a string |
| `categorical-checkbox(-filter)`, `categorical-paste` | a list of strings |
| `numeric-range` | `{minimum, maximum}` (either or both) |
| `timestamp-range`, or a `numeric-range` over a date variable | `{minimum, maximum}` as dates (`YYYY-MM-DD`; the maximum includes its whole day) |
| `cohort` | an object of the cohort builder's filters: entities matching **every** filter given, **any** of a filter's values |
| `boolean` | true / false |
| hidden arguments | not exposed |

Arguments in a `mandatory` argument set are required. **`argument_values`** lists the valid
values of any filter argument (with entity counts), or a numeric range's spread, by running that
argument's own `argument_protocol`, the same call that fills the UI's picker.

**Results** start with the values the tool ran with. Reports (R/Python plugins) come back as markdown
(headings, tables, lists) plus their plots as images;
statistical results (comparison, summary) as one line per finding with the protocol's own
descriptor sentences; entity results as JSON.

## Writing protocols that make good tools

The tool a model sees is only as good as what you wrote:

- **`title` and `description` on the protocol** become the tool's name and description. Say what
  question it answers and what comes back.
- **`description` on each argument set** becomes the inputs' guidance. Say what the input means and
  what leaving it blank does ("Optional. Blank means every show since the song's debut.").
- **`"visible": false`** protocols are not tools. Hide helper and callback protocols; keep the
  ones a person (or model) should run visible.
- **Fixed choices as `static-*` with `options`** give the model an exact enum instead of guessing.
- **`default_value` on an argument** becomes the input's `default`, so the model knows what leaving it
  out means without reading prose.
- **Filters with an `argument_protocol`** let the model look up valid values instead of inventing them.
- **Add `prompts` to `data_product_definition`** (in `main.json`/the manifest): the questions this
  data product answers well. Clients offer them as starters. A string is the question; an object
  can add `name`, `title` and `description` (`text` is required):

  ```json
  "prompts": [
    "Which diagnoses are most common among patients over 65?",
    {
      "name": "encounter_trends",
      "title": "Encounter trends",
      "description": "Encounters per month, by type.",
      "text": "How have encounter counts changed month to month, by encounter type?"
    }
  ]
  ```
