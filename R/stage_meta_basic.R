#' Create/modify sites file
#' 
#' @param sites a vector of sites to acquire/update metadata for
#' @param on_exists what to do if the file already exists in the given folder
#' @param folder the folder in which to save the metadata file
#' @param verbose logical. print status messages?
#' @import dplyr
#' @import tibble
#' @importFrom unitted u v is.unitted get_units write_unitted
#' @export
#' @examples 
#' \dontrun{
#' stage_meta_basic(sites=list_sites()[655:665], verbose=TRUE, folder=NULL)
#' }
stage_meta_basic <- function(sites=list_sites(), on_exists=c('replace','add_rows','stop','replace_rows'), folder = tempdir(), verbose = FALSE) {
  
  on_exists <- match.arg(on_exists)
  
  # Establish the basic site information
  sites_meta <- 
    tibble(
      site_name=sites, 
      site_database=parse_site_name(sites, out='database'),
      site_num=parse_site_name(sites, out='sitenum')) %>%
    as.data.frame() %>% # unitted_data.frames work better than unitted_tbl_dfs for now
    u()
  
  # get metadata from each site database in turn. if stage_meta_basic_nwis
  # changes its output, empty_meta in stage_meta_basic should also be changed
  empty_meta <- u(data.frame(
    site_name=u(as.character(NA),NA), long_name=u(as.character(NA),NA),
    lat=u(as.numeric(NA),"degN"), lon=u(as.numeric(NA),"degE"), coord_datum=u(as.character(NA),NA), 
    alt=u(as.numeric(NA),"ft"), alt_datum=u(as.character(NA),NA), site_type=u(as.character(NA),NA), 
    nhdplus_id=u(as.numeric(NA),NA),
    stringsAsFactors=FALSE))[NULL,]
  meta_nwis <- sites_meta[sites_meta$site_database=="nwis",] %>% stage_meta_basic_nwis(empty_meta=empty_meta, verbose=verbose)
  meta_styx <- sites_meta[sites_meta$site_database=="styx",] %>% stage_meta_basic_styx(empty_meta=empty_meta, verbose=verbose)
  meta_indy <- sites_meta[sites_meta$site_database=="indy",] %>% stage_meta_basic_indy(empty_meta=empty_meta, verbose=verbose)
  
  # merge the datasets
  if(!all.equal(get_units(meta_nwis), get_units(meta_styx)) ||
     !all.equal(get_units(meta_nwis), get_units(meta_indy))) stop("units mismatch in binding meta_xxxxes")
  meta_merged <- bind_rows(v(meta_nwis), v(meta_styx), v(meta_indy)) %>% 
    as.data.frame() %>% 
    u(get_units(meta_nwis))
  sites_meta <- left_join(sites_meta, meta_merged, by="site_name", copy=TRUE)
  
  # add a quick-access column of sciencebase site item IDs
  siteids <- item_list_children(mda.streams::locate_folder('sites'), limit=10000) %>%
    lapply(function(si) as.data.frame(si[c('title','id')], stringsAsFactors=FALSE)) %>%
    bind_rows()
  sites_meta$sciencebase_id <- siteids$id[match(sites_meta$site_name, siteids$title)]
  
  # merge with existing metadata if appropriate
  on_exists <- match.arg(on_exists)
  if(on_exists == 'replace') {
    new_meta <- sites_meta
  } else {
    if('basic' %in% list_metas()) {
      if(on_exists == 'stop') stop("on_exists == 'stop' and 'basic' meta already exists on ScienceBase")
        
      # get existing metadata
      old_meta <- read_meta(download_meta('basic', on_local_exists = 'replace'))
      
      # quick & unhelpful compatibility check
      if(!all.equal(names(old_meta), names(sites_meta))) 
        stop("column names of old and new metadata don't match")
      
      # check for conflicting rows and stop or replace
      replacements <- old_meta$site_name[which(old_meta$site_name %in% sites_meta$site_name)]
      if(length(replacements) > 0) {
        if(on_exists=="add_rows") {
          stop("these sites are already in meta_basic: ", paste0(replacements, collapse=", "))
        } else { # on_exists=='replace_rows'
          old_meta[match(replacements, old_meta$site_name), ] <- sites_meta[match(replacements, sites_meta$site_name), ]
          sites_meta <- sites_meta[!(sites_meta$site_name %in% replacements),]
        }
      }
      
      # add truly new rows
      new_meta <- rbind(old_meta, sites_meta)
    } else {
      new_meta <- sites_meta
    }
  }
  site_name <- '.dplyr.var'
  new_meta <- new_meta %>% v() %>% arrange(site_name) %>% u(get_units(new_meta)) # way faster than order()
  
  # either return the data.frame, or save data to local file and return the
  # filename.
  if(is.null(folder)) {
    return(new_meta)
  } else {
    fpath <- make_meta_path(type='basic', folder=folder)
    gz_con <- gzfile(fpath, "w")
    meta_file <- write_unitted(new_meta, file=gz_con, sep="\t", row.names=FALSE, quote=TRUE)
    close(gz_con)
    return(invisible(fpath))
  }
  
}

