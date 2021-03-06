% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/stage_calc_ts.R
\name{stage_calc_ts}
\alias{stage_calc_ts}
\title{stage calculated or modeled data into a time series file}
\usage{
stage_calc_ts(sites, var, src, folder = tempdir(), version = c("rds",
  "tsv"), inputs = list(), day_start = 4, day_end = 28, verbose = FALSE,
  with_ts_version = "rds", with_ts_archived = FALSE,
  with_ts_uploaded_after = "2017-01-01", ...)
}
\arguments{
\item{sites}{a character vector of valid NWIS site IDs}

\item{var}{short name of variable as in 
\code{unique(get_var_src_codes(out='var'))}}

\item{src}{short name of src as in \code{get_var_src_codes(var==myvar, 
out='src')}}

\item{folder}{a folder to place the file outputs in (defaults to temp 
directory)}

\item{version}{the format (rds/tsv) in which to save the calculated ts}

\item{inputs}{appropriate only when src is a simXxxx type. a list of named 
inputs (data.frames, constants, etc.) to pass to the specified calculation 
function. These inputs are downloaded from standard locations for the 
calcXxxx variants.}

\item{day_start}{hour of day start as in \code{mm_model_by_ply}}

\item{day_end}{hour of day end as in \code{mm_model_by_ply}}

\item{verbose}{logical. provide status messages?}

\item{with_ts_version}{one or more of \code{c('rds','tsv')} to limit the 
dataset extension to anything in with_ts_version (if the dataset is a ts)}

\item{with_ts_archived}{one or more of \code{c(TRUE,FALSE)} to limit the list
to sites that have a ts that's archived, not archived, or either}

\item{with_ts_uploaded_after}{POSIXct, or convertible to POSIXct, giving date
after which a ts must have been uploaded to count}

\item{...}{additional arguments passed to \code{\link[geoknife]{geoknife}} 
and \code{\link[unitted]{write_unitted}}}
}
\value{
a file handle for time series file created
}
\description{
accept calculated/modeled data as a data.frame and return a file
  handle
}
\examples{
\dontrun{
# calc

file_par <- stage_calc_ts(sites="nwis_08062500", var="par", src="calcLat", verbose=TRUE)
head(read_ts(file_par))
attr(file_par, 'choices')

file_parMerged <- stage_calc_ts(sites="nwis_08062500", var="par", src="calcLatSw", verbose=TRUE)
head(read_ts(file_parMerged))
attr(file_parMerged, 'choices')
library(ggplot2)
ggplot(unitted::v(read_ts(file_parMerged)), aes(x=DateTime, y=par)) + geom_line()
pm <- read_ts(file_parMerged)
subset(unitted::v(pm), par>5000) # make sure there aren't any extreme values

file_depth <- stage_calc_ts(sites="nwis_08062500", var="depth", src="calcDischHarvey", verbose=TRUE)
head(read_ts(file_depth))
attr(file_depth, 'choices')

file_dosat <- stage_calc_ts(sites="nwis_08062500", var="dosat", src="calcGGbconst", verbose=TRUE)
head(read_ts(file_dosat))

# with data provenance

some_sites <- c('nwis_08062500','styx_001002','nwis_05515500','nwis_295826095082200')
file_par <- stage_calc_ts(sites=some_sites, var="par", src="calcLat", verbose=TRUE)
attr(file_par, 'choices')

# sim calc

library(dplyr); library(unitted)
real_doobs <- read_ts(download_ts("doobs_nwis", "nwis_08062500", on_local_exists="replace")) \%>\%
  subset(v(DateTime) > as.POSIXct("2014-07-13", tz="UTC") & 
    v(DateTime) <= as.POSIXct("2014-07-15", tz="UTC"))

file_suntime <- stage_calc_ts(sites="nwis_08062500", var="suntime", src="simLon", verbose=TRUE, 
  inputs=list(utctime=real_doobs$DateTime, longitude=u(-96.46304, "degE")))
head(read_ts(file_suntime))

file_par <- stage_calc_ts(sites="nwis_08062500", var="par", src="simLat", verbose=TRUE,
  inputs=list(utctime=real_doobs$DateTime, suntime=read_ts(file_suntime)$suntime, 
  latitude=u(32.42653, "degN")))
head(read_ts(file_par))

file_depth <- stage_calc_ts(sites="nwis_08062500", var="depth", src="simDisch", verbose=TRUE,
  inputs=list(utctime=real_doobs$DateTime, disch=u(rep(2900, nrow(real_doobs)), "ft^3 s^-1")))
head(read_ts(file_depth))

file_dosat <- stage_calc_ts(sites="nwis_08062500", var="dosat", src="simGGbconst", verbose=TRUE,
  inputs=list(utctime=real_doobs$DateTime, wtr=u(rep(12, 192), "degC"), baro=u(90000, "Pa")))
head(read_ts(file_dosat))

# simNew

file_par2 <- stage_calc_ts(sites="nwis_08062500", var="par", src="simNew", verbose=TRUE,
  inputs=list(utctime=real_doobs$DateTime, 
              value=u(rnorm(real_doobs$DateTime, 10, 2), "umol m^-2 s^-1")))
head(read_ts(file_par2))

# simCopy

file_suntime2 <- stage_calc_ts(sites="styx_001001", var="suntime", src="simCopy", verbose=TRUE,
  inputs=list(from_src="calcLon", from_site="nwis_08062500", filter_fun=function(df) {
    df[df$DateTime > as.POSIXct("2015-05-14", tz="UTC") &
         df$DateTime < as.POSIXct("2015-05-17", tz="UTC"), ] }))
file_suntime2
head(read_ts(file_suntime2))

# daily means

file_dischdaily <- stage_calc_ts(sites="nwis_08062500", 
  var="dischdaily", src="calcDMean", verbose=TRUE)
head(read_ts(file_dischdaily))

file_mfootdaily <- stage_calc_ts(sites="nwis_08062500", 
  var="mfootdaily", src="calc3vK", verbose=TRUE)
head(read_ts(file_mfootdaily))
}
}
