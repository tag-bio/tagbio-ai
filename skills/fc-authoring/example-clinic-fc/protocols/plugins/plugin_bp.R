# Blood Pressure by Department -- a Tag.bio R plugin.
# A plugin is a function(tag_data, tag_result): pull the analysis frame with
# tagbio::get_results(), do the work, write to tag_result$output_path, return tag_result.
if (!require('plotly')) install.packages('plotly', repos = "https://cloud.r-project.org")
require('plotly')
require('dplyr')
require('tidyr')

function(tag_data, tag_result) {

  # One row per entity; columns are the analysis_variables (Encounter ID is used as the row name).
  data <- tagbio::get_results(tag_data, row_name = "Encounter ID")

  # A numeric variable arrives named "<Collection> = <Variable>" (e.g. "Blood Pressure = Systolic");
  # drop the collection prefix so the columns read as plain Systolic / Diastolic.
  names(data) <- sub("^Blood Pressure = ", "", names(data))

  data_tall <- data %>%
    tidyr::pivot_longer(c(Systolic, Diastolic), names_to = "measure", values_to = "mmHg")

  fig <- plot_ly(data_tall, x = ~Department, y = ~mmHg, color = ~measure, type = "box") %>%
    layout(boxmode = "group", yaxis = list(title = "mmHg"))

  htmlwidgets::saveWidget(fig, tag_result$output_path)

  return(tag_result)
}