#' Get data for NWIS sites
#' 
#' Helper to stage_meta_basic. Download/clean up columns of useful data for NWIS
#' sites
#' 
#' @param sites_meta a data.frame of site_names and parse site_names, as in the
#'   opening lines of stage_meta_basic
#' @param empty_meta a data.frame showing how an empty result should look
#' @param verbose logical. give status messages?
#' @importFrom dataRetrieval readNWISsite
#' @importFrom unitted u v
#' @import dplyr
#' @importFrom utils read.table
#' @keywords internal
#' @examples
#' \dontrun{
#' sites <- list_sites()[655:665]
#' sites_meta <- tibble::tibble(
#'   site_name=sites, 
#'   site_database=parse_site_name(sites, out='database'),
#'   site_num=parse_site_name(sites, out='sitenum')) %>%
#'   as.data.frame() %>% # unitted_data.frames work better than unitted_tbl_dfs for now
#'   u()
#' str(mda.streams:::stage_meta_basic_nwis(sites_meta, verbose=TRUE))
#' }
stage_meta_basic_nwis <- function(sites_meta, empty_meta, verbose=FALSE) {
  
  # this empty_meta ignores everything else in this function; if
  # stage_meta_basic_nwis changes its output, empty_meta in stage_meta_basic
  # should also be changed.
  nwis_meta <- empty_meta[seq_len(nrow(sites_meta)),]
  if(nrow(nwis_meta) == 0) return(nwis_meta)
  
  if(verbose) message("acquiring NWIS metadata")
  
  # get NWIS site metadata from NWIS in chunks
  site_database <- site_name <- group <- . <- agency_cd <- site_tp_cd <- '.dplyr.var'
  group_size <- 50 # dataRetrieval can't handle huge lists of sites
  sites_meta <- sites_meta %>%
    v() %>% # unitted can't handle all that's to come here
    filter(site_database == "nwis") %>%
    mutate(group=rep(1:ceiling(length(site_name)/group_size), each=group_size)[1:length(site_name)]) %>%
    group_by(group) %>%
    do(readNWISsite(.$site_num) %>%
         select(agency_cd, site_no, station_nm, site_tp_cd,
                lat_va, long_va, dec_lat_va, dec_long_va, coord_datum_cd, dec_coord_datum_cd,
                alt_va, alt_datum_cd))
  
  # do our best to get decimal coordinates
  parse_nwis_coords <- function(coords) {
    deg <- floor(coords/10000)
    min <- floor((coords-deg*10000)/100)
    sec <- coords-deg*10000-min*100
    return(deg + (min/60) + (sec/3600))
  }
  station_nm <- dec_lat_va <- dec_long_va <- lat_va <- long_va <- dec_coord_datum_cd <- 
    coord_datum_cd <- alt_va <- alt_datum_cd <- site_name <- site_no <- 
    long_name <- site_type <- lat <- lon <- coord_datum <- alt <- alt_datum <- site_name <- '.dplyr.var'
  sites_meta <- sites_meta %>% 
    mutate(
      long_name=station_nm,
      site_type=site_tp_cd,
      lat=ifelse(!is.na(dec_lat_va) & !is.na(dec_long_va), dec_lat_va, parse_nwis_coords(lat_va)),
      lon=ifelse(!is.na(dec_lat_va) & !is.na(dec_long_va), dec_long_va, -parse_nwis_coords(long_va)),
      coord_datum=ifelse(!is.na(dec_lat_va) & !is.na(dec_long_va), dec_coord_datum_cd, coord_datum_cd),
      alt=alt_va,
      alt_datum=alt_datum_cd) %>%
    # eliminate duplicates
    group_by(site_no) %>%
    summarize(long_name=long_name[1], lat=mean(lat, na.rm=TRUE), lon=mean(lon, na.rm=TRUE), coord_datum=unique(coord_datum),
              alt=mean(alt_va), alt_datum=unique(alt_datum_cd), site_type=site_type[1]) %>%
    # turn site_no into site_name
    mutate(site_name=make_site_name(unique(site_no), database="nwis"))
  
  # load NHDPlus ComIDs from file and attach to sites_meta
  comidfile <- system.file('extdata/170505_stets_COMIDs_Slopes.csv', package='mda.streams')
  comids <- read.table(comidfile, header=TRUE, sep=",", colClasses="character", skip=3)
  matched_comids <- comids[match(sites_meta$site_name, comids$site_name),"COMID"]
  
  # These were the COMIDs from 7/1/2015. Ted reconciled these with Jud's recent 
  # COMID matchups and some hand checking in GIS to produce the above file 
  # (170505_stets_COMIDs_Slopes.csv). However, this reconciliation didn't 
  # provide COMIDs for sites not in the chosen 367 sites, so here we'll merge in
  # COMIDs from old sites that probably don't have metabolism estimates but 
  # might someday. This still leaves 99 sites, hopefully important ones, for
  # which nhdplus_id is NA
  oldcomidfile <- system.file('extdata/NHDPlus_ComIDs.tsv', package='mda.streams')
  oldcomids <- read.table(oldcomidfile, header=TRUE, sep="\t", colClasses="character")
  oldcomids[oldcomids$comid_best==0,'comid_best'] <- NA
  oldmatched_comids <- oldcomids[match(sites_meta$site_no, oldcomids$nwis_id),"comid_best"]
  
  # Merge the new and old COMIDs
  sites_meta$nhdplus_id_v1 <- ifelse(!is.na(matched_comids), matched_comids, oldmatched_comids)
                                         
  # Third possible source of COMIDs: the NLDI API. Takes ~2.5 minutes to run 100 sites
  nldi_comids <- sapply(sites_meta$site_no[is.na(sites_meta$nhdplus_id_v1)], function(site_no) {
    nldi_site <- sprintf('https://cida.usgs.gov/nldi/nwissite/USGS-%s', site_no)
    comid <- tryCatch({
      nldi_data <- jsonlite::fromJSON(nldi_site)
      nldi_data$features$properties$comid
    }, error=function(e) NA)
    return(comid)
  })
  nldi_comids[nldi_comids==""] <- NA
  matched_nldi_comids <- nldi_comids[match(sites_meta$site_no, names(nldi_comids))]
  
  # Add the NLDI COMIDs to the ted/james/jud COMIDs
  sites_meta$nhdplus_id <- ifelse(!is.na(sites_meta$nhdplus_id_v1), sites_meta$nhdplus_id_v1, matched_nldi_comids)
  
  # format
  nhdplus_id <- '.dplyr.var'
  sites_meta  %>%
    # put columns in proper order
    select(site_name, long_name, lat, lon, coord_datum, alt, alt_datum, site_type, nhdplus_id) %>%
    # add units
    as.data.frame() %>%
    u(c(site_name=NA, long_name=NA, lat="degN", lon="degE", coord_datum=NA, 
        alt="ft", alt_datum=NA, site_type=NA, nhdplus_id=NA))
}

