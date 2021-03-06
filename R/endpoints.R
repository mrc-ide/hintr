input_response <- function(value, type, file) {
  ret <- list(hash = scalar(file$hash),
                            type = scalar(type),
                            data = value$data,
                            filename = scalar(file$filename),
                            fromADR = scalar(file$fromADR),
                            filters = value$filters)
  validate_json_schema(to_json(ret), get_input_response_schema(type), "data")
  ret
}

model_options <- function(input) {
  input <- jsonlite::fromJSON(input)
  tryCatch({
    assert_file_exists(input$shape$path)
    assert_file_exists(input$survey$path)
    json_verbatim(
      do_endpoint_model_options(input$shape, input$survey,
                                input$programme, input$anc))
  }, error = function(e) {
    hintr_error(e$message, "INVALID_OPTIONS")
  })
}

calibration_options <- function() {
  tryCatch({
    json_verbatim(
      build_options_from_template(naomi::get_model_calibration_options()))
  }, error = function(e) {
    hintr_error(e$message, "INVALID_CALIBRATION_OPTIONS")
  })
}

root_endpoint <- function() {
  scalar(t_("WELCOME"))
}

validate_baseline <- function(input) {
  input <- jsonlite::fromJSON(input)
  validate_func <- switch(input$type,
                          pjnz = do_validate_pjnz,
                          shape = do_validate_shape,
                          population = do_validate_population)
  tryCatch({
    assert_file_exists(input$file$path)
    ## This does some validation of the data part of the response
    ## Is that right to do at this point or does porcelain have a way to validate
    ## subsets of the data?
    input_response(validate_func(input$file), input$type, input$file)
  },
  error = function(e) {
    hintr_error(e$message, "INVALID_FILE")
  })
}

validate_baseline_combined <- function(input) {
  input <- jsonlite::fromJSON(input)
  as_file_object <- function(x) {
    if (!is.null(x)) {
      file_object(x)
    } else {
      NULL
    }
  }
  tryCatch({
    do_validate_baseline(as_file_object(input$pjnz),
                         as_file_object(input$shape),
                         as_file_object(input$population))
  },
  error = function(e) {
    hintr_error(e$message, "INVALID_BASELINE")
  })
}

validate_survey_programme <- function(input) {
  input <- jsonlite::fromJSON(input)
  validate_func <- switch(input$type,
                          programme = do_validate_programme,
                          anc = do_validate_anc,
                          survey = do_validate_survey)
  tryCatch({
    shape <- file_object(input$shape)
    assert_file_exists(input$file$path)
    assert_file_exists(shape$path)
    input_response(validate_func(input$file, shape), input$type, input$file)
  },
  error = function(e) {
    hintr_error(e$message, "INVALID_FILE")
  })
}

model_options <- function(input) {
  input <- jsonlite::fromJSON(input)
  tryCatch({
    assert_file_exists(input$shape$path)
    assert_file_exists(input$survey$path)
    json_verbatim(
      do_endpoint_model_options(input$shape, input$survey,
                                input$programme, input$anc))
  }, error = function(e) {
    hintr_error(e$message, "INVALID_OPTIONS")
  })
}

model_options_validate <- function(input) {
  input <- jsonlite::fromJSON(input)
  tryCatch({
    ## Update some labels to match what naomi requires
    ## TODO: Some of this is shared between model running and here so we
    ## should use use common code when we merge this back into hintr.
    ## This endpoint currently isn't called see mrc-592.
    data <- input$data
    data$art_number <- data$programme
    data$programme <- NULL
    data$anc_testing <- data$anc
    data$anc <- NULL
    data <- naomi:::format_data_input(data)
    list(valid = scalar(naomi:::validate_model_options(data, input$options)))
  }, error = function(e) {
    hintr_error(e$message, "INVALID_OPTIONS")
  })
}

submit_model <- function(queue) {
  function(input) {
    input <- jsonlite::fromJSON(input)
    if (!is_current_version(input$version)) {
      hintr_error(t_("MODEL_SUBMIT_OLD"), "VERSION_OUT_OF_DATE")
    }
    tryCatch(
      list(id = scalar(queue$submit_model_run(input$data, input$options))),
      error = function(e) {
        hintr_error(e$message, "FAILED_TO_QUEUE")
      }
    )
  }
}

queue_status <- function(queue) {
  check_orphan <- throttle(queue$queue$worker_detect_exited, 10)
  function(id) {
    no_error(check_orphan())
    tryCatch({
      out <- queue$status(id)
      prepare_status_response(out, id)
    },
    error = function(e) {
      hintr_error(e$message, "FAILED_TO_RETRIEVE_STATUS")
    })
  }
}

