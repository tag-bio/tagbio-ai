# Analysis patterns

Mechanics get you a dataframe. These patterns are what keeps the analysis honest.

## Collapse to your unit of analysis, then join

**The single most valuable recipe when combining a fine-grained product with a coarse one.**

Given a longitudinal/event product (many rows per subject) and a baseline product (one row per
subject), the wrong move is to join first — you fan the baseline row out across every event and every
downstream test becomes weighted by follow-up length.

**Do it in this order:**

1. **Collapse the event log to one outcome-row-per-subject first** — deltas (last − first), event
   counts, a first-occurrence date, a boolean "ever happened" flag, follow-up duration.
2. **Then merge 1:1 onto the baseline table** on the shared key.
3. **Assert the join didn't fan out**: row count unchanged, key unique on both sides.

```python
# 1. collapse
per_subject = (events.sort_values("date")
                     .groupby(KEY)
                     .agg(first_score=("score", "first"),
                          last_score =("score", "last"),
                          n_visits   =("score", "size"))
                     .assign(delta=lambda d: d.last_score - d.first_score)
                     .reset_index())

# 2. merge, 3. verify
assert per_subject[KEY].is_unique and baseline[KEY].is_unique
fused = baseline.merge(per_subject, on=KEY, how="inner", validate="one_to_one")
```

Sibling products in a family share a **compound key** — often something like
`<SubjectID> | <Laterality>` for a per-side grain, or a plain enrollment/participant ID at subject
grain. **Discover the exact key name in each product** (`discover.md`); it is not always spelled
identically across siblings. Report the **match rate** (how many keys found a partner) — a low rate
means you picked the wrong key or the wrong grain.

## The outcome-definition lesson

Worth internalizing, because it produces the most misleading results:

**The same predictor can look null against one endpoint and strongly predictive against another.** A
risk score can be flat against a **cross-sectional label** (a stage recorded at enrollment) while
showing a clean monotonic gradient against a **well-defined longitudinal endpoint** (an event that
demonstrably happened during follow-up). Neither result is a bug — the endpoint quality and the
follow-up window drive the signal.

So, before believing any association:

- **Is the endpoint cross-sectional or incident?** Prevalent-at-baseline labels conflate "who got
  sick" with "who survived to be enrolled."
- **Is follow-up adequate and comparable across groups?** Differential follow-up alone creates
  gradients.
- **Was the cohort selected on something related to the outcome?** A score trained on
  case/control data behaves differently inside an all-cases cohort — index-event bias.
- **Would the effect survive a different, equally reasonable endpoint?** Test two and report both.

Report the endpoint definition alongside every effect size. A p-value without its endpoint
definition is not interpretable.

## Longitudinal work

- **Parse the string date, not the epoch number,** when the product offers both — the numeric
  timestamp is often dirtier. **Clip implausible dates** (year 1900, year 3025 sentinels) to a
  sensible window and report how many you dropped.
- **Sort by subject, then date, before any `first`/`last`/`diff`.** A groupby on unsorted data gives
  arbitrary "first" values.
- **Require a minimum trajectory** for slope/change analyses — e.g. ≥3 observations spanning ≥1
  year — and state the requirement. Two-point slopes on short intervals are mostly noise.
- **Filter to the record type first** (`data-model.md`): heterogeneous event rows mean the naive
  denominator is wrong.
- **Distinguish "no event" from "no follow-up."** A subject with one visit hasn't avoided the
  outcome; they're uninformative for it.

## Reporting

- **Counts and denominators, always.** "23% converted" is meaningless without n and the denominator
  rule (entities with a value, not all entities).
- **State the grain** in every table caption: "per eye", "per visit", "per participant".
- **Under the guardrails, report structure not rows** — shapes, dtypes, null counts, group counts,
  effect sizes. Never paste record-level output.
- **Note the data version** so a rerun is comparable.

## Charts

If the **`dataviz`** skill is available in your environment, load it before writing chart code — it
carries a validated palette and figure style, so figures stay consistent across notebooks. If it
isn't, the brand-neutral categorical palette and neutral set below are a validated, accessible
default — **swap in your organization's brand colors** if it has them:

```python
PAL = ["#2a78d6","#eb6834","#1baf7a","#eda100","#e87ba4","#008300","#4a3aa7","#e34948"]
INK, MUTED, SURFACE, GRID = "#0b0b0b", "#52514e", "#fcfcfb", "#e6e6e2"
```

Chart hygiene that matters for this data: plot **distributions, not just means** (clinical measures
are skewed and censored); show **n per group** on or beside the chart; and don't draw a trend line
through a group whose trajectory minimum you didn't enforce.

### Sentinel values will destroy an axis — trim by IQR fence, and report it

Real-world columns carry physically impossible sentinels — a pressure of ~1e6, an age of 999, a lab
value of `-9999`: a unit error or a magic number. Left in, the real distribution collapses into a
single bin and the chart is worthless.

A fixed small percentile (0.5%/99.5%) **does not** reliably fix this — if the sentinels are more
numerous than the trim fraction they survive it. Use a **Tukey fence**, which is scale-free:

```python
q1, q3 = v.quantile(.25), v.quantile(.75); iqr = q3 - q1
lo, hi = q1 - 3*iqr, q3 + 3*iqr
inliers = v[(v >= lo) & (v <= hi)]
```

**Then guard it.** If the fence would hide more than ~5% of values, trim **nothing** — that much
mass is real structure, not error. Severity measures routinely have a genuine severely-affected
cluster far below (or above) the main mode, and quietly cropping it to tidy an axis misrepresents
the cohort.

Either way, **state the count excluded and the true max in the caption.** A trimmed axis with no
note is indistinguishable from clean data.

### Don't truncate category labels that differ only in their tail

Staging and diagnosis vocabularies are often long and share a prefix — `Chronic Kidney Disease,
Stage 3a, with Proteinuria`, `…, Stage 3b, …`, `…, Stage 4, …`. A 24-character truncation renders
three distinct stages **identically**, which silently invites a wrong reading of the chart. Wrap
onto two lines instead, or widen the panel.

## Notebooks

- Execute end-to-end before claiming a notebook works:
  `jupyter nbconvert --to notebook --execute --inplace <nb>.ipynb`, then confirm **0 error outputs**.
- **Clear outputs before committing** — saved output cells embed the data.
- Keep the expensive pull in one cached cell (`query.md`) so re-running the analysis doesn't re-pull.
