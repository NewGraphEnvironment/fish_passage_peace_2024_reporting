source("scripts/02_reporting/0165-read-sqlite.R")
source('scripts/02_reporting/tables.R')

# At the time of writing in June 2025, we aren't really using these objects in other parts of the reporting so we will
# just build the objects here instead of in tables.R. We will also build the objects using our feild forms and fish data
# as opposed to the provincial spreadsheets because we are hoping to move away from that thing...


# Build objects ----------------------------------------------

# Some definitions of what these objects are:
#   - `hab_fish_collect` - species captured at each electrofishing sites
#   - `hab_features` - features found on the stream (beaver dams, major log jams, etc)
#   - `hab_site_priorities` - list of habitat confirmation sites with their priority ranking, barrier status, etc.
#   - `phase1_priorities` - list of phase 1 barrier assessments with habitat value and barrier status.


## Build `hab_fish_collect` object -----------------------------------------------

# Filter fish data to show distinct species captured at each sites
hab_fish_collect_prep1 <-  fish_data_complete |>
  dplyr::distinct(local_name, species, .keep_all = TRUE) |>
  dplyr::select(local_name,
                enclosure,
                species)


# Grab the species codes from fishbc
hab_fish_codes <- fishbc::freshwaterfish |>
  select(species_code = Code, common_name = CommonName)  |>
  tibble::add_row(species_code = 'NFC', common_name = 'No Fish Caught') |>
  mutate(common_name = case_when(common_name == 'Cutthroat Trout' ~ 'Cutthroat Trout (General)', TRUE ~ common_name))


# Add the species codes and pivot longer
hab_fish_collect_prep2 <- dplyr::left_join(
  hab_fish_collect_prep1 |>
    dplyr::mutate(species = as.factor(species)),  ##just needed to do this b/c there actually are no fish.

  hab_fish_codes |>
    dplyr::select(common_name, species_code),

  by = c('species' = 'common_name')
) |>
  # small fix because species = NFC not No Fish Caught
  dplyr::mutate(species_code = dplyr::case_when(species == "NFC" ~ "NFC", T ~ species_code)) |>
  dplyr::select(-species)


# Combine species into one column
hab_fish_collect_prep3 <- hab_fish_collect_prep2 |>
  dplyr::group_by(local_name) |>
  dplyr::summarise(
    species_code = stringr::str_c(unique(species_code), collapse = ", ")
  )

# Add the utm coordinates from form_fiss_site
hab_fish_collect <- dplyr::left_join(
  hab_fish_collect_prep3,

  form_fiss_site |>
    dplyr::select(gazetted_names, local_name, utm_zone:utm_northing),

  by = "local_name"
) |>
  dplyr::relocate(gazetted_names, .after = local_name)




## Build `hab_features` object -----------------------------------------------

# We will pull these directly from the spreasheet because that is the only place where the utm coordinates for the
# features are located...other than paper cards

habitat_confirmations <- fpr::fpr_import_hab_con(col_filter_na = TRUE, row_empty_remove = TRUE)


hab_features <-  dplyr::left_join(
  habitat_confirmations |>
    purrr::pluck("step_4_stream_site_data") |>
    dplyr::select(local_name, feature_type:utm_northing) |>
    dplyr::filter(!is.na(feature_type)),

  fpr::fpr_xref_obstacles,

  by = c('feature_type' = 'spreadsheet_feature_type')
)



## Build `hab_site_priorities` object -----------------------------------------------

hab_site_priorities <- dplyr::left_join(
  habitat_confirmations_priorities |>
    dplyr::mutate(site = as.character(site)),

  # Grab the barrier results and utm coordinates from the pscis phase 2 spreadsheet. Not ideal, but that is the only
  # place with the barrier results currently. Working on a function for that here though https://github.com/NewGraphEnvironment/fpr/issues/110
  pscis_phase2 |>
    dplyr::select(pscis_crossing_id,
                  barrier_result,
                  utm_zone,
                  utm_easting = easting,
                  utm_northing = northing) |>
    dplyr::mutate(pscis_crossing_id = as.character(pscis_crossing_id)),

  by = c('site' = 'pscis_crossing_id')
) |>
  # Just select the upstream sites, we don't need both ds and us
  dplyr::filter(location == "us") |>
  dplyr::select(stream_name,
                local_name,
                hab_value,
                priority,
                barrier_result,
                utm_zone:utm_northing)




## Build `phase1_priorities` object -----------------------------------------------

phase1_priorities <- pscis_all |>
  dplyr::filter(!source == "pscis_phase2.xlsm") |>
  dplyr::select(aggregated_crossings_id,
                pscis_crossing_id,
                my_crossing_reference,
                utm_zone,
                utm_easting = easting,
                utm_northing = northing,
                habitat_value,
                barrier_result,
                source)




# Burn objects to geopackage -----------------------------------------------

# BE AWARE!! `fpr_make_geopackage` has a default utm_zone = 9, so watch out if your utm_zone is not 9!!

fpr::fpr_make_geopackage(utm_zone = 10, dat = hab_fish_collect)
fpr::fpr_make_geopackage(utm_zone = 10, dat = hab_features)
fpr::fpr_make_geopackage(utm_zone = 10, dat = hab_site_priorities)
fpr::fpr_make_geopackage(utm_zone = 10, dat = phase1_priorities)




# Add other objects to geopackage -----------------------------------------------

path_repo_gpkg <- fs::path("data/fishpass_mapping/fishpass_mapping.gpkg")

## Watershed stats -----------------------------------------------

# We need to store the:
# - upstream watersheds for the phase 2 habitat confirmation sites (wshds)
# - watershed polygons for the watersheds included in the project study area (wshd_study_areas)
# These have both already been added to `fishpass_mapping.gpkg` in the script `scripts/02_reporting/0170-load-wshd_stats.R`


## GPS tracks -----------------------------------------------

# We also store the cleaned habitat confirmation gps tracks in this geopackage. These tracks get read in
# `/02_reporting/0165-read-sqlite.R`, but needs to be added to the geopackage.

habitat_confirmation_tracks |>
  sf::st_write(path_repo_gpkg, 'hab_tracks', append = TRUE)


## Copy to QGIS project  -----------------------------------------------

fs::file_copy(path = path_repo_gpkg,
              new_path = fs::path_expand(fs::path("~/Projects/gis/", params$gis_project_name, "/data_field/2024/fishpass_mapping.gpkg")),
              overwrite = T)



# Burn to GeoJSON -----------------------------------------------

# We use geojsons to make the mapping convenient as they update automagically in QGIS without a restart and b/c
# when in wsg84 they display by default on github and other web platforms.

# we send this GeoJSON to Simon and he uses them to update the pdf maps

dir_repo_gpkg <- fs::path("data/fishpass_mapping/")

rfp::rfp_gpkg_to_geojson(
  dir_in = dir_repo_gpkg,
  dir_out = dir_repo_gpkg,
  file_name_in = "fishpass_mapping"
)