model_result <- function(queue) {
  function(id) {
    verify_result_available(queue, id)
    list(id = scalar(id),
         complete = scalar(TRUE))
  }
}

submit_calibrate <- function(queue) {
  function(id, input) {
    verify_result_available(queue, id)
    calibration_options <- jsonlite::fromJSON(input)
    if (!is_current_version(calibration_options$version)) {
      hintr_error(t_("CALIBRATE_SUBMIT_OLD"), "VERSION_OUT_OF_DATE")
    }
    tryCatch(
      list(id = scalar(queue$submit_calibrate(queue$result(id),
                                              calibration_options$options))),
      error = function(e) {
        hintr_error(e$message, "FAILED_TO_QUEUE")
      }
    )
  }
}

calibrate_result <- function(queue) {
  function(id) {
    verify_result_available(queue, id)
    process_result(queue$result(id))
  }
}

calibrate_plot <- function(queue) {
  data <- read_csv(system_file("extdata/dummy_calibrate_data.csv"))
  data$spectrum_region_code <- as.character(data$spectrum_region_code)
  filters <- get_calibrate_plot_output_filters(data)
  function(id) {
    list(
      data = data,
      plottingMetadata = list(
        barchart = list(
          indicators = data_frame(
            indicator = "plhiv",
            value_column = "mean",
            error_low_column = "lower",
            error_high_column = "upper",
            indicator_column = "indicator",
            indicator_value = "plhiv",
            name = "PLHIV",
            scale = 1,
            accuracy = NA,
            format = "0.0%"
          ),
          filters = filters,
          defaults = list(
            indicator_id = scalar("plhiv"),
            x_axis_id = scalar("spectrum_region"),
            disaggregate_by_id = scalar("type"),
            selected_filter_options = list(
              spectrum_region = get_selected_filter_options(filters,
                                                            "spectrum_region"),
              quarter = get_selected_filter_options(filters, "quarter")[2],
              sex = get_selected_filter_options(filters, "sex", "both"),
              age = get_selected_filter_options(
                filters, "age", naomi::get_five_year_age_groups())[1],
              type = get_selected_filter_options(filters, "type")
            )
          )
        )
      )
    )
  }
}

verify_result_available <- function(queue, id) {
  task_status <- queue$queue$task_status(id)
  if (task_status == "COMPLETE") {
    result <- queue$result(id)
    if (!naomi:::is_hintr_output(result)) {
      hintr_error(t_("UNKNOWN_OUTPUT_TYPE"), "UNKNOWN_OUTPUT_TYPE")
    }
  } else if (task_status == "ERROR") {
    result <- queue$result(id)
    trace <- c(sprintf("# %s", id), result$trace)
    hintr_error(result$message, "MODEL_RUN_FAILED", trace = trace)
  } else if (task_status == "DIED") {
    hintr_error(t_("MODEL_RESULT_CRASH"), "MODEL_RUN_FAILED")
  } else if (task_status == "CANCELLED") {
    hintr_error(t_("MODEL_RUN_CANCELLED"), "MODEL_RUN_FAILED")
  } else { # ~= MISSING, PENDING, RUNNING
    hintr_error(t_("MODEL_RESULT_MISSING"), "FAILED_TO_RETRIEVE_RESULT")
  }
}

model_cancel <- function(queue) {
  function(id) {
    tryCatch({
      queue$cancel(id)
      json_null()
    },
    error = function(e) {
      hintr_error(e$message, "FAILED_TO_CANCEL")
    })
  }
}

plotting_metadata <- function(iso3) {
  tryCatch(
    do_plotting_metadata(iso3),
    error = function(e) {
      hintr_error(e$message, "FAILED_TO_GET_METADATA")
    }
  )
}

download_spectrum <- function(queue) {
  download(queue, "spectrum", "naomi-output", ".zip")
}

download_coarse_output <- function(queue) {
  download(queue, "coarse_output", "coarse-output", ".zip")
}

download_summary <- function(queue) {
  download(queue, "summary", "summary-report", ".html")
}

