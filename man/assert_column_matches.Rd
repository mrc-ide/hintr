% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/validation_asserts.R
\name{assert_column_matches}
\alias{assert_column_matches}
\title{Check that values of column match regex pattern}
\usage{
assert_column_matches(data, column_name, pattern)
}
\arguments{
\item{data}{Data to check}

\item{column_name}{Column to check}

\item{pattern}{Pattern to match}
}
\value{
TRUE is valid otherwise throws an error
}
\description{
Check that values of column match regex pattern
}
\keyword{internal}
