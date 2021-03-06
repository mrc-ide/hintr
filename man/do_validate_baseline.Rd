% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/validate_inputs.R
\name{do_validate_baseline}
\alias{do_validate_baseline}
\title{Validate collection of baseline data for consistency.}
\usage{
do_validate_baseline(pjnz, shape, population)
}
\arguments{
\item{pjnz}{A file object (path, hash, filename) corresponding to
the input pjnz file}

\item{shape}{A file object (path, hash, filename) corresponding to
the input shape file.}

\item{population}{A file object (path, hash, filename) corresponding to
the input population file.}
}
\value{
An error if invalid.
}
\description{
Validate collection of baseline data for consistency.
}
\keyword{internal}
