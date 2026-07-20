# Lab Results by Panel -- a Tag.bio Python plugin.
# The Python twin of plugin_lab_results.R: consumes the whole numeric Labs collection_set at once.
# Each lab collection arrives as a column "<Collection>: <Variable>" (e.g. "Lipid: LDL" -- the
# Python SDK uses ": ", the R SDK uses " = "). Reshape to one row per (panel, analyte, value)
# and box-plot the distributions by analyte.
from tagbiopy.protocol import TagbioData, TagbioResult
import plotly.express as px


def lab_results_report(tag_data: TagbioData, tag_result: TagbioResult):
    df = tag_data.df

    # The lab columns are the numeric ones named "Panel: Analyte"; melt them to tall, drop the
    # encounters missing a given lab, then split the name back into its Panel and Analyte parts.
    lab_cols = [c for c in df.columns if ": " in c]
    tall = df.melt(value_vars=lab_cols, var_name="panel_analyte", value_name="result").dropna(
        subset=["result"]
    )
    tall[["Panel", "Analyte"]] = tall["panel_analyte"].str.split(": ", n=1, expand=True)

    fig = px.box(tall, x="Analyte", y="result", color="Panel")
    fig.update_layout(boxmode="group", yaxis_title="Result")
    fig.write_html(tag_result.path)
    return tag_result
