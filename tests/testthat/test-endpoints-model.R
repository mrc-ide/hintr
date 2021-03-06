context("endpoints-model")

test_that("endpoint model run queues a model run", {
  test_redis_available()
  test_mock_model_available()

  ## Setup payload
  path <- setup_submit_payload()

  ## Call the endpoint
  queue <- test_queue(workers = 1)
  model_submit <- submit_model(queue)
  response <- model_submit(readLines(path))
  expect_true("id" %in% names(response))

  ## Wait for complete and query for status
  ## Query for status
  result <- queue$queue$task_wait(response$id)
  status_endpoint <- queue_status(queue)
  status <- status_endpoint(response$id)
  expect_equal(status$id, response$id)
  expect_equal(status$done, scalar(TRUE))
  expect_equal(status$status, scalar("COMPLETE"))
  expect_equal(status$queue, scalar(0))
  expect_equal(status$success, scalar(TRUE))
  expect_length(status$progress, 2)
  expect_equal(status$progress[[1]]$name, scalar("Started mock model"))
  expect_true(status$progress[[1]]$complete)
  expect_equal(status$progress[[2]]$name, scalar("Finished mock model"))
  expect_false(status$progress[[2]]$complete)
  expect_equal(status$progress[[2]]$helpText, scalar("model running"))

  ## Get the result
  get_model_result <- model_result(queue)
  result <- get_model_result(response$id)
  expect_equal(result, list(
    id = scalar(response$id),
    complete = scalar(TRUE)
  ))
})

test_that("endpoint_run_model returns error if queueing fails", {
  test_redis_available()
  ## Create request data
  path <- setup_submit_payload()

  ## Create mocks
  queue <- test_queue()
  mock_submit_model_run <- function(data, options) { stop("Failed to queue") }

  ## Call the endpoint
  model_submit <- submit_model(queue)
  mockery::stub(model_submit, "queue$submit_model_run", mock_submit_model_run)
  error <- expect_error(model_submit(readLines(path)))

  expect_equal(error$data[[1]]$error, scalar("FAILED_TO_QUEUE"))
  expect_equal(error$data[[1]]$detail, scalar("Failed to queue"))
  expect_equal(error$status_code, 400)
})

test_that("running model with old version throws an error", {
  test_redis_available()

  ## Setup payload
  path <- setup_submit_payload('{
                               "hintr": "0.0.12",
                               "naomi": "0.0.15",
                               "rrq": "0.2.1"
                               }')

  ## Call the endpoint
  queue <- test_queue(workers = 1)
  model_submit <- submit_model(queue)
  error <- expect_error(model_submit(readLines(path)))

  expect_equal(error$data[[1]]$error, scalar("VERSION_OUT_OF_DATE"))
  expect_equal(error$data[[1]]$detail, scalar(
    paste0("Trying to run model with",
           " old version of options. Update model run options")))
  expect_equal(error$status_code, 400)
})

test_that("querying for status of missing job returns useful message", {
  test_redis_available()

  queue <- test_queue()
  status_endpoint <- queue_status(queue)
  status <- status_endpoint("ID")
  expect_equal(status$done, json_null())
  expect_equal(status$status, scalar("MISSING"))
  expect_equal(status$success, json_null())
  expect_equal(status$id, scalar("ID"))
})

test_that("querying for result of missing job returns useful error", {
  test_redis_available()

  queue <- test_queue()
  get_model_result <- model_result(queue)
  error <- expect_error(get_model_result("ID"))
  expect_equal(error$data[[1]]$error, scalar("FAILED_TO_RETRIEVE_RESULT"))
  expect_equal(error$data[[1]]$detail, scalar("Failed to fetch result"))
  expect_equal(error$status_code, 400)
})

test_that("querying for an orphan task returns sensible error", {
  test_redis_available()

  queue <- test_queue()
  id <- ids::random_id()
  queue$queue$con$HSET(queue$queue$keys$task_status, id, "DIED")
  get_model_result <- model_result(queue)
  error <- expect_error(get_model_result(id))

  expect_equal(error$data[[1]]$error, scalar("MODEL_RUN_FAILED"))
  expect_equal(error$data[[1]]$detail,
               scalar("Worker has crashed - error details are unavailable"))
  expect_equal(error$status_code, 400)
})

