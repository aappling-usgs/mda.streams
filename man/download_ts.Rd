% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/download_ts.R
\name{download_ts}
\alias{download_ts}
\title{Download timeseries data to local file destination}
\usage{
download_ts(var_src, site_name, folder = tempdir(), version = c("rds",
  "tsv"), on_remote_missing = c("stop", "return_NA"),
  on_local_exists = c("stop", "skip", "replace"))
}
\arguments{
\item{var_src}{a valid variable name for timeseries data (see 
\code{get_var_src_codes(data_type=='ts')$var_src})}

\item{site_name}{a valid mda.streams site (see \link{list_sites})}

\item{folder}{string for a folder location}

\item{version}{character string indicating whether you want to download the 
ts as an .rds or .tsv}

\item{on_remote_missing}{character indicating what to do if the remote file 
is missing}

\item{on_local_exists}{character indicating what to do if the folder already 
contains a file with the intended download name}
}
\value{
file handle (character path) for the downloaded file, or NA if the 
  timeseries is unavailable on ScienceBase
}
\description{
Download a timeseries file to a user-specified (or temp file) location
}
\examples{
\dontrun{
download_ts(var_src = c('doobs_nwis','baro_nldas'), site_name = 'nwis_06893300')
download_ts(var_src = c('doobs_nwis','baro_nldas'), site_name = 'nwis_06893300')
download_ts(var_src = c('doobs_nwis','baro_nldas'), site_name = 'nwis_06893300', 
  on_local_exists="skip")
}
}
\author{
Alison P Appling, Corinna Gries, Jordan S Read, Luke A Winslow
}