#' Get data for Styx (simulated data) sites
#' 
#' Helper to stage_meta_basic. Create dummy columns of metadata for Styx sites.
#' 
#' @param sites_meta a data.frame of site_names and parsed site_names, as in the
#'   opening lines of stage_meta_basic
#' @param empty_meta a data.frame showing how an empty result should look
#' @param verbose logical. give status messages?
#' @importFrom dataRetrieval readNWISsite
#' @importFrom unitted u v
#' @keywords internal
#' @examples
#' \dontrun{
#' sites <- list_sites()[655:665]
#' sites_meta <- tibble::tibble(
#'   site_name=sites, 
#'   site_database=parse_site_name(sites, out='database'),
#'   site_num=parse_site_name(sites, out='sitenum')) %>%
#'   as.data.frame() %>% # unitted_data.frames work better than unitted_tbl_dfs for now
#'   u()
#' str(mda.streams:::stage_meta_basic_styx(sites_meta, verbose=TRUE))
#' }
stage_meta_basic_styx <- function(sites_meta, empty_meta, verbose=FALSE) {
  styx_meta <- empty_meta[seq_len(nrow(sites_meta)),]
  if(nrow(styx_meta) == 0) return(styx_meta)
  
  styx_meta[['site_name']] <- sites_meta$site_name
  styx_meta[['long_name']] <- u(paste0("Simulated data: ",sites_meta$site_name))
  
  styx_meta
}


#' Get data for Indy (custom/independently collected data) sites
#' 
#' Helper to stage_meta_basic. Copies data from meta_indy into meta_basic where 
#' this is available.
#' 
#' @param sites_meta a data.frame of site_names and parsed site_names, as in the
#'   opening lines of stage_meta_basic
#' @param empty_meta a data.frame showing how an empty result should look
#' @param verbose logical. give status messages?
stage_meta_basic_indy <- function(sites_meta, empty_meta, verbose=FALSE) {
  indy_meta <- empty_meta[seq_len(nrow(sites_meta)),]
  if(nrow(indy_meta) == 0) return(indy_meta)
  
  im <- get_meta('indy')
  im <- im[match(sites_meta$site_name, im$site_name), ]
  
  indy_meta[['site_name']] <- im$site_name
  indy_meta[['long_name']] <- im$indy.long_name
  indy_meta[['lat']] <- im$indy.lat
  indy_meta[['lon']] <- im$indy.lon
  indy_meta[['alt']] <- im$indy.alt
  
  indy_meta
}