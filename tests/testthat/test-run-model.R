context("run-model")

test_that("model can be run and filters extracted", {
  test_mock_model_available()
  model_run <- process_result(mock_model)
  expect_equal(names(model_run),
               c("data", "plottingMetadata", "uploadMetadata"))
  expect_equal(names(model_run$data),
               c("area_id", "sex", "age_group", "calendar_quarter",
                 "indicator", "mode", "mean", "lower", "upper"))
  expect_true(nrow(model_run$data) > 84042)
  expect_equal(names(model_run$plottingMetadata), c("barchart", "choropleth"))
  barchart <- model_run$plottingMetadata$barchart
  expect_equal(names(barchart), c("indicators", "filters", "defaults"))
  expect_length(barchart$filters, 4)
  expect_equal(names(barchart$filters[[1]]),
               c("id", "column_id", "label", "options", "use_shape_regions"))
  expect_equal(names(barchart$filters[[2]]),
               c("id", "column_id", "label", "options"))
  expect_equal(barchart$filters[[1]]$id, scalar("area"))
  expect_equal(barchart$filters[[2]]$id, scalar("quarter"))
  expect_equal(barchart$filters[[3]]$id, scalar("sex"))
  expect_equal(barchart$filters[[4]]$id, scalar("age"))
  expect_true(length(barchart$filters[[4]]$options) >= 29)
  expect_length(barchart$filters[[2]]$options, 3)
  expect_equal(barchart$filters[[2]]$options[[2]]$id, scalar("CY2018Q3"))
  expect_equal(barchart$filters[[2]]$options[[2]]$label, scalar("September 2018"))
  expect_equal(nrow(barchart$indicators), 21)
  expect_true(all(c("population", "prevalence", "plhiv", "art_coverage",
                    "art_current_residents", "art_current",
                    "untreated_plhiv_num", "aware_plhiv_prop",
                    "unaware_plhiv_num", "aware_plhiv_num", "incidence",
                    "infections", "anc_prevalence", "anc_art_coverage",
                    "anc_clients", "anc_plhiv", "anc_already_art",
                    "anc_art_new", "anc_known_pos",
                    "anc_tested_pos", "anc_tested_neg") %in%
                    barchart$indicators$indicator))

  choropleth <- model_run$plottingMetadata$choropleth
  expect_equal(names(choropleth), c("indicators", "filters"))
  expect_length(choropleth$filters, 4)
  expect_equal(names(choropleth$filters[[1]]),
               c("id", "column_id", "label", "options", "use_shape_regions"))
  expect_equal(names(choropleth$filters[[2]]),
               c("id", "column_id", "label", "options"))
  expect_equal(choropleth$filters[[1]]$id, scalar("area"))
  expect_equal(choropleth$filters[[2]]$id, scalar("quarter"))
  expect_equal(choropleth$filters[[3]]$id, scalar("sex"))
  expect_equal(choropleth$filters[[4]]$id, scalar("age"))
  expect_true(length(choropleth$filters[[4]]$options) >= 29)
  expect_length(choropleth$filters[[2]]$options, 3)
  expect_equal(choropleth$filters[[2]]$options[[2]]$id, scalar("CY2018Q3"))
  expect_equal(choropleth$filters[[2]]$options[[2]]$label,
               scalar("September 2018"))
  expect_equal(nrow(choropleth$indicators), 21)
  expect_true(all(!is.null(choropleth$indicators$error_low_column)))
  expect_true(all(!is.null(choropleth$indicators$error_high_column)))
  expect_true(all(c("population", "prevalence", "plhiv", "art_coverage",
                  "art_current_residents", "art_current",
                  "untreated_plhiv_num", "aware_plhiv_prop",
                  "unaware_plhiv_num", "aware_plhiv_num", "incidence",
                  "infections", "anc_prevalence", "anc_art_coverage",
                  "anc_clients", "anc_plhiv", "anc_already_art",
                  "anc_art_new", "anc_known_pos",
                  "anc_tested_pos", "anc_tested_neg") %in%
                  choropleth$indicators$indicator))

  upload_metadata <- model_run$uploadMetadata
  expect_s3_class(upload_metadata$outputSummary$description,
                  c("scalar", "character"))
  expect_length(upload_metadata$outputSummary$description, 1)
  expect_s3_class(upload_metadata$outputZip$description,
                  c("scalar", "character"))
  expect_length(upload_metadata$outputZip$description, 1)
})

