% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{collapse}
\alias{collapse}
\title{Collapse a vector into a human readable format for returning in messages}
\usage{
collapse(vector, collapse = ", ", limit = 150, end = "...")
}
\arguments{
\item{vector}{The vector to collapse}

\item{collapse}{Separator between each element after collapse}

\item{limit}{Max character length for message}

\item{end}{If length of message is over the limit this string will be
appended to the end}
}
\value{
The collapsed vector as a string.
}
\description{
Limits the returned message based on a character maximum.
}
\keyword{internal}
