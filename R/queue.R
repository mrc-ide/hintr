Queue <- R6::R6Class(
  "Queue",
  cloneable = FALSE,
  public = list(
    root = NULL,
    cleanup_on_exit = NULL,
    queue = NULL,
    results_dir = NULL,
    prerun_dir = NULL,

    initialize = function(queue_id = NULL, workers = 2,
                          cleanup_on_exit = workers > 0,
                          results_dir = tempdir(),
                          prerun_dir = NULL,
                          timeout = Inf) {
      self$cleanup_on_exit <- cleanup_on_exit
      self$results_dir = results_dir

      message(t_("QUEUE_CONNECTING", list(redis = redux::redis_config()$url)))
      con <- redux::hiredis()

      message(t_("QUEUE_STARTING"))
      queue_id <- hintr_queue_id(queue_id)
      self$queue <- rrq::rrq_controller(queue_id, con)
      self$queue$worker_config_save("localhost", heartbeat_period = 10,
                                    queue = c(QUEUE_CALIBRATE, QUEUE_RUN))
      self$queue$worker_config_save("calibrate_only", heartbeat_period = 10,
                                    queue = QUEUE_CALIBRATE)

      self$start(workers, timeout)

      message(t_("QUEUE_CACHE"))
      set_cache(queue_id)

      self$prerun_dir <- prerun_dir
    },

    start = function(workers, timeout) {
      if (workers > 0L) {
        ids <- rrq::worker_spawn(self$queue, workers)
        if (is.finite(timeout) && timeout > 0) {
          self$queue$message_send_and_wait("TIMEOUT_SET", timeout, ids)
        }
      }
    },

    submit = function(job, queue = NULL, environment = parent.frame()) {
      self$queue$enqueue_(job, environment, queue = queue,
                          separate_process = TRUE)
    },

    submit_model_run = function(data, options) {
      results_dir <- self$results_dir
      prerun_dir <- self$prerun_dir
      language <- traduire::translator()$language()
      self$submit(quote(
        hintr:::run_model(data, options, results_dir, prerun_dir, language)),
        queue = QUEUE_RUN)
    },

    submit_calibrate = function(model_output, calibration_options) {
      results_dir <- self$results_dir
      language <- traduire::translator()$language()
      self$submit(quote(
        hintr:::run_calibrate(model_output, calibration_options, results_dir,
                              language)),
        queue = QUEUE_CALIBRATE)
    },

    status = function(id) {
      status <- unname(self$queue$task_status(id))
      done <- c("ERROR", "DIED", "CANCELLED", "TIMEOUT", "COMPLETE")
      incomplete <- c("MISSING")
      progress <- self$queue$task_progress(id)
      if (status %in% done) {
        list(done = TRUE,
             status = status,
             success = status == "COMPLETE",
             queue = 0,
             progress = progress)
      } else if (status %in% incomplete) {
        list(done = json_verbatim("null"),
             status = status,
             success = json_verbatim("null"),
             queue = self$queue$task_position(id),
             progress = progress)
      } else {
        list(done = FALSE,
             status = status,
             success = json_verbatim("null"),
             queue = self$queue$task_position(id),
             progress = progress)
      }
    },

    result = function(id) {
      self$queue$task_result(id)
    },

    cancel = function(id) {
      self$queue$task_cancel(id, delete = FALSE)
    },

    ## Not part of the api exposed functions, used in tests
    remove = function(id) {
      self$queue$task_delete(id)
    },

    ## Not part of the api exposed functions, used in tests
    destroy = function() {
      self$queue$destroy(delete = TRUE)
    },

    cleanup = function() {
      clear_cache(self$queue$keys$queue_id)
      if (self$cleanup_on_exit && !is.null(self$queue$con)) {
        message(t_("QUEUE_STOPPING_WORKERS"))
        self$queue$worker_stop(type = "kill")
        self$destroy()
      }
    }
  ),

  private = list(
    finalize = function() {
      self$cleanup()
    }
  )
)

hintr_queue_id <- function(queue_id, worker = FALSE) {
  if (!is.null(queue_id)) {
    return(queue_id)
  }
  id <- Sys.getenv("HINTR_QUEUE_ID", "")
  if (!nzchar(id)) {
    if (worker) {
      stop(t_("QUEUE_ID_NOT_SET"))
    }
    id <- sprintf("hintr:%s", ids::random_id())
  }
  id
}