test_that("model without national level results can be processed", {
  test_mock_model_available()
  output <- readRDS(mock_model$output_path)
  output <- output[output$area_level != 0, ]
  output_temp <- tempfile()
  saveRDS(output, output_temp)
  model_run <- process_result(list(output_path = output_temp))
  expect_equal(names(model_run),
               c("data", "plottingMetadata", "uploadMetadata"))
  expect_equal(names(model_run$data),
               c("area_id", "sex", "age_group", "calendar_quarter",
                 "indicator", "mode", "mean", "lower", "upper"))
  expect_true(nrow(model_run$data) > 84042)
  expect_equivalent(as.data.frame(model_run$data)[1, "area_id"], "MWI_1_1_demo")
  expect_equal(names(model_run$plottingMetadata), c("barchart", "choropleth"))
  barchart <- model_run$plottingMetadata$barchart
  expect_equal(names(barchart), c("indicators", "filters", "defaults"))
  expect_length(barchart$filters, 4)
  expect_equal(names(barchart$filters[[1]]),
               c("id", "column_id", "label", "options", "use_shape_regions"))
  expect_equal(names(barchart$filters[[2]]),
               c("id", "column_id", "label", "options"))
  expect_equal(barchart$filters[[1]]$id, scalar("area"))
  expect_equal(barchart$filters[[2]]$id, scalar("quarter"))
  expect_equal(barchart$filters[[3]]$id, scalar("sex"))
  expect_equal(barchart$filters[[4]]$id, scalar("age"))
  expect_true(length(barchart$filters[[4]]$options) >= 29)
  expect_length(barchart$filters[[2]]$options, 3)
  expect_equal(barchart$filters[[2]]$options[[2]]$id, scalar("CY2018Q3"))
  expect_equal(barchart$filters[[2]]$options[[2]]$label, scalar("September 2018"))
  expect_equal(nrow(barchart$indicators), 21)
  expect_true(all(c("population", "prevalence", "plhiv", "art_coverage",
                    "art_current_residents", "art_current",
                    "untreated_plhiv_num", "aware_plhiv_prop",
                    "unaware_plhiv_num", "aware_plhiv_num", "incidence",
                    "infections", "anc_prevalence", "anc_art_coverage",
                    "anc_clients", "anc_plhiv", "anc_already_art",
                    "anc_art_new", "anc_known_pos",
                    "anc_tested_pos", "anc_tested_neg") %in%
                    barchart$indicators$indicator))

  choropleth <- model_run$plottingMetadata$choropleth
  expect_equal(names(choropleth), c("indicators", "filters"))
  expect_length(choropleth$filters, 4)
  expect_equal(names(choropleth$filters[[1]]),
               c("id", "column_id", "label", "options", "use_shape_regions"))
  expect_equal(names(choropleth$filters[[2]]),
               c("id", "column_id", "label", "options"))
  expect_equal(choropleth$filters[[1]]$id, scalar("area"))
  expect_equal(choropleth$filters[[2]]$id, scalar("quarter"))
  expect_equal(choropleth$filters[[3]]$id, scalar("sex"))
  expect_equal(choropleth$filters[[4]]$id, scalar("age"))
  expect_true(length(choropleth$filters[[4]]$options) >= 29)
  expect_length(choropleth$filters[[2]]$options, 3)
  expect_equal(choropleth$filters[[2]]$options[[2]]$id, scalar("CY2018Q3"))
  expect_equal(choropleth$filters[[2]]$options[[2]]$label,
               scalar("September 2018"))
  expect_equal(nrow(choropleth$indicators), 21)
  expect_true(all(c("population", "prevalence", "plhiv", "art_coverage",
                    "art_current_residents", "art_current",
                    "untreated_plhiv_num", "aware_plhiv_prop",
                    "unaware_plhiv_num", "aware_plhiv_num", "incidence",
                    "infections", "anc_prevalence", "anc_art_coverage",
                    "anc_clients", "anc_plhiv", "anc_already_art",
                    "anc_art_new", "anc_known_pos",
                    "anc_tested_pos", "anc_tested_neg") %in%
                    choropleth$indicators$indicator))

})

