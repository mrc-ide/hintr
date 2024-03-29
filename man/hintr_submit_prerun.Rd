% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/prerun.R
\name{hintr_submit_prerun}
\alias{hintr_submit_prerun}
\title{Submit a prerun to the web app}
\usage{
hintr_submit_prerun(
  inputs,
  model_output,
  calibrate_output,
  server = "http://naomi.unaids.org",
  port = "8888",
  output_zip_path = tempfile(fileext = ".zip")
)
}
\arguments{
\item{inputs}{The model inputs, a named list of file paths including
pjnz, shape, population, survey and optionally programme and anc.}

\item{model_output}{The \code{hintr_output} object from model fit}

\item{calibrate_output}{The \code{hintr_output} object from calibration}

\item{server}{The server URL to upload files to}

\item{port}{The port the API is running on}

\item{output_zip_path}{The path to save the output zip at, will use
a tempfile by default}
}
\value{
Path to the generated output zip
}
\description{
This requires VPN or RDP access to work.
}
\details{
This will take all model files and upload to a specified server and
output the model output zip which can be saved into the ADR or
uploaded into the Naomi app to view plots of model outputs.

Can use this for countries which cannot get a fit to work via the app
you can prepare a model fit locally and then upload those outputs into
the app.
}
