# Patients per Condition -- a Tag.bio R plugin that exercises a NON-EXCLUSIVE (multi-value) categorical.
#
# `Conditions` is a `categorical-delimited` collection: each patient may carry several conditions
# (P004 has three; P003 has none). Over the download it is a multi-value column, and the SDK collapses
# it to the CSV form -- the values joined by "; " -- so ordinary string ops behave identically whether
# the transport was CSV or parquet. This plugin is the REGRESSION GUARD for that shape-compatibility:
# `Conditions == ""` on a raw parquet LIST column would error ("Can't combine list<character> and
# character"); it must see a plain string. Keep this test so a future SDK change can't silently
# reintroduce the list shape.
require('plotly')
require('dplyr')
require('tidyr')

function(tag_data, tag_result) {

  data <- tagbio::get_results(tag_data)

  # The exact pattern that broke: compare a multi-value categorical directly to "" and remap empties.
  data <- data %>%
    dplyr::mutate(Conditions = ifelse(Conditions == "", "None recorded", Conditions))

  # Multi-value handling: split the "; "-joined values back into one row per condition and count.
  counts <- data %>%
    tidyr::separate_longer_delim(Conditions, delim = "; ") %>%
    dplyr::filter(Conditions != "None recorded") %>%
    dplyr::count(Conditions, name = "Patients", sort = TRUE)

  fig <- plot_ly(counts, x = ~Conditions, y = ~Patients, type = "bar") %>%
    layout(title = "Patients per Condition", yaxis = list(title = "Patients"))

  htmlwidgets::saveWidget(fig, tag_result$output_path)

  return(tag_result)
}