test_that("real model can be run", {
  data <- list(
    pjnz = file.path("testdata", "Malawi2019.PJNZ"),
    shape = file.path("testdata", "malawi.geojson"),
    population = file.path("testdata", "population.csv"),
    survey = file.path("testdata", "survey.csv"),
    programme = file.path("testdata", "programme.csv"),
    anc = file.path("testdata", "anc.csv")
  )
  options <- list(
    area_scope = "MWI",
    area_level = 4,
    calendar_quarter_t1 = "CY2016Q1",
    calendar_quarter_t2 = "CY2018Q3",
    calendar_quarter_t3 = "CY2019Q2",
    survey_prevalence = c("DEMO2016PHIA", "DEMO2015DHS"),
    survey_art_coverage = "DEMO2016PHIA",
    survey_recently_infected = "DEMO2016PHIA",
    include_art_t1 = "true",
    include_art_t2 = "true",
    anc_clients_year2 = 2018,
    anc_clients_year2_num_months = "9",
    anc_prevalence_year1 = 2016,
    anc_prevalence_year2 = 2018,
    anc_art_coverage_year1 = 2016,
    anc_art_coverage_year2 = 2018,
    spectrum_population_calibration = "none",
    spectrum_plhiv_calibration_level = "none",
    spectrum_plhiv_calibration_strat = "sex_age_group",
    spectrum_artnum_calibration_level = "none",
    spectrum_artnum_calibration_strat = "age_coarse",
    spectrum_infections_calibration_level = "none",
    spectrum_infections_calibration_strat = "age_coarse",
    calibrate_method = "logistic",
    artattend_log_gamma_offset = -4L,
    artattend = "false",
    output_aware_plhiv = "true",
    rng_seed = 17,
    no_of_samples = 20,
    max_iter = 250,
    permissive = "false"
  )
  withr::with_envvar(c("USE_MOCK_MODEL" = "false"), {
    model_run <- run_model(data, options, tempdir())
  })
  expect_equal(names(model_run), c("output_path", "spectrum_path",
                                   "coarse_output_path", "summary_report_path",
                                   "calibration_path", "metadata"))

  output <- readRDS(model_run$output_path)
  expect_equal(colnames(output),
               c("area_level", "area_level_label", "area_id", "area_name",
                 "sex", "age_group", "age_group_label",
                 "calendar_quarter", "quarter_label", "indicator",
                 "indicator_label", "mean",
                 "se", "median", "mode", "lower", "upper"))
  expect_true(nrow(output) > 84042)

  file_list <- unzip(model_run$spectrum_path, list = TRUE)
  expect_true(all(c("boundaries.geojson", "indicators.csv", "meta_age_group.csv",
                    "meta_area.csv", "meta_indicator.csv", "meta_period.csv")
                  %in% file_list$Name))

  file_list <- unzip(model_run$coarse_output_path, list = TRUE)
  expect_true(all(c("boundaries.geojson", "indicators.csv", "meta_age_group.csv",
                    "meta_area.csv", "meta_indicator.csv", "meta_period.csv")
                  %in% file_list$Name))

  expect_true(file.size(model_run$summary_report_path) > 2000)
})

test_that("real model can be run with csv2 data", {
  testthat::skip_on_covr() # slow so don't run over again
  convert_csv <- function(path) {
    dest <- tempfile(fileext = ".csv")
    write.csv2(read_csv(path), dest, row.names = FALSE)
    dest
  }
  data <- list(
    pjnz = file.path("testdata", "Malawi2019.PJNZ"),
    shape = file.path("testdata", "malawi.geojson"),
    population = convert_csv(file.path("testdata", "population.csv")),
    survey = convert_csv(file.path("testdata", "survey.csv")),
    programme = convert_csv(file.path("testdata", "programme.csv")),
    anc = convert_csv(file.path("testdata", "anc.csv"))
  )
  options <- list(
    area_scope = "MWI",
    area_level = 4,
    calendar_quarter_t1 = "CY2016Q1",
    calendar_quarter_t2 = "CY2018Q3",
    calendar_quarter_t3 = "CY2019Q2",
    survey_prevalence = c("DEMO2016PHIA", "DEMO2015DHS"),
    survey_art_coverage = "DEMO2016PHIA",
    survey_recently_infected = "DEMO2016PHIA",
    include_art_t1 = "true",
    include_art_t2 = "true",
    anc_clients_year2 = 2018,
    anc_clients_year2_num_months = "9",
    anc_prevalence_year1 = 2016,
    anc_prevalence_year2 = 2018,
    anc_art_coverage_year1 = 2016,
    anc_art_coverage_year2 = 2018,
    spectrum_population_calibration = "none",
    spectrum_plhiv_calibration_level = "none",
    spectrum_plhiv_calibration_strat = "sex_age_group",
    spectrum_artnum_calibration_level = "none",
    spectrum_artnum_calibration_strat = "age_coarse",
    spectrum_infections_calibration_level = "none",
    spectrum_infections_calibration_strat = "age_coarse",
    calibrate_method = "logistic",
    artattend_log_gamma_offset = -4L,
    artattend = "false",
    output_aware_plhiv = "true",
    rng_seed = 17,
    no_of_samples = 20,
    max_iter = 250,
    permissive = "false"
  )
  withr::with_envvar(c("USE_MOCK_MODEL" = "false"), {
    model_run <- run_model(data, options, tempdir())
  })

  expect_equal(names(model_run), c("output_path", "spectrum_path",
                                   "coarse_output_path", "summary_report_path",
                                   "calibration_path", "metadata"))

  output <- readRDS(model_run$output_path)
  expect_equal(colnames(output),
               c("area_level", "area_level_label", "area_id", "area_name",
                 "sex", "age_group", "age_group_label",
                 "calendar_quarter", "quarter_label", "indicator",
                 "indicator_label", "mean",
                 "se", "median", "mode", "lower", "upper"))
  expect_true(nrow(output) > 84042)

  file_list <- unzip(model_run$spectrum_path, list = TRUE)
  expect_true(all(c("boundaries.geojson", "indicators.csv", "meta_age_group.csv",
                    "meta_area.csv", "meta_indicator.csv", "meta_period.csv")
                  %in% file_list$Name))

  file_list <- unzip(model_run$coarse_output_path, list = TRUE)
  expect_true(all(c("boundaries.geojson", "indicators.csv", "meta_age_group.csv",
                    "meta_area.csv", "meta_indicator.csv", "meta_period.csv")
                  %in% file_list$Name))

  expect_true(file.size(model_run$summary_report_path) > 2000)
})