test_that("endpoint_run_status returns error if query for status fails", {
  test_redis_available()

  ## Create mocks
  queue <- test_queue()
  mock_status <- function(data, parameters) { stop("Failed to get status") }

  ## Call the endpoint
  status_endpoint <- queue_status(queue)
  mockery::stub(status_endpoint, "queue$status", mock_status)
  error <- expect_error(status_endpoint("ID"))
  expect_equal(error$data[[1]]$error, scalar("FAILED_TO_RETRIEVE_STATUS"))
  expect_equal(error$data[[1]]$detail, scalar("Failed to get status"))
  expect_equal(error$status_code, 400)
})

test_that("querying for result of incomplete jobs returns useful error", {
  test_redis_available()
  test_mock_model_available()

  path <- setup_submit_payload()
  queue <- test_queue(workers = 1)
  model_submit <- submit_model(queue)
  response <- model_submit(readLines(path))
  expect_true("id" %in% names(response))

  ## Get result prematurely
  get_model_result <- model_result(queue)
  error <- expect_error(get_model_result(response$id))

  expect_equal(error$data[[1]]$error, scalar("FAILED_TO_RETRIEVE_RESULT"))
  expect_equal(error$data[[1]]$detail,
               scalar("Failed to fetch result"))
  expect_equal(error$status_code, 400)
})

test_that("erroring model run returns useful messages", {
  test_redis_available()

  ## Call the endpoint
  queue <- MockQueue$new()
  path <- setup_submit_payload()
  model_submit <- submit_model(queue)
  response <- model_submit(readLines(path))
  expect_true("id" %in% names(response))
  out <- queue$queue$task_wait(response$id)

  ## Get the status
  endpoint_status <- queue_status(queue)
  status <- endpoint_status(response$id)
  expect_equal(status$done, scalar(TRUE))
  expect_equal(status$status, scalar("ERROR"))
  expect_equal(status$success, scalar(FALSE))
  expect_equal(status$id, response$id)

  # Get the result
  mock_id <- mockery::mock(scalar("fake_key"), cycle = TRUE)
  with_mock("ids::proquint" = mock_id, {
    get_model_result <- model_result(queue)
    error <- expect_error(get_model_result(response$id))
  })

  expect_equal(error$status_code, 400)
  expect_equal(names(error$data[[1]]), c("error", "detail", "key", "trace"))
  expect_equal(error$data[[1]]$error, scalar("MODEL_RUN_FAILED"))
  expect_equal(error$data[[1]]$detail, scalar("test error"))
  expect_equal(error$data[[1]]$key, scalar("fake_key"))

  trace <- vapply(error$data[[1]]$trace, identity, character(1))
  expect_true("rrq:::rrq_worker_main()" %in% trace)
  expect_true("stop(\"test error\")" %in% trace)
  expect_match(trace[[1]], "^# [[:xdigit:]]+$")
})

test_that("model run can be cancelled", {
  test_redis_available()
  test_mock_model_available()

  ## Start the model running
  path <- setup_submit_payload()
  queue <- test_queue(workers = 1)
  model_submit <- submit_model(queue)
  response <- model_submit(readLines(path))
  expect_true("id" %in% names(response))
  id <- response$id

  ## Mock model run sleeps for 5, sleep here for 1 to ensure it has
  ## started and will be running
  Sys.sleep(1)
  expect_equal(queue$queue$task_status(id), setNames("RUNNING", id))

  ## Cancel the run
  worker <- queue$queue$worker_list()
  cancel_model <- model_cancel(queue)
  response <- cancel_model(id)
  expect_equal(response, json_null())

  testthat::try_again(5, {
    Sys.sleep(1)
    log <- queue$queue$worker_log_tail(worker, n = Inf)
    expect_true("CANCEL" %in% log$command)
    expect_equal(queue$queue$task_status(id), setNames("CANCELLED", id))
  })

  get_status <- queue_status(queue)
  response <- get_status(id)
  expect_true(response$done)
  expect_false(response$success)
  expect_equal(response$status, scalar("CANCELLED"))

  get_result <- model_result(queue)
  error <- expect_error(get_result(id))
  expect_equal(error$data[[1]]$error, scalar("MODEL_RUN_FAILED"))
  expect_equal(error$data[[1]]$detail,
               scalar("Model run was cancelled by user"))
  expect_equal(error$status_code, 400)
})

