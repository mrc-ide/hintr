PrerunModelResults <- R6::R6Class(
  "PrerunModelResults",
  private = list(
    path = NULL,
    validate_path = function(path, dir, name = deparse(substitute(path))) {
      if (grepl("/", path, fixed = TRUE)) {
        stop(sprintf("Path for '%s' must be just the filename, no slashes",
                     name))
      }
      path_full <- file.path(dir, path)
      if (!file.exists(path_full)) {
        stop(sprintf("Path '%s' for '%s' does not exist", path, name))
      }
      file.path(dir, path)
    }
  ),

  public = list(
    initialize = function(path) {
      private$path <- path
      dir.create(private$path, FALSE, TRUE)
    },

    exists = function(inputs) {
      hash <- hash_info_inputs(inputs)
      file.exists(file.path(private$path, hash))
    },

    list = function() {
      dir(private$path, pattern = "^[[:xdigit:]]+$")
    },

    get = function(inputs) {
      self$get_by_hash(hash_info_inputs(inputs))
    },

    get_by_hash = function(hash) {
      p <- file.path(private$path, hash)
      ret <- list(
        output_path = file.path(private$path, hash, "output.rds"),
        spectrum_path = file.path(private$path, hash, "spectrum.zip"),
        coarse_output_path = file.path(private$path, hash, "coarse-output.zip"),
        summary_report_path = file.path(private$path, hash,
                                        "summary-report.html"),
        calibration_path = file.path(private$path, hash, "calibration.rds"))
      stopifnot(all(file.exists(vcapply(ret, identity))))
      ret
    },

    import = function(path, output = "output.rds",
                      spectrum = "spectrum.zip",
                      coarse_output = "coarse-output.zip",
                      summary_report = "summary-report.html",
                      calibration = "calibration.rds") {
      if (!file.exists(path)) {
        stop(sprintf("Import directory %s does not exist", path))
      }
      output <- private$validate_path(output, path)
      spectrum <- private$validate_path(spectrum, path)
      coarse_output <- private$validate_path(coarse_output, path)
      summary_report <- private$validate_path(summary_report, path)
      calibration <- private$validate_path(calibration, path)
      hash <- hash_info_inputs(read_info_inputs(coarse_output))
      import <- file.path(private$path, hash)
      if (file.exists(import)) {
        stop("This set of data has been imported already")
      }
      dir.create(import)
      file_copy(output, file.path(import, "output.rds"))
      file_copy(spectrum, file.path(import, "spectrum.zip"))
      file_copy(coarse_output, file.path(import, "coarse-output.zip"))
      file_copy(summary_report, file.path(import, "summary-report.html"))
      file_copy(calibration, file.path(import, "calibration.rds"))
      invisible(hash)
    }
  ))

##' Import prerun model results
##'
##' @title Import prerun model results
##' @param prerun Path to the prerun model store
##' @param path Path to your results
##' @param output Path, within \code{path} to your output file
##' @param spectrum Path, within \code{path} to your spectrum file
##' @param coarse_output Path, within \code{path} to your coarse output file
##' @param summary_report Path, within \code{path} to your summary report file
##' @param calibration Path, within \code{path} to your calibration file
##' @export
prerun_import <- function(prerun, path, output = "output.rds",
                          spectrum = "spectrum.zip",
                          coarse_output = "coarse-output.zip",
                          summary_report = "summary-report.html",
                          calibration = "calibration.rds") {
  PrerunModelResults$new(prerun)$import(path, output, spectrum, coarse_output,
                                        summary_report, calibration)
}

##' Push prerun model results to naomi.dide.ic.ac.uk
##'
##' @title Push prerun model results to naomi.dide.ic.ac.uk
##' @inheritParams prerun_import
##' @export
prerun_push <- function(path, output = "output.rds",
                        spectrum = "spectrum.zip",
                        coarse_output = "coarse-output.zip",
                        summary_report = "summary-report.html",
                        calibration = "calibration.rds") {
  loadNamespace("ssh")
  session <- ssh::ssh_connect("incoming@naomi.dide.ic.ac.uk")
  on.exit(ssh::ssh_disconnect(session))
  id <- ids::random_id(1, 6)
  dest <- sprintf("incoming/%s", id)
  args <- c("./hintr_prerun_import", dest, "--output", output,
            "--spectrum", spectrum, "--coarse-output", coarse_output,
            "--summary-report", summary_report, "--calibration", calibration)
  command <- paste(args, collapse = " ")
  ssh::scp_upload(session, path, dest)
  code <- ssh::ssh_exec_wait(session, command)
  if (code != 0) {
    stop("Error running remote command")
  }
}

read_info_inputs <- function(path) {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  zip::unzip(path, "info/inputs.csv", exdir = tmp, junkpaths = TRUE)
  path_inputs <- file.path(tmp, "inputs.csv")
  read_csv(path_inputs)
}


hash_info_inputs <- function(inputs) {
  inputs$role[inputs$role == "art_number"] <- "programme"
  inputs$role[inputs$role == "anc_testing"] <- "anc"
  digest::digest(inputs$md5sum[order(inputs$role)])
}
