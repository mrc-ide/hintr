do_plotting_metadata <- function(iso3) {
  metadata <- get_plotting_metadata(iso3)
  metadata <- metadata[metadata$data_type %in%
                         c("survey", "anc", "output", "programme"), ]
  metadata <- metadata[order(metadata$indicator_sort_order), ]
  lapply(split(metadata, metadata$data_type), build_data_type_metadata)
}

get_plotting_metadata <- function(...) {
  naomi::get_plotting_metadata(...)
}

build_data_type_metadata <- function(metadata) {
  lapply(split(metadata, metadata$plot_type), build_plot_type_metadata)
}

build_plot_type_metadata <- function(metadata) {
  list(indicators =
         lapply(metadata$indicator, function(indicator) {
           build_indicator_metadata(metadata[metadata$indicator == indicator, ])
           }))
}

build_indicator_metadata <- function(metadata) {
  if (nrow(metadata) != 1) {
    stop(t_("METADATA_BUILD_INDICATOR"))
  }
  list(
    indicator = scalar(metadata$indicator),
    value_column = scalar(metadata$value_column),
    indicator_column = scalar(metadata$indicator_column),
    indicator_value = scalar(metadata$indicator_value),
    name = scalar(metadata$name),
    min = scalar(metadata$min),
    max = scalar(metadata$max),
    colour = scalar(metadata$colour),
    invert_scale = scalar(metadata$invert_scale),
    scale = scalar(metadata$scale),
    accuracy = if (is.na(metadata$accuracy)) {
      json_null()
    } else {
      scalar(metadata$accuracy)
    },
    format = scalar(metadata$format)
  )
}

get_barchart_metadata <- function(output, data_type = "output") {
  metadata <- naomi::get_metadata()
  metadata <- metadata[
    metadata$data_type == data_type & metadata$plot_type == "barchart",
    c("indicator", "value_column", "error_low_column", "error_high_column",
      "indicator_column", "indicator_value", "indicator_sort_order",
      "name", "scale", "accuracy", "format")]
  metadata[order(metadata$indicator_sort_order), ]
}

get_choropleth_metadata <- function(output) {
  iso3 <- get_country_iso3(output$area_id)
  metadata <- get_plotting_metadata(iso3)
  metadata <- metadata[
    metadata$data_type == "output" & metadata$plot_type == "choropleth",
    c("indicator", "value_column", "error_low_column", "error_high_column",
      "indicator_column", "indicator_value", "indicator_sort_order",
      "name", "min", "max", "colour",
      "invert_scale", "scale", "accuracy", "format")]
  metadata[order(metadata$indicator_sort_order), ]
}


get_country_iso3 <- function(area_ids) {
  sub("([A-Z]{3}).*", "\\1", area_ids[1])
}
