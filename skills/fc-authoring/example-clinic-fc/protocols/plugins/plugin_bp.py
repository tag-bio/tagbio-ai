# Blood Pressure report -- a Tag.bio Python plugin.
# A plugin receives TagbioData (tag_data.df is a pandas DataFrame of the analysis frame:
# one row per entity, columns = the analysis_variables) and writes to TagbioResult.
from tagbiopy.protocol import TagbioData, TagbioResult
import plotly.express as px


def blood_pressure_report(tag_data: TagbioData, tag_result: TagbioResult):
    # A numeric variable arrives named "<Collection>: <Variable>" (e.g. "Blood Pressure:
    # Systolic" — the Python SDK uses ": "; the R SDK uses " = "). Drop the collection prefix so
    # the columns read as plain Systolic / Diastolic.
    df = tag_data.df.rename(columns=lambda c: c.replace("Blood Pressure: ", ""))
    tall = df.melt(
        id_vars=["Department"],
        value_vars=["Systolic", "Diastolic"],
        var_name="measure",
        value_name="mmHg",
    )
    fig = px.box(tall, x="Department", y="mmHg", color="measure")
    fig.write_html(tag_result.path)
    return tag_result
