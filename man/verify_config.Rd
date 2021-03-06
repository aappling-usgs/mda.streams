% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/verify_config.R
\name{verify_config}
\alias{verify_config}
\title{Verify that a config file row has the requisite info}
\usage{
verify_config(config, checks = c("names"), on_fail = warning)
}
\arguments{
\item{config}{a config df to verify}

\item{checks}{a character vector of tests to run}

\item{on_fail}{the function to apply to the error message[s] if a test fails}
}
\value{
TRUE if is valid, FALSE if not
}
\description{
Checks the config row for valid src-site-logic pairs with respect to a given 
model
}
\examples{
\dontrun{
egconfig <- suppressWarnings(
  stage_metab_config(tag="0.0.1", strategy="try stage_metab_config", 
    site="nwis_04087142", filename=NULL))
verify_config(egconfig)
}
}
