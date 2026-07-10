# Lab Results by Panel -- a Tag.bio R plugin.
# Demonstrates consuming a whole collection_set: the analysis frame's columns are every numeric
# lab collection at once (Lipid, Metabolic, ...), each arriving as "<Collection> = <Variable>"
# (e.g. "Lipid = LDL"). We reshape to one row per (panel, analyte, value) and box-plot by analyte.
if (!require('plotly')) install.packages('plotly', repos = "http://cran.us.r-project.org")
require('plotly')
require('dplyr')
require('tidyr')

function(tag_data, tag_result) {

  # One row per entity; columns are the numeric lab variables pulled in by the Labs collection_set.
  data <- tagbio::get_results(tag_data, row_name = "Encounter ID")

  # Column names are "Panel = Analyte"; pivot to tall, drop encounters missing a given lab, then
  # split the name back into its Panel and Analyte parts.
  tall <- data %>%
    tidyr::pivot_longer(dplyr::contains(" = "), names_to = "panel_analyte", values_to = "result") %>%
    dplyr::filter(!is.na(result)) %>%
    tidyr::separate(panel_analyte, into = c("Panel", "Analyte"), sep = " = ")

  fig <- plot_ly(tall, x = ~Analyte, y = ~result, color = ~Panel, type = "box") %>%
    layout(boxmode = "group", yaxis = list(title = "Result"))

  htmlwidgets::saveWidget(fig, tag_result$output_path)

  return(tag_result)
}