download <- function(queue, type, filename, ext) {
  function(id) {
    tryCatch({
      res <- queue$result(id)
      if (is_error(res)) {
        hintr_error(res$message, "MODEL_RUN_FAILED")
      }
      ## We renamed download from "summary" to "coarse_output" to be more
      ## representative of the actual content of the download and in
      ## preparation for adding a summary report.
      ## To be backwards compatible with old model results from the app
      ## we need to fallback to old name if the new name isn't available in
      ## the model result.
      if ("coarse_output_path" %in% names(res)) {
        coarse_output <- res$coarse_output_path
      } else {
        coarse_output <- res$summary_path
      }
      path <- switch(type,
                     "spectrum" = res$spectrum_path,
                     "coarse_output" = coarse_output,
                     "summary" = res$summary_report_path)
      if (is.null(path)) {
        hintr_error(t_("MODEL_RESULT_OLD",
                       list(type = gsub("-", " ",
                                        tools::file_path_sans_ext(filename)))),
                    "MODEL_RESULT_OUT_OF_DATE")
      }
      bytes <- readBin(path, "raw", n = file.size(path))
      bytes <- porcelain::porcelain_add_headers(bytes, list(
        "Content-Disposition" = build_content_disp_header(res$metadata$areas,
                                                          filename, ext),
        "Content-Length" = length(bytes)))
      bytes
    },
    error = function(e) {
      if (is_porcelain_error(e)) {
        stop(e)
      } else {
        hintr_error(e$message, "FAILED_TO_RETRIEVE_RESULT")
      }
    })
  }
}

build_content_disp_header <- function(areas, filename, ext) {
  sprintf('attachment; filename="%s"',
          paste0(paste(c(areas, filename, iso_time_str()), collapse = "_"),
                 ext))
}

download_model_debug <- function(queue) {
  function(id) {
    tryCatch({
      data <- queue$queue$task_data(id)
      files <- unique(unlist(lapply(data$objects$data, function(x) {
        if (!is.null(x)) {
          x$path
        }
      }), FALSE, FALSE))
      tmp <- tempfile()
      path <- file.path(tmp, id)
      dir.create(path, FALSE, TRUE)

      data$sessionInfo <- utils::sessionInfo()
      data$objects$data <- lapply(data$objects$data, function(x) {
        if (!is.null(x)) {
          list(path = basename(x$path), hash = x$hash, filename = x$filename)
        }
      })

      path_files <- file.path(path, "files")
      dir.create(path_files)
      file_copy(files, file.path(path_files, basename(files)))
      saveRDS(data, file.path(path, "data.rds"))

      on.exit(unlink(tmp, recursive = TRUE))

      dest <- paste0(id, ".zip")
      withr::with_dir(tmp, zip::zipr(dest, id))

      path <- file.path(tmp, dest)
      bytes <- readBin(path, "raw", n = file.size(path))
      bytes <- porcelain::porcelain_add_headers(bytes, list(
        "Content-Disposition" =
          sprintf('attachment; filename="%s_%s_naomi_debug.zip"',
                  id, iso_time_str())))
      bytes
    },
    error = function(e) {
      if (is_porcelain_error(e)) {
        stop(e)
      } else {
        hintr_error(e$message, "INVALID_TASK")
      }
    })
  }
}

worker_status <- function(queue) {
  function() {
    lapply(queue$queue$worker_status(), scalar)
  }
}

hintr_stop <- function(queue) {
  force(queue)
  function() {
    message("Stopping workers")
    queue$queue$worker_stop()
    message("Quitting hintr")
    quit(save = "no")
  }
}

prepare_status_response <- function(value, id) {
  set_scalar <- function(x) {
    if (length(names(x)) > 1) {
      lapply(x, set_scalar)
    } else {
      scalar(x)
    }
  }

  json_or_scalar <- function(x) {
    if (inherits(x, "json")) {
      x
    } else {
      scalar(x)
    }
  }

  response_value <- lapply(value[names(value) != "progress"], json_or_scalar)
  response_value$progress <- lapply(unname(value$progress), set_scalar)
  response_value$id <- scalar(id)
  response_value
}

hintr_error <- function(message, error, status_code = 400L, ...) {
  key <- scalar(ids::proquint(n_words = 3))
  porcelain::porcelain_stop(message, error, errors = NULL,
                            status_code = status_code, key = key, ...)
}

hintr_404_handler <- function(req, res) {
  ## Manually construct the response here
  res$status <- 404L
  message <- t_("ERROR_404",
                 list(verb = req$REQUEST_METHOD, path = req$PATH_INFO))
  list(
    status = scalar("failure"),
    errors = list(
      list(
        error = scalar("NOT_FOUND"),
        detail = scalar(message),
        key = scalar(ids::proquint(n_words = 3))
      )
    ),
    data = NULL
  )
}