test_that("translation of progress", {
  test_redis_available()
  test_mock_model_available()

  path <- setup_submit_payload()
  queue <- test_queue(workers = 1)
  model_submit <- submit_model(queue)
  get_status <- queue_status(queue)

  response <- with_hintr_language(
    "fr",
    model_submit(readLines(path)))
  id <- response$id

  ## Query for status
  result <- queue$queue$task_wait(id)
  status <- get_status(id)

  expect_equal(status$progress[[1]]$name,
               scalar("Maquette commencée"))
  expect_equal(status$progress[[2]]$name,
               scalar("Maquette terminée"))
})

test_that("error messages from naomi are translated", {
  test_redis_available()
  test_mock_model_available()
  queue <- withr::with_envvar(c("USE_MOCK_MODEL" = "false"),
                              test_queue(workers = 1))

  model_submit <- submit_model(queue)
  ## Create a population file which deliberately will cause an error
  path <- setup_submit_payload()
  payload <- readLines(path)
  payload <- jsonlite::read_json(path)
  pop <- read.csv(payload$data$population$path)
  pop$sex <- NULL
  t <- tempfile()
  write.csv(pop, t)
  payload$data$population$path <- t
  writeLines(jsonlite::toJSON(payload), path)

  response <- with_hintr_language(
    "fr",
    model_submit(readLines(path)))
  id <- response$id
  queue$queue$task_wait(id)

  get_result <- model_result(queue)
  error <- expect_error(get_result(id))
  expect_equal(error$data[[1]]$error, scalar("MODEL_RUN_FAILED"))
  expect_equal(error$data[[1]]$detail,
               scalar("Colonnes obligatoires introuvables: sex"))
})

test_that("failed cancel sends reasonable message", {
  test_redis_available()
  test_mock_model_available()
  ## Create request data
  queue <- test_queue()
  cancel_model <- model_cancel(queue)

  id <- ids::random_id()
  error <- expect_error(cancel_model(id))

  ## TODO: translate the message ideally - requires some work in rrq
  ## though.
  expect_equal(error$data[[1]]$error, scalar("FAILED_TO_CANCEL"))
  expect_match(error$data[[1]]$detail,
               scalar("Task [[:xdigit:]]+ is not cancelable \\(MISSING\\)"))
  expect_is(error$data[[1]]$key, "character")
  expect_equal(error$status_code, 400)
})

test_that("Debug endpoint returns debug information", {
  test_redis_available()
  test_mock_model_available()

  ## Start the model running
  path <- setup_submit_payload()
  queue <- test_queue(workers = 1)
  model_submit <- submit_model(queue)
  response <- model_submit(readLines(path))
  expect_true("id" %in% names(response))
  id <- response$id

  model_debug <- download_model_debug(queue)
  bin <- model_debug(id)
  tmp <- tempfile()
  dest <- tempfile()
  writeBin(as.vector(bin), tmp)
  zip::unzip(tmp, exdir = dest)
  expect_equal(scalar(dir(dest)), id)
  expect_setequal(
    dir(file.path(dest, id)),
    c("data.rds", "files"))
  info <- readRDS(file.path(dest, id, "data.rds"))
  ## Smoke test options are passed through
  expect_true(length(info$objects$options) > 25)
  expect_true(list(area_scope = "MWI") %in% info$objects$options)
  expect_is(info$sessionInfo, "sessionInfo")
  expect_equal(names(info$objects$data),
               c("pjnz", "shape", "population", "survey", "programme", "anc"))
  expect_equal(names(info$objects$data$pjnz), c("path", "hash", "filename"))
  expect_setequal(
    dir(file.path(dest, id, "files")),
    c("anc.csv", "malawi.geojson", "Malawi2019.PJNZ", "population.csv",
      "programme.csv", "survey.csv"))
})

test_that("Debug endpoint errors on nonexistant id", {
  test_redis_available()
  queue <- test_queue()
  model_debug <- download_model_debug(queue)

  error <- expect_error(model_debug("1234"))
  expect_equal(error$data[[1]]$error, scalar("INVALID_TASK"))
  expect_equal(error$data[[1]]$detail,
               scalar("Task '1234' not found"))
  expect_equal(error$status_code, 400)
})
