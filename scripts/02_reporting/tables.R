## new tables.R

# Parameters -------------------------------------------------

# path to form_pscis_2024
path_form_pscis <- fs::path('~/Projects/gis/sern_peace_fwcp_2023/data_field/2024/form_pscis_2024.gpkg')

# path to NEW `form_fiss_site_2024` made from `0205_fiss_extract_inputs.Rmd`
path_form_fiss_site <- fs::path('~/Projects/gis/sern_peace_fwcp_2023/data_field/2024/form_fiss_site_2024.gpkg')

# path to the fish data with the pit tags joined.
path_fish_tags_joined <-  fs::path_expand('~/Projects/repo/fish_passage_peace_2024_reporting/data/fish_data_tags_joined.csv')

# specify which project data we want. for this case `2024-073-sern-peace-fish-passage`
project = "2024-073-sern-peace-fish-passage"

# specify the repo
repo_name <- "fish_passage_peace_2024_reporting"


# Generate dynamic captions -------------------------------------------------

# Dynamically make the table captions depending on the species used for modelling.
# These captions are used in the methods and results sections

# specify in index.Rmd YAML which species you want to use for the modelling
# For Skeena we use steelhead
# For Peace we use bull trout
model_species_name <- dplyr::case_when(params$model_species == "bt" ~ "Bull trout",
                                       params$model_species == "st" ~ "Steelhead")

# Network/access model caption

# Hard coding these for now, not ideal but will do.
bt_network_gradient <- "25"
st_network_gradient <- "20"

sp_network_caption <- dplyr::case_when(params$model_species == "bt" ~ paste0(model_species_name," network model used for habitat estimates (total length of stream network <",
                                                                             bt_network_gradient, "% gradient)."),
                                       params$model_species == "st" ~ paste0(model_species_name," network model used for habitat estimates (total length of stream network <",
                                                                             st_network_gradient, "% gradient)."))

#Rearing model caption

#pull out the max rearing gradient
rear_gradient <- bcfishpass_spawn_rear_model |>
  dplyr::filter(species_code == stringr::str_to_upper(params$model_species)) |>
  dplyr::mutate(rear_gradient_max = round((rear_gradient_max*100), 1)) |>
  dplyr::pull(rear_gradient_max)

sp_rearing_caption <- paste0(model_species_name," rearing model used for habitat estimates (total length of stream network <", rear_gradient, "% gradient).")


#pull out the max spawning gradient as well, used in the caption for plot-model-all
spawn_gradient <- bcfishpass_spawn_rear_model |>
  dplyr::filter(species_code == stringr::str_to_upper(params$model_species)) |>
  dplyr::mutate(spawn_gradient_max = round((spawn_gradient_max*100), 1)) |>
  dplyr::pull(spawn_gradient_max)


# Load data -------------------------------------------------

## Reload form_pscis -------------------------------------------------

# form_pscis gets read in from `02_reporting/0165-read-sqlite.R`

# If update_form_pscis = TRUE then load form_pscis to sqlite - need to load the params from `index.Rmd`
if (params$update_form_pscis) {
  form_pscis <- fpr::fpr_sp_gpkg_backup(
    path_gpkg = path_form_pscis,
    dir_backup = "data/backup/",
    update_utm = TRUE,
    update_site_id = FALSE, ## This now also checks for duplicates
    write_back_to_path = FALSE,
    write_to_csv = FALSE,
    write_to_rdata = FALSE,
    return_object = TRUE)


  conn <- readwritesqlite::rws_connect("data/bcfishpass.sqlite")
  # won't run on first build if the table doesn't exist
  readwritesqlite::rws_drop_table("form_pscis", conn = conn)
  readwritesqlite::rws_write(form_pscis, exists = F, delete = TRUE,
                             conn = conn, x_name = "form_pscis")
  readwritesqlite::rws_disconnect(conn)
}


## Reload form_fiss_site -------------------------------------------------

# form_fiss_site data gets read in from `02_reporting/0165-read-sqlite.R`

# If update_form_fiss_site = TRUE then load form_fiss_site to sqlite - need to load the params from `index.Rmd`
if (params$update_form_fiss_site) {
  form_fiss_site <- fpr::fpr_sp_gpkg_backup(
    path_gpkg = path_form_fiss_site,
    dir_backup = "data/backup/",
    update_utm = TRUE,
    update_site_id = FALSE,
    write_back_to_path = FALSE,
    return_object = TRUE,
    write_to_csv = FALSE,
    write_to_rdata = FALSE,
    col_easting = "utm_easting",
    col_northing = "utm_northing") |>
    sf::st_drop_geometry()


# Peace 2024 - times in `form_fiss_site_raw` are wrong in R and Q!
#
# We need to fix the times because they are in UTC and we need them in PDT. This issue is documented here https://github.com/NewGraphEnvironment/fish_passage_template_reporting/issues/18
  form_fiss_site_clean_times <- form_fiss_site |>
    # make a new column for the time as is with different name then mutate to PST
    # we don't need the new column but will leave here for now so we can visualize and confirm the time is correct
    dplyr::mutate(date_time_start_raw = date_time_start,
                  date_time_start = lubridate::force_tz(date_time_start_raw, tzone = "America/Vancouver"),
                  date_time_start = lubridate::with_tz(date_time_start, tzone = "UTC")) |>
    dplyr::relocate(date_time_start_raw, .after = date_time_start)

  ## Double check the time is correct and now remove the date_time_start_raw column
  form_fiss_site <- form_fiss_site_clean_times |>
    select(-date_time_start_raw)


  # Now burn to the sqlite
  conn <- readwritesqlite::rws_connect("data/bcfishpass.sqlite")
  # won't run on first build if the table doesn't exist
  readwritesqlite::rws_drop_table("form_fiss_site", conn = conn)
  readwritesqlite::rws_write(form_fiss_site, exists = F, delete = TRUE,
                             conn = conn, x_name = "form_fiss_site")
  readwritesqlite::rws_disconnect(conn)
  # remove the object to avoid issues if something breaks
  rm(form_fiss_site_clean_times)
}



## Load PSCIS spreadsheets -------------------------------------------------

# For now, import data and build tables we for reporting
pscis_list <- fpr::fpr_import_pscis_all()
pscis_phase1 <- pscis_list |> purrr::pluck('pscis_phase1')
pscis_phase2 <- pscis_list |> purrr::pluck('pscis_phase2') |>
  dplyr::arrange(pscis_crossing_id)
pscis_reassessments <- pscis_list |> purrr::pluck('pscis_reassessments')
pscis_all_prep <- pscis_list |>
  dplyr::bind_rows()



# Used in many other parts of the script
pscis_all <- dplyr::left_join(
  pscis_all_prep,
  xref_pscis_my_crossing_modelled,
  by = c('my_crossing_reference' = 'external_crossing_reference')
) |>
  dplyr::mutate(pscis_crossing_id = dplyr::case_when(
    is.na(pscis_crossing_id) ~ as.numeric(stream_crossing_id),
    TRUE ~ pscis_crossing_id
  )) |>
  dplyr::arrange(pscis_crossing_id)


## Load fish data -------------------------------------------------

fish_data_complete <- readr::read_csv(file = path_fish_tags_joined) |>
  janitor::clean_names() |>
  #filter for peace 2024
  dplyr::filter(project_name == project)


# Bcfishpass modelling table setup for reporting --------------------------

# 1. if you want salmon modelling (used for skeena and fraser) then use the following:
# xref_bcfishpass_names <- fpr::fpr_xref_crossings

# 2. if you want bull trout modelling (peace) then use the following:
# (the one used in `fpr::fpr_xref_crossings` is for salmon (does not include bull trout) so use a hard coded tribble for this project)

xref_bcfishpass_names <- tibble::tribble(
  ~bcfishpass,                                                        ~report, ~id_join, ~id_side,                                                                                                                                                                                                                                          ~column_comment,
  "aggregated_crossings_id",                                      "Aggregated Crossings Id",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "all_rearing_belowupstrbarriers_km",                              "All Rearing Below Barriers (km)",       NA,       NA,                                                                                                             "Length of stream upstream of point and below any additional upstream barriers, modelled as potential rearing habitat (all CH,CO,SK,ST,WCT)",
  "all_rearing_km",                                             "All Rearing (km)",       NA,       NA,                                                                          "Length of stream upstream of point and below any additional upstream barriers, modelled as potential spawning habitat for all modelled species (currently BT,CH,CO,SK,ST,WCT)",
  "all_spawning_belowupstrbarriers_km",                             "All Spawning Below Barriers (km)",       NA,       NA,                                                                                                                       "Length of stream upstream of point modelled as potential rearing habitat for all modelled species (currently BT,CH,CO,SK,ST,WCT)",
  "all_spawning_km",                                            "All Spawning (km)",       NA,       NA,                                                                                                                      "Length of stream upstream of point modelled as potential spawning habitat for all modelled species (currently BT,CH,CO,SK,ST,WCT)",
  "all_spawningrearing_belowupstrbarriers_km",                     "All Spawning Rearing Below Barriers (km)",       NA,       NA,                                                                                                                                                                                           "Length of all spawning and rearing habitat upstream of point",
  "all_spawningrearing_km",                                    "All Spawning Rearing (km)",       NA,       NA,                                                                                                                                                                                           "Length of all spawning and rearing habitat upstream of point",
  "all_spawningrearing_per_barrier",                             "All Spawning Rearing Per Barrier",       NA,       NA, "If the given barrier and all barriers downstream were remediated, the amount of connected spawning/rearing habitat that would be added, per barrier. (ie the sum of all_spawningrearing_belowupstrbarriers_km for all barriers, divided by n barriers)",
  "barrier_status",                                               "Barrier Status",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "barriers_anthropogenic_dnstr",                                 "Barriers Anthropogenic Dnstr",       NA,       NA,                                                                                                                                  "List of the aggregated_crossings_id values of barrier crossings downstream of the given crossing, in order downstream",
  "barriers_anthropogenic_dnstr_count",                           "Barriers Anthropogenic Dnstr Count",       NA,       NA,                                                                                                                                                                                      "A count of the barrier crossings downstream of the given crossing",
  "barriers_anthropogenic_upstr",                                 "Barriers Anthropogenic Upstr",       NA,       NA,                                                                                                                                                         "List of the aggregated_crossings_id values of barrier crossings upstream of the given crossing",
  "barriers_anthropogenic_upstr_count",                           "Barriers Anthropogenic Upstr Count",       NA,       NA,                                                                                                                                                                                        "A count of the barrier crossings upstream of the given crossing",
  "barriers_bt_dnstr",                                            "Barriers BT Dnstr",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "barriers_ch_cm_co_pk_sk_dnstr",                               "Barriers CH  Cm CO Pk SK Dnstr",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "barriers_st_dnstr",                                            "Barriers ST Dnstr",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "barriers_wct_dnstr",                                           "Barriers WCT Dnstr",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "blue_line_key",                                                "Blue Line Key",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "bt_belowupstrbarriers_lakereservoir_ha",                        "BT Below Barriers Lake Reservoir (ha)",       50,       2L,                                                                                                                  "Bull Trout model, total area lakes and reservoirs potentially accessible upstream of point and below any additional upstream barriers",
  "bt_belowupstrbarriers_network_km",                               "BT Below Barriers Network (km)",       30,       2L,                                                                                                                   "Bull Trout model, total length of stream network potentially accessible upstream of point and below any additional upstream barriers",
  "bt_belowupstrbarriers_slopeclass03_km",                          "BT Below Barriers Slopeclass03 (km)",       70,       2L,                                                                                                                "Bull Trout model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 0-3%",
  "bt_belowupstrbarriers_slopeclass03_waterbodies_km",              "BT Below Barriers Slopeclass03 Waterbodies (km)",       NA,       NA,                                                                                    "Bull Trout model, length of stream connectors (in waterbodies) potentially accessible upstream of point and below any additional upstream barriers, with slope 0-3%",
  "bt_belowupstrbarriers_slopeclass05_km",                          "BT Below Barriers Slopeclass05 (km)",       80,       2L,                                                                                                                "Bull Trout model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 3-5%",
  "bt_belowupstrbarriers_slopeclass08_km",                          "BT Below Barriers Slopeclass08 (km)",       90,       2L,                                                                                                                "Bull Trout model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 5-8%",
  "bt_belowupstrbarriers_slopeclass15_km",                          "BT Below Barriers Slopeclass15 (km)",      100,       2L,                                                                                                               "Bull Trout model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 8-15%",
  "bt_belowupstrbarriers_slopeclass22_km",                          "BT Below Barriers Slopeclass22 (km)",       NA,       NA,                                                                                                              "Bull Trout model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 15-22%",
  "bt_belowupstrbarriers_slopeclass30_km",                          "BT Below Barriers Slopeclass30 (km)",       NA,       NA,                                                                                                              "Bull Trout model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 22-30%",
  "bt_belowupstrbarriers_stream_km",                                "BT Below Barriers Stream (km)",       40,       2L,                                                            "Bull Trout model, total length of streams and rivers potentially accessible upstream of point and below any additional upstream barriers (does not include network connectors in lakes etc)",
  "bt_belowupstrbarriers_wetland_ha",                               "BT Below Barriers Wetland (ha)",       60,       2L,                                                                                                                              "Bull Trout model, total area wetlands potentially accessible upstream of point and below any additional upstream barriers",
  "bt_lakereservoir_ha",                                       "BT Lake Reservoir (ha)",       50,       1L,                                                                                                                                                            "Bull Trout model, total area lakes and reservoirs potentially accessible upstream of point ",
  "bt_network_km",                                              "BT Network (km)",       30,       1L,                                                                                                                                                              "Bull Trout model, total length of stream network potentially accessible upstream of point",
  "bt_rearing_belowupstrbarriers_km",                               "BT Rearing Below Barriers (km)",       10,       2L,                                                                                                                        "Length of stream upstream of point and below any additional upstream barriers, modelled as potential Bull Trout rearing habitat",
  "bt_rearing_km",                                              "BT Rearing (km)",       10,       1L,                                                                                                                                                                    "Length of stream upstream of point modelled as potential Bull Trout rearing habitat",
  "bt_slopeclass03_km",                                         "BT Slopeclass03 (km)",       70,       1L,                                                                                                                                                            "Bull Trout model, length of stream potentially accessible upstream of point with slope 0-3%",
  "bt_slopeclass03_waterbodies_km",                             "BT Slopeclass03 Waterbodies (km)",       NA,       NA,                                                                                                                                "Bull Trout model, length of stream connectors (in waterbodies) potentially accessible upstream of point with slope 0-3%",
  "bt_slopeclass05_km",                                         "BT Slopeclass05 (km)",       80,       1L,                                                                                                                                                            "Bull Trout model, length of stream potentially accessible upstream of point with slope 3-5%",
  "bt_slopeclass08_km",                                         "BT Slopeclass08 (km)",       90,       1L,                                                                                                                                                            "Bull Trout model, length of stream potentially accessible upstream of point with slope 5-8%",
  "bt_slopeclass15_km",                                         "BT Slopeclass15 (km)",      100,       1L,                                                                                                                                                           "Bull Trout model, length of stream potentially accessible upstream of point with slope 8-15%",
  "bt_slopeclass22_km",                                         "BT Slopeclass22 (km)",       NA,       NA,                                                                                                                                                          "Bull Trout model, length of stream potentially accessible upstream of point with slope 15-22%",
  "bt_slopeclass30_km",                                         "BT Slopeclass30 (km)",       NA,       NA,                                                                                                                                                          "Bull Trout model, length of stream potentially accessible upstream of point with slope 22-30%",
  "bt_spawning_belowupstrbarriers_km",                              "BT Spawning Below Barriers (km)",       20,       2L,                                                                                                                       "Length of stream upstream of point and below any additional upstream barriers, modelled as potential Bull Trout spawning habitat",
  "bt_spawning_km",                                             "BT Spawning (km)",       20,       1L,                                                                                                                                                                   "Length of stream upstream of point modelled as potential Bull Trout spawning habitat",
  "bt_stream_km",                                               "BT Stream (km)",       40,       1L,                                                                                                      "Bull Trout model, total length of streams and rivers potentially accessible upstream of point  (does not include network connectors in lakes etc)",
  "bt_wetland_ha",                                              "BT Wetland (ha)",       60,       1L,                                                                                                                                                                        "Bull Trout model, total area wetlands potentially accessible upstream of point ",
  "ch_cm_co_pk_sk_belowupstrbarriers_lakereservoir_ha",           "CH  Cm CO Pk SK Below Barriers Lake Reservoir (ha)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_belowupstrbarriers_network_km",                  "CH  Cm CO Pk SK Below Barriers Network (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_belowupstrbarriers_slopeclass03_km",             "CH  Cm CO Pk SK Below Barriers Slopeclass03 (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_belowupstrbarriers_slopeclass03_waterbodies_km", "CH  Cm CO Pk SK Below Barriers Slopeclass03 Waterbodies (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_belowupstrbarriers_slopeclass05_km",             "CH  Cm CO Pk SK Below Barriers Slopeclass05 (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_belowupstrbarriers_slopeclass08_km",             "CH  Cm CO Pk SK Below Barriers Slopeclass08 (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_belowupstrbarriers_slopeclass15_km",             "CH  Cm CO Pk SK Below Barriers Slopeclass15 (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_belowupstrbarriers_slopeclass22_km",             "CH  Cm CO Pk SK Below Barriers Slopeclass22 (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_belowupstrbarriers_slopeclass30_km",             "CH  Cm CO Pk SK Below Barriers Slopeclass30 (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_belowupstrbarriers_stream_km",                   "CH  Cm CO Pk SK Below Barriers Stream (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_belowupstrbarriers_wetland_ha",                  "CH  Cm CO Pk SK Below Barriers Wetland (ha)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_lakereservoir_ha",                          "CH  Cm CO Pk SK Lake Reservoir (ha)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_network_km",                                 "CH  Cm CO Pk SK Network (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_slopeclass03_km",                            "CH  Cm CO Pk SK Slopeclass03 (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_slopeclass03_waterbodies_km",                "CH  Cm CO Pk SK Slopeclass03 Waterbodies (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_slopeclass05_km",                            "CH  Cm CO Pk SK Slopeclass05 (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_slopeclass08_km",                            "CH  Cm CO Pk SK Slopeclass08 (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_slopeclass15_km",                            "CH  Cm CO Pk SK Slopeclass15 (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_slopeclass22_km",                            "CH  Cm CO Pk SK Slopeclass22 (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_slopeclass30_km",                            "CH  Cm CO Pk SK Slopeclass30 (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_stream_km",                                  "CH  Cm CO Pk SK Stream (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_cm_co_pk_sk_wetland_ha",                                 "CH  Cm CO Pk SK Wetland (ha)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ch_rearing_belowupstrbarriers_km",                              "CH  Rearing Below Barriers (km)",       NA,       NA,                                                                                                                           "Length of stream upstream of point and below any additional upstream barriers, modelled as potential Chinook rearing habitat",
  "ch_rearing_km",                                             "CH  Rearing (km)",       NA,       NA,                                                                                                                                                                       "Length of stream upstream of point modelled as potential Chinook rearing habitat",
  "ch_spawning_belowupstrbarriers_km",                             "CH  Spawning Below Barriers (km)",       NA,       NA,                                                                                                                          "Length of stream upstream of point and below any additional upstream barriers, modelled as potential Chinook spawning habitat",
  "ch_spawning_km",                                            "CH  Spawning (km)",       NA,       NA,                                                                                                                                                                      "Length of stream upstream of point modelled as potential Chinook spawning habitat",
  "cm_spawning_belowupstrbarriers_km",                              "Cm Spawning Below Barriers (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "cm_spawning_km",                                             "Cm Spawning (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "co_rearing_belowupstrbarriers_ha",                               "CO Rearing Below Barriers (ha)",       NA,       NA,                                                                                                                              "Area of wetlands upstream of point and below any additional upstream barriers, modelled as potential Coho rearing habitat",
  "co_rearing_belowupstrbarriers_km",                               "CO Rearing Below Barriers (km)",       NA,       NA,                                                                                                                              "Length of stream upstream of point and below any additional upstream barriers, modelled as potential Coho rearing habitat",
  "co_rearing_ha",                                              "CO Rearing (ha)",       NA,       NA,                                                                                                                                                                          "Area of wetlands upstream of point modelled as potential Coho rearing habitat",
  "co_rearing_km",                                              "CO Rearing (km)",       NA,       NA,                                                                                                                                                                          "Length of stream upstream of point modelled as potential Coho rearing habitat",
  "co_spawning_belowupstrbarriers_km",                              "CO Spawning Below Barriers (km)",       NA,       NA,                                                                                                                             "Length of stream upstream of point and below any additional upstream barriers, modelled as potential Coho spawning habitat",
  "co_spawning_km",                                             "CO Spawning (km)",       NA,       NA,                                                                                                                                                                         "Length of stream upstream of point modelled as potential Coho spawning habitat",
  "crossing_feature_type",                                        "Crossing Feature Type",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "crossing_source",                                              "Crossing Source",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "crossing_subtype_code",                                        "Crossing Subtype Code",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "crossing_type_code",                                           "Crossing Type Code",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "crossings_dnstr",                                              "Crossings Dnstr",       NA,       NA,                                                                                                                                          "List of the aggregated_crossings_id values of crossings downstream of the given crossing, in order downstream",
  "dam_height",                                                   "Dam Height",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "dam_id",                                                       "Dam Id",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "dam_name",                                                     "Dam Name",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "dam_operating_status",                                         "Dam Operating Status",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "dam_owner",                                                    "Dam Owner",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "dam_use",                                                      "Dam Use",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "dbm_mof_50k_grid",                                             "Dbm Mof 50k Grid",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "downstream_route_measure",                                     "Downstream Route Measure",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ften_client_name",                                             "Ften Client Name",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ften_client_number",                                           "Ften Client Number",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ften_file_type_description",                                   "Ften File Type Description",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ften_forest_file_id",                                          "Ften Forest File Id",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ften_life_cycle_status_code",                                  "Ften Life Cycle Status Code",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "gnis_stream_name",                                             "Gnis Stream Name",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "gradient",                                                     "Gradient",       NA,       NA,                                                                                                                                                                                                                                  "Stream slope at point",
  "linear_feature_id",                                            "Linear Feature Id",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "localcode_ltree",                                              "Localcode Ltree",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "modelled_crossing_id",                                         "Modelled Crossing Id",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "modelled_crossing_type_source",                                "Modelled Crossing Type Source",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "observedspp_dnstr",                                            "Observedspp Dnstr",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "observedspp_upstr",                                            "Observedspp Upstr",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "ogc_proponent",                                                "Ogc Proponent",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "pk_spawning_belowupstrbarriers_km",                              "Pk Spawning Below Barriers (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "pk_spawning_km",                                             "Pk Spawning (km)",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "pscis_assessment_comment",                                     "PSCIS Assessment Comment",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "pscis_assessment_date",                                        "PSCIS Assessment Date",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "pscis_final_score",                                            "PSCIS Final Score",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "pscis_road_name",                                              "PSCIS Road Name",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "pscis_status",                                                 "PSCIS Status",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "pscis_stream_name",                                            "PSCIS Stream Name",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "rail_operator_english_name",                                   "Rail Operator English Name",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "rail_owner_name",                                              "Rail Owner Name",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "rail_track_name",                                              "Rail Track Name",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "sk_rearing_belowupstrbarriers_ha",                               "SK Rearing Below Barriers (ha)",       NA,       NA,                                                                                                                              "Area of lakes upstream of point and below any additional upstream barriers, modelled as potential Sockeye rearing habitat",
  "sk_rearing_belowupstrbarriers_km",                               "SK Rearing Below Barriers (km)",       NA,       NA,                                                                                                                           "Length of stream upstream of point and below any additional upstream barriers, modelled as potential Sockeye rearing habitat",
  "sk_rearing_ha",                                              "SK Rearing (ha)",       NA,       NA,                                                                                                                                                                          "Area of lakes upstream of point modelled as potential Sockeye rearing habitat",
  "sk_rearing_km",                                              "SK Rearing (km)",       NA,       NA,                                                                                                                                                                       "Length of stream upstream of point modelled as potential Sockeye rearing habitat",
  "sk_spawning_belowupstrbarriers_km",                              "SK Spawning Below Barriers (km)",       NA,       NA,                                                                                                                          "Length of stream upstream of point and below any additional upstream barriers, modelled as potential Sockeye spawning habitat",
  "sk_spawning_km",                                             "SK Spawning (km)",       NA,       NA,                                                                                                                                                                      "Length of stream upstream of point modelled as potential Sockeye spawning habitat",
  "st_belowupstrbarriers_lakereservoir_ha",                        "ST Below Barriers Lake Reservoir (ha)",       NA,       NA,                                                                                                                   "Steelhead model, total area lakes and reservoirs potentially accessible upstream of point and below any additional upstream barriers",
  "st_belowupstrbarriers_network_km",                               "ST Below Barriers Network (km)",       NA,       NA,                                                                                                                    "Steelhead model, total length of stream network potentially accessible upstream of point and below any additional upstream barriers",
  "st_belowupstrbarriers_slopeclass03_km",                          "ST Below Barriers Slopeclass03 (km)",       NA,       NA,                                                                                                                 "Steelhead model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 0-3%",
  "st_belowupstrbarriers_slopeclass03_waterbodies_km",              "ST Below Barriers Slopeclass03 Waterbodies (km)",       NA,       NA,                                                                                     "Steelhead model, length of stream connectors (in waterbodies) potentially accessible upstream of point and below any additional upstream barriers, with slope 0-3%",
  "st_belowupstrbarriers_slopeclass05_km",                          "ST Below Barriers Slopeclass05 (km)",       NA,       NA,                                                                                                                 "Steelhead model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 3-5%",
  "st_belowupstrbarriers_slopeclass08_km",                          "ST Below Barriers Slopeclass08 (km)",       NA,       NA,                                                                                                                 "Steelhead model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 5-8%",
  "st_belowupstrbarriers_slopeclass15_km",                          "ST Below Barriers Slopeclass15 (km)",       NA,       NA,                                                                                                                "Steelhead model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 8-15%",
  "st_belowupstrbarriers_slopeclass22_km",                          "ST Below Barriers Slopeclass22 (km)",       NA,       NA,                                                                                                               "Steelhead model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 15-22%",
  "st_belowupstrbarriers_slopeclass30_km",                          "ST Below Barriers Slopeclass30 (km)",       NA,       NA,                                                                                                               "Steelhead model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 22-30%",
  "st_belowupstrbarriers_stream_km",                                "ST Below Barriers Stream (km)",       NA,       NA,                                                             "Steelhead model, total length of streams and rivers potentially accessible upstream of point and below any additional upstream barriers (does not include network connectors in lakes etc)",
  "st_belowupstrbarriers_wetland_ha",                               "ST Below Barriers Wetland (ha)",       NA,       NA,                                                                                                                               "Steelhead model, total area wetlands potentially accessible upstream of point and below any additional upstream barriers",
  "st_lakereservoir_ha",                                       "ST Lake Reservoir (ha)",       NA,       NA,                                                                                                                                                             "Steelhead model, total area lakes and reservoirs potentially accessible upstream of point ",
  "st_network_km",                                              "ST Network (km)",       NA,       NA,                                                                                                                                                               "Steelhead model, total length of stream network potentially accessible upstream of point",
  "st_rearing_belowupstrbarriers_km",                               "ST Rearing Below Barriers (km)",       NA,       NA,                                                                                                                         "Length of stream upstream of point and below any additional upstream barriers, modelled as potential Steelhead rearing habitat",
  "st_rearing_km",                                              "ST Rearing (km)",       NA,       NA,                                                                                                                                                                     "Length of stream upstream of point modelled as potential Steelhead rearing habitat",
  "st_slopeclass03_km",                                         "ST Slopeclass03 (km)",       NA,       NA,                                                                                                                                                             "Steelhead model, length of stream potentially accessible upstream of point with slope 0-3%",
  "st_slopeclass03_waterbodies_km",                             "ST Slopeclass03 Waterbodies (km)",       NA,       NA,                                                                                                                                 "Steelhead model, length of stream connectors (in waterbodies) potentially accessible upstream of point with slope 0-3%",
  "st_slopeclass05_km",                                         "ST Slopeclass05 (km)",       NA,       NA,                                                                                                                                                             "Steelhead model, length of stream potentially accessible upstream of point with slope 3-5%",
  "st_slopeclass08_km",                                         "ST Slopeclass08 (km)",       NA,       NA,                                                                                                                                                             "Steelhead model, length of stream potentially accessible upstream of point with slope 5-8%",
  "st_slopeclass15_km",                                         "ST Slopeclass15 (km)",       NA,       NA,                                                                                                                                                            "Steelhead model, length of stream potentially accessible upstream of point with slope 8-15%",
  "st_slopeclass22_km",                                         "ST Slopeclass22 (km)",       NA,       NA,                                                                                                                                                           "Steelhead model, length of stream potentially accessible upstream of point with slope 15-22%",
  "st_slopeclass30_km",                                         "ST Slopeclass30 (km)",       NA,       NA,                                                                                                                                                           "Steelhead model, length of stream potentially accessible upstream of point with slope 22-30%",
  "st_spawning_belowupstrbarriers_km",                              "ST Spawning Below Barriers (km)",       NA,       NA,                                                                                                                        "Length of stream upstream of point and below any additional upstream barriers, modelled as potential Steelhead spawning habitat",
  "st_spawning_km",                                             "ST Spawning (km)",       NA,       NA,                                                                                                                                                                    "Length of stream upstream of point modelled as potential Steelhead spawning habitat",
  "st_stream_km",                                               "ST Stream (km)",       NA,       NA,                                                                                                       "Steelhead model, total length of streams and rivers potentially accessible upstream of point  (does not include network connectors in lakes etc)",
  "st_wetland_ha",                                              "ST Wetland (ha)",       NA,       NA,                                                                                                                                                                         "Steelhead model, total area wetlands potentially accessible upstream of point ",
  "stream_crossing_id",                                           "Stream Crossing Id",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "stream_magnitude",                                             "Stream Magnitude",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "stream_order",                                                 "Stream Order",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "total_belowupstrbarriers_lakereservoir_ha",                     "Total Below Barriers Lake Reservoir (ha)",       NA,       NA,                                                                                                                                    "Total area lakes and reservoirs potentially accessible upstream of point and below any additional upstream barriers",
  "total_belowupstrbarriers_network_km",                            "Total Below Barriers Network (km)",       NA,       NA,                                                                                                                                     "Total length of stream network potentially accessible upstream of point and below any additional upstream barriers",
  "total_belowupstrbarriers_slopeclass03_km",                       "Total Below Barriers Slopeclass03 (km)",       NA,       NA,                                                                                                                            "Total length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 0-3%",
  "total_belowupstrbarriers_slopeclass03_waterbodies_km",           "Total Below Barriers Slopeclass03 Waterbodies (km)",       NA,       NA,                                                                                                "Total length of stream connectors (in waterbodies) potentially accessible upstream of point and below any additional upstream barriers, with slope 0-3%",
  "total_belowupstrbarriers_slopeclass05_km",                       "Total Below Barriers Slopeclass05 (km)",       NA,       NA,                                                                                                                            "Total length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 3-5%",
  "total_belowupstrbarriers_slopeclass08_km",                       "Total Below Barriers Slopeclass08 (km)",       NA,       NA,                                                                                                                            "Total length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 5-8%",
  "total_belowupstrbarriers_slopeclass15_km",                       "Total Below Barriers Slopeclass15 (km)",       NA,       NA,                                                                                                                           "Total length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 8-15%",
  "total_belowupstrbarriers_slopeclass22_km",                       "Total Below Barriers Slopeclass22 (km)",       NA,       NA,                                                                                                                          "Total length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 15-22%",
  "total_belowupstrbarriers_slopeclass30_km",                       "Total Below Barriers Slopeclass30 (km)",       NA,       NA,                                                                                                                          "Total length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 22-30%",
  "total_belowupstrbarriers_stream_km",                             "Total Below Barriers Stream (km)",       NA,       NA,                                                                              "Total length of streams and rivers potentially accessible upstream of point and below any additional upstream barriers (does not include network connectors in lakes etc)",
  "total_belowupstrbarriers_wetland_ha",                            "Total Below Barriers Wetland (ha)",       NA,       NA,                                                                                                                                                "Total area wetlands potentially accessible upstream of point and below any additional upstream barriers",
  "total_lakereservoir_ha",                                    "Total Lake Reservoir (ha)",       NA,       NA,                                                                                                                                                                                                     "Total area lakes and reservoirs upstream of point ",
  "total_network_km",                                           "Total Network (km)",       NA,       NA,                                                                                                                                                                                                       "Total length of stream network upstream of point",
  "total_slopeclass03_km",                                      "Total Slopeclass03 (km)",       NA,       NA,                                                                                                                                                                        "Total length of stream potentially accessible upstream of point with slope 0-3%",
  "total_slopeclass03_waterbodies_km",                          "Total Slopeclass03 Waterbodies (km)",       NA,       NA,                                                                                                                                            "Total length of stream connectors (in waterbodies) potentially accessible upstream of point with slope 0-3%",
  "total_slopeclass05_km",                                      "Total Slopeclass05 (km)",       NA,       NA,                                                                                                                                                                        "Total length of stream potentially accessible upstream of point with slope 3-5%",
  "total_slopeclass08_km",                                      "Total Slopeclass08 (km)",       NA,       NA,                                                                                                                                                                        "Total length of stream potentially accessible upstream of point with slope 5-8%",
  "total_slopeclass15_km",                                      "Total Slopeclass15 (km)",       NA,       NA,                                                                                                                                                                       "Total length of stream potentially accessible upstream of point with slope 8-15%",
  "total_slopeclass22_km",                                      "Total Slopeclass22 (km)",       NA,       NA,                                                                                                                                                                      "Total length of stream potentially accessible upstream of point with slope 15-22%",
  "total_slopeclass30_km",                                      "Total Slopeclass30 (km)",       NA,       NA,                                                                                                                                                                      "Total length of stream potentially accessible upstream of point with slope 22-30%",
  "total_stream_km",                                            "Total Stream (km)",       NA,       NA,                                                                                                                                                "Total length of streams and rivers upstream of point (does not include network connectors in lakes etc)",
  "total_wetland_ha",                                           "Total Wetland (ha)",       NA,       NA,                                                                                                                                                                                                                 "Total area wetlands upstream of point ",
  "transport_line_structured_name_1",                             "Transport Line Structured Name 1",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "transport_line_surface_description",                           "Transport Line Surface Description",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "transport_line_type_description",                              "Transport Line Type Description",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "user_barrier_anthropogenic_id",                                "User Barrier Anthropogenic Id",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "utm_easting",                                                  "Utm Easting",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "utm_northing",                                                 "Utm Northing",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "utm_zone",                                                     "Utm Zone",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "watershed_group_code",                                         "Watershed Group Code",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "watershed_key",                                                "Watershed Key",       NA,       NA,                                                                                                                                                                                                                                                       NA,
  "wct_belowupstrbarriers_lakereservoir_ha",                       "WCT Below Barriers Lake Reservoir (ha)",       NA,       NA,                                                                                                   "Westslope Cutthroat Trout model, total area lakes and reservoirs potentially accessible upstream of point and below any additional upstream barriers",
  "wct_belowupstrbarriers_network_km",                              "WCT Below Barriers Network (km)",       NA,       NA,                                                                                                    "Westslope Cutthroat Trout model, total length of stream network potentially accessible upstream of point and below any additional upstream barriers",
  "wct_belowupstrbarriers_slopeclass03_km",                         "WCT Below Barriers Slopeclass03 (km)",       NA,       NA,                                                                                                 "Westslope Cutthroat Trout model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 0-3%",
  "wct_belowupstrbarriers_slopeclass03_waterbodies_km",             "WCT Below Barriers Slopeclass03 Waterbodies (km)",       NA,       NA,                                                                     "Westslope Cutthroat Trout model, length of stream connectors (in waterbodies) potentially accessible upstream of point and below any additional upstream barriers, with slope 0-3%",
  "wct_belowupstrbarriers_slopeclass05_km",                         "WCT Below Barriers Slopeclass05 (km)",       NA,       NA,                                                                                                 "Westslope Cutthroat Trout model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 3-5%",
  "wct_belowupstrbarriers_slopeclass08_km",                         "WCT Below Barriers Slopeclass08 (km)",       NA,       NA,                                                                                                 "Westslope Cutthroat Trout model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 5-8%",
  "wct_belowupstrbarriers_slopeclass15_km",                         "WCT Below Barriers Slopeclass15 (km)",       NA,       NA,                                                                                                "Westslope Cutthroat Trout model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 8-15%",
  "wct_belowupstrbarriers_slopeclass22_km",                         "WCT Below Barriers Slopeclass22 (km)",       NA,       NA,                                                                                               "Westslope Cutthroat Trout model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 15-22%",
  "wct_belowupstrbarriers_slopeclass30_km",                         "WCT Below Barriers Slopeclass30 (km)",       NA,       NA,                                                                                               "Westslope Cutthroat Trout model, length of stream potentially accessible upstream of point and below any additional upstream barriers, with slope 22-30%",
  "wct_belowupstrbarriers_stream_km",                               "WCT Below Barriers Stream (km)",       NA,       NA,                                              "Westslope Cuthroat Trout model, total length of streams and rivers potentially accessible upstream of point and below any additional upstream barriers (does not include network connectors in lakes etc)",
  "wct_belowupstrbarriers_wetland_ha",                              "WCT Below Barriers Wetland (ha)",       NA,       NA,                                                                                                               "Westslope Cutthroat Trout model, total area wetlands potentially accessible upstream of point and below any additional upstream barriers",
  "wct_betweenbarriers_network_km",                            "WCT Between Barriers Network (km)",       NA,       NA,                                                                                                            "Westslope Cutthroat Trout model, total length of potentially accessible stream network between crossing and all in-stream adjacent barriers",
  "wct_lakereservoir_ha",                                      "WCT Lake Reservoir (ha)",       NA,       NA,                                                                                                                                              "Westslope Cuthroat Trout model, total area lakes and reservoirs potentially accessible upstream of point ",
  "wct_network_km",                                             "WCT Network (km)",       NA,       NA,                                                                                                                                                "Westslope Cuthroat Trout model, total length of stream network potentially accessible upstream of point",
  "wct_rearing_belowupstrbarriers_km",                              "WCT Rearing Below Barriers (km)",       NA,       NA,                                                                                                               "Length of stream upstream of point and below any additional upstream barriers, modelled as potential Westslope Cutthroat rearing habitat",
  "wct_rearing_betweenbarriers_km",                            "WCT Rearing Between Barriers (km)",       NA,       NA,                                                                                                                                  "Westslope Cutthroat Trout model, total length of rearing habitat between crossing and all in-stream adjacent barriers",
  "wct_rearing_km",                                             "WCT Rearing (km)",       NA,       NA,                                                                                                                                                           "Length of stream upstream of point modelled as potential Westslope Cutthroat rearing habitat",
  "wct_slopeclass03_km",                                        "WCT Slopeclass03 (km)",       NA,       NA,                                                                                                                                             "Westslope Cutthroat Trout model, length of stream potentially accessible upstream of point with slope 0-3%",
  "wct_slopeclass03_waterbodies_km",                            "WCT Slopeclass03 Waterbodies (km)",       NA,       NA,                                                                                                                 "Westslope Cutthroat Trout model, length of stream connectors (in waterbodies) potentially accessible upstream of point with slope 0-3%",
  "wct_slopeclass05_km",                                        "WCT Slopeclass05 (km)",       NA,       NA,                                                                                                                                             "Westslope Cutthroat Trout model, length of stream potentially accessible upstream of point with slope 3-5%",
  "wct_slopeclass08_km",                                        "WCT Slopeclass08 (km)",       NA,       NA,                                                                                                                                             "Westslope Cutthroat Trout model, length of stream potentially accessible upstream of point with slope 5-8%",
  "wct_slopeclass15_km",                                        "WCT Slopeclass15 (km)",       NA,       NA,                                                                                                                                            "Westslope Cutthroat Trout model, length of stream potentially accessible upstream of point with slope 8-15%",
  "wct_slopeclass22_km",                                        "WCT Slopeclass22 (km)",       NA,       NA,                                                                                                                                           "Westslope Cutthroat Trout model, length of stream potentially accessible upstream of point with slope 15-22%",
  "wct_slopeclass30_km",                                        "WCT Slopeclass30 (km)",       NA,       NA,                                                                                                                                           "Westslope Cutthroat Trout model, length of stream potentially accessible upstream of point with slope 22-30%",
  "wct_spawning_belowupstrbarriers_km",                             "WCT Spawning Below Barriers (km)",       NA,       NA,                                                                                                              "Length of stream upstream of point and below any additional upstream barriers, modelled as potential Westslope Cutthroat spawning habitat",
  "wct_spawning_betweenbarriers_km",                           "WCT Spawning Between Barriers (km)",       NA,       NA,                                                                                                                                 "Westslope Cutthroat Trout model, total length of spawning habitat between crossing and all in-stream adjacent barriers",
  "wct_spawning_km",                                            "WCT Spawning (km)",       NA,       NA,                                                                                                                                                          "Length of stream upstream of point modelled as potential Westslope Cutthroat spawning habitat",
  "wct_spawningrearing_betweenbarriers_km",                   "WCT Spawning Rearing Between Barriers (km)",       NA,       NA,                                                                                                                     "Westslope Cutthroat Trout model, total length of spawning and rearing habitat between crossing and all in-stream adjacent barriers",
  "wct_stream_km",                                              "WCT Stream (km)",       NA,       NA,                                                                                        "Westslope Cuthroat Trout model, total length of streams and rivers potentially accessible upstream of point  (does not include network connectors in lakes etc)",
  "wct_wetland_ha",                                             "WCT Wetland (ha)",       NA,       NA,                                                                                                                                                          "Westslope Cuthroat Trout model, total area wetlands potentially accessible upstream of point ",
  "wscode_ltree",                                                 "Wscode Ltree",       NA,       NA,                                                                                                                                                                                                                                                       NA

)



# Habitat Summaries -------------------------------------------------

## Build hab_site object for fpr_my_habitat_info() ------------------
hab_site <- form_fiss_site


## Build tab_hab_summary object for tables --------------------------

tab_hab_summary <- form_fiss_site |>
  dplyr::filter(is.na(ef)) |>
  dplyr::select(local_name,
           site,
           location,
           avg_channel_width_m,
           avg_wetted_width_m,
           average_residual_pool_depth_m,
           average_gradient_percent,
           total_cover,
           site_length,
           habitat_value_rating) |>
  dplyr::mutate(location = dplyr::case_when(location == "us" ~ stringr::str_replace_all(location, 'us', 'Upstream'),
    TRUE ~ stringr::str_replace_all(location, 'ds', 'Downstream')
    )) |>
  dplyr::arrange(site, location) |>
  dplyr::select(Site = site,
         Location = location,
         `Length Surveyed (m)` = site_length,
         `Average Channel Width (m)` = avg_channel_width_m,
         `Average Wetted Width (m)` = avg_wetted_width_m,
         `Average Pool Depth (m)` = average_residual_pool_depth_m,
         `Average Gradient (%)` = average_gradient_percent,
         `Total Cover` = total_cover,
         `Habitat Value` = habitat_value_rating)



# Phase 1 Appendix ----------------------------------------------

## make result summary tables for each of the crossings, used to display phase 1 data in the appendix

## turn spreadsheet into list of data frames
pscis_phase1_for_tables <- pscis_all |>
  dplyr::filter(!source == "pscis_phase2.xlsm") |>
  dplyr::arrange(pscis_crossing_id)

pscis_split <- pscis_phase1_for_tables  |>
  dplyr::group_split(pscis_crossing_id) |>
  purrr::set_names(pscis_phase1_for_tables$pscis_crossing_id)


##make result summary tables for each of the crossings
tab_summary <- pscis_split |>
  purrr::map(fpr::fpr_table_cv_detailed)

tab_summary_comments <- pscis_split |>
  purrr::map(fpr::fpr_table_cv_detailed_comments)


tab_photo_url <- fs::dir_ls(path = "data/photos/", recurse = FALSE) |>
  basename() |>
  tibble::as_tibble() |>
  dplyr::mutate(value = as.integer(value)) |>  # Convert filenames to integers for sorting
  dplyr::arrange(value) |>
  dplyr::mutate(photo = paste0("![](data/photos/", value, "/crossing_all.JPG)")) |>
  dplyr::filter(value %in% pscis_phase1_for_tables$site_id) |>
  dplyr::left_join(xref_pscis_my_crossing_modelled,
                   by = c("value" = "external_crossing_reference")) |>
  dplyr::mutate(stream_crossing_id = dplyr::case_when(
    is.na(stream_crossing_id) ~ value,
    TRUE ~ stream_crossing_id
  )) |>
  dplyr::arrange(stream_crossing_id) |>
  dplyr::group_split(stream_crossing_id)


# used to build tables for PDF version of the report
tabs_phase1_pdf <- mapply(
  fpr::fpr_table_cv_detailed_print,
  tab_sum = tab_summary,
  comments = tab_summary_comments,
  photos = tab_photo_url,
  gitbook_switch = FALSE)


rm(pscis_phase1_for_tables,pscis_split)


# Phase 2 Priority spreadsheet ----------------------------------------------

# Read priority spreadsheet
# spreadsheet that includes site lengths, surveyors initials, time, priority for remediation, updated fish species (if changed from my_fish_sp())

# read in the object
habitat_confirmations_priorities <- readr::read_csv(
  file = "data/habitat_confirmations_priorities.csv")


# Phase 2 overview table ------------------------------------------

# Overview of habitat confirmation sites used in the results section

tab_overview_prep1 <- form_pscis|>
  sf::st_drop_geometry() |>
  dplyr::filter(assess_type_phase2 == "Yes") |>
  dplyr::select(pscis_crossing_id, stream_name, road_name, road_tenure, easting, northing, utm_zone, habitat_value)

tab_overview_prep2 <- habitat_confirmations_priorities|>
  dplyr::filter(location == 'us')|>
  dplyr::select(site, species_codes, upstream_habitat_length_m, priority, comments)|>
  dplyr::mutate(upstream_habitat_length_km = round(upstream_habitat_length_m/1000,1))

tab_overview <- dplyr::left_join(
  tab_overview_prep1,
  tab_overview_prep2,
  by = c('pscis_crossing_id' = 'site')
)|>
  dplyr::mutate(utm = paste0(round(easting,0), ' ', round(northing,0)))|>
  dplyr::select(`PSCIS ID` = pscis_crossing_id,
                Stream = stream_name,
                Road = road_name,
                Tenure = road_tenure,
                `UTM` = utm,
                `UTM zone` = utm_zone,
                `Fish Species` = species_codes,
                `Habitat Gain (km)` = upstream_habitat_length_km,
                `Habitat Value` = habitat_value,
                Priority = priority,
                Comments = comments )

rm(tab_overview_prep1, tab_overview_prep2)



# Fish sampling ----------------------------------------------

## Fish sampling results condensed ----------------------------------------------
# tab_fish_summary
tab_fish_summary <- fish_data_complete |>
  # exclude visual observations
  dplyr::filter(sampling_method == "electrofishing") |>
  tidyr::separate(local_name, into = c("site_id", "location", "ef")) |>
  dplyr::mutate(site_id = paste0(site_id, "_", location)) |>
  dplyr::group_by(site_id,
                  ef,
                  sampling_method,
                  species) |>
  dplyr::summarise(count_fish = n()) |>
  dplyr::arrange(site_id, species, ef)



## Fish sampling site summary ------------------------------
# `tab_fish_sites_sum` object for `fpr_table_fish_site()`
tab_fish_sites_sum <- dplyr::left_join(fish_data_complete |>
                                         dplyr::group_by(local_name) |>
                                         dplyr::mutate(pass_total = max(pass_number)) |>
                                         dplyr::ungroup() |>
                                         dplyr::select(local_name, pass_total, enclosure),
                                       form_fiss_site |>
                                         dplyr::filter(!is.na(ef)) |>
                                         dplyr::select(local_name, gazetted_names, site_length, avg_wetted_width_m) |>
                                         dplyr::mutate(gazetted_names = stringr::str_trim(gazetted_names),
                                                        gazetted_names = stringr::str_to_title(gazetted_names)) ,
                                       by = "local_name"

  ) |>
  dplyr::distinct(local_name, .keep_all = TRUE) |>
  dplyr::rename(ef_length_m = site_length, ef_width_m = avg_wetted_width_m) |>
  dplyr::mutate(area_m2 = round(ef_length_m * ef_width_m,1)) |>
  dplyr::select(site = local_name, stream = gazetted_names, passes = pass_total, ef_length_m, ef_width_m, area_m2, enclosure)


## Fish sampling density results ------------------------------
# `fish_abund` object for `fpr_table_fish_density()` and `fpr_plot_fish_box()`
fish_abund <- dplyr::left_join(
  fish_data_complete |>
    # exclude visual observations
    dplyr::filter(sampling_method == "electrofishing") |>
    # Add life_stage and pass_total
    dplyr::mutate(
      life_stage = case_when(
        length <= 65 ~ 'fry',
        length > 65 & length <= 110 ~ 'parr',
        length > 110 & length <= 140 ~ 'juvenile',
        length > 140 ~ 'adult',
        TRUE ~ NA_character_
      ),
      life_stage = case_when(
        stringr::str_like(species, '%sculpin%') ~ NA_character_,
        TRUE ~ life_stage
      ),
      # Add pass_total here
      pass_total = max(pass_number)
    ) |>
    # Group and summarize
    dplyr::group_by(local_name, species, life_stage, pass_number,pass_total) |>
    dplyr::summarise(
      catch = n(),
      .groups = "drop" # Ensures the grouping is removed after summarizing
    ) |>
    # Add nfc_pass
    dplyr::mutate(
      catch = case_when(species == 'NFC' ~ 0L, TRUE ~ catch),
      nfc_pass = case_when(
        species != 'NFC' & pass_number == pass_total ~ FALSE,
        TRUE ~ TRUE
      ),
      nfc_pass = case_when(
        species == 'NFC' ~ TRUE,
        TRUE ~ nfc_pass
      )),

  form_fiss_site |>
    dplyr::filter(!is.na(ef)) |>
    dplyr::select(local_name, site, location, site_length, avg_wetted_width_m),

  by = "local_name"
  ) |>

  dplyr::rename(ef_length_m = site_length, ef_width_m = avg_wetted_width_m, species_code = species) |>
  dplyr::mutate(area_m2 = round(ef_length_m * ef_width_m,1),
                density_100m2 = round(catch/area_m2 * 100,1)) |>
  dplyr::select(local_name, site, location, species_code, life_stage, catch, density_100m2, nfc_pass)




# Cost Estimates ------------------------------

# General preparation for cost estimates. Phase 1 and Phase 2 specific code in farther down.

# Step 1: Join the road class and surface data from `rd_class_surface` to the crossings
tab_cost_est_prep <- dplyr::left_join(
  pscis_all |>
    dplyr::select(
      pscis_crossing_id,
      my_crossing_reference,
      aggregated_crossings_id,
      stream_name,
      road_name,
      downstream_channel_width_meters,
      barrier_result,
      fill_depth_meters,
      crossing_fix,
      habitat_value,
      recommended_diameter_or_span_meters,
      source),
  rd_class_surface |>
    dplyr::select(stream_crossing_id, my_road_class, my_road_surface),
  by = c('pscis_crossing_id' = 'stream_crossing_id')
)

# Step 2: Add `pscis_crossing_id` from `xref_pscis_my_crossing_modelled`
tab_cost_est_prep1 <- dplyr::left_join(
  tab_cost_est_prep,
  xref_pscis_my_crossing_modelled |>
    dplyr::select(external_crossing_reference, stream_crossing_id) |>
    dplyr::mutate(external_crossing_reference = as.numeric(external_crossing_reference)),
  by = c('my_crossing_reference' = 'external_crossing_reference')
) |>
  dplyr::mutate(pscis_crossing_id = dplyr::case_when(
    is.na(pscis_crossing_id) ~ as.integer(stream_crossing_id),
    TRUE ~ pscis_crossing_id
  )) |>
  dplyr::select(-stream_crossing_id)

# Step 3: Join the bridge costs and embedment costs
tab_cost_est_prep2 <- dplyr::left_join(
  tab_cost_est_prep1,
  sfpr_xref_road_cost() |>
    dplyr::select(my_road_class, my_road_surface, cost_m_1000s_bridge, cost_embed_cv),
  by = c('my_road_class', 'my_road_surface')
)

# Step 4: Join the crossing fix codes
tab_cost_est_prep3 <- dplyr::left_join(
  tab_cost_est_prep2,
  dplyr::select(fpr_xref_fix, crossing_fix, crossing_fix_code),
  by = c('crossing_fix')
)

# Step 5: Calculate the cost estimates per 1000 square feet
tab_cost_est_prep4 <- tab_cost_est_prep3 |>
  dplyr::mutate(cost_est_1000s = dplyr::case_when(
    crossing_fix_code == 'SS-CBS' ~ cost_embed_cv,
    crossing_fix_code == 'OBS' ~ cost_m_1000s_bridge * recommended_diameter_or_span_meters)
  ) |>
  dplyr::mutate(cost_est_1000s = round(cost_est_1000s, 0))



## Phase 1  ------------------------------

# Now prepare phase 1 cost estimates.

sp_network_km <- rlang::sym(paste0(params$model_species, "_network_km"))
sp_belowupstrbarriers_network_km <- rlang::sym(paste0(params$model_species, "_belowupstrbarriers_network_km"))


# Step 6: Add upstream modelling data to estimate potential habitat gain
tab_cost_est_prep5 <- dplyr::left_join(
  tab_cost_est_prep4,
  bcfishpass |>
    dplyr::select(stream_crossing_id, !!sp_network_km, !!sp_belowupstrbarriers_network_km) |>
    dplyr::mutate(stream_crossing_id = as.numeric(stream_crossing_id)),
  by = c('pscis_crossing_id' = 'stream_crossing_id')
) |>
  dplyr::mutate(
    cost_net = round(!!sp_belowupstrbarriers_network_km * 1000 / cost_est_1000s, 1),
    cost_gross = round(!!sp_network_km * 1000 / cost_est_1000s, 1),
    cost_area_net = round((!!sp_belowupstrbarriers_network_km * 1000 * downstream_channel_width_meters * 0.5) / cost_est_1000s, 1),
    cost_area_gross = round((!!sp_network_km * 1000 * downstream_channel_width_meters * 0.5) / cost_est_1000s, 1),
    st_network_km = round(!!sp_network_km, 1)
  )


# Step 7: Add the priority from `form_pscis`
tab_cost_est_prep6 <- dplyr::left_join(
  tab_cost_est_prep5 |>
    # only for skeena 2024 where the road names are not capitalized in the spreadsheet because I forgot:/
    dplyr::select(-road_name),
  form_pscis |>
    dplyr::select(pscis_crossing_id, my_priority, road_name),
  by = 'pscis_crossing_id'
) |>
  dplyr::arrange(pscis_crossing_id) |>
  dplyr::select(
    pscis_crossing_id,
    my_crossing_reference,
    stream_name,
    road_name,
    barrier_result,
    habitat_value,
    sp_network_km,
    downstream_channel_width_meters,
    my_priority,
    crossing_fix_code,
    cost_est_1000s,
    cost_gross, cost_area_gross, source
  ) |>
  dplyr::filter(barrier_result != 'Unknown' & barrier_result != 'Passable')

# Step 8: Final adjustments and renaming columns
tab_cost_est_phase1 <- tab_cost_est_prep6 |>
  dplyr::rename(
    `PSCIS ID` = pscis_crossing_id,
    `External ID` = my_crossing_reference,
    Priority = my_priority,
    Stream = stream_name,
    Road = road_name,
    `Barrier Result` = barrier_result,
    `Habitat value` = habitat_value,
    `Habitat Upstream (km)` = sp_network_km,
    `Stream Width (m)` = downstream_channel_width_meters,
    Fix = crossing_fix_code,
    `Cost Est ( $K)` = cost_est_1000s,
    `Cost Benefit (m / $K)` = cost_gross,
    `Cost Benefit (m2 / $K)` = cost_area_gross
  ) |>
  dplyr::filter(!source == "pscis_phase2.xlsm") |>
  dplyr::select(-source)



## Phase 2 ------------------------------

# Now prepare phase 2 cost estimates.

# Step 1: Join habitat confirmation priorities data to upstream habitat length
tab_cost_est_prep7 <- dplyr::left_join(
  tab_cost_est_prep4,
  dplyr::select(
    dplyr::filter(habitat_confirmations_priorities, location == 'us'),
    site,
    upstream_habitat_length_m
  ),
  by = c('pscis_crossing_id' = 'site')
) |>
  dplyr::mutate(
    cost_net = round(upstream_habitat_length_m * 1000 / cost_est_1000s, 1),
    cost_area_net = round((upstream_habitat_length_m * 1000 * downstream_channel_width_meters * 0.5) / cost_est_1000s, 1) ## this is a triangle area!
  )

# Step 2: Join habitat site data for average channel width using stringr for pattern matching
tab_cost_est_prep8 <- dplyr::left_join(
  tab_cost_est_prep7,
  dplyr::select(
    hab_site |>
      dplyr::filter(
        !stringr::str_detect(local_name, 'ds') &
          !stringr::str_detect(local_name, 'ef') &
          !stringr::str_detect(local_name, '\\d$')
      ),
    site, avg_channel_width_m
  ),
  by = c('pscis_crossing_id' = 'site')
)


# Step 3: Filter and select relevant columns for Phase 2 cost estimates
tab_cost_est_prep9 <- tab_cost_est_prep8 |>
  dplyr::filter(source == "pscis_phase2.xlsm") |>
  dplyr::select(
    pscis_crossing_id,
    stream_name,
    road_name,
    barrier_result,
    habitat_value,
    avg_channel_width_m,
    crossing_fix_code,
    cost_est_1000s,
    upstream_habitat_length_m,
    cost_net,
    cost_area_net,
    source
  )

# Step 4: Prepare the Phase 2 cost estimates for the table
# Don't rename the columns here because the function `fpr_my_cost_estimate` relies on the column cost_est_1000ss
tab_cost_est_phase2 <- tab_cost_est_prep9 |>
  dplyr::arrange(pscis_crossing_id) |>
  dplyr::select(-source)

# Clean up unnecessary objects
rm(tab_cost_est_prep,
   tab_cost_est_prep1,
   tab_cost_est_prep2,
   tab_cost_est_prep3,
   tab_cost_est_prep4,
   tab_cost_est_prep5,
   tab_cost_est_prep6,
   tab_cost_est_prep7,
   tab_cost_est_prep8)



# Map Tables --------------------------------------------------------------

## Phase 1 --------------------------------------------------------------

tab_map_phase_1_prep <- dplyr::left_join(form_pscis |>
                                           dplyr::select(-c(barrier_result, source)),
                                         pscis_all |>
                                   dplyr::select(pscis_crossing_id, barrier_result, source),
                                 by = c('pscis_crossing_id')) |>
  dplyr::select(pscis_crossing_id,
                my_crossing_reference,
                utm_zone,
                utm_easting = easting,
                utm_northing = northing,
                stream_name,
                road_name,
                site_id,
                priority_phase1 = my_priority,
                habitat_value,
                barrier_result,
                source) |>
  # we must transform the data to latitude/longitude (CRS 4326)
  sf::st_transform(4326)




tab_map_phase_1 <- tab_map_phase_1_prep |>
  dplyr::mutate(priority_phase1 = dplyr::case_when(priority_phase1 == 'mod' ~ 'moderate',
                                     TRUE ~ priority_phase1),
                priority_phase1 = stringr::str_to_title(priority_phase1)) |>
  dplyr::mutate(data_link = paste0('<a href =', 'sum/cv/', pscis_crossing_id, '.html ', 'target="_blank">Culvert Data</a>')) |>
  dplyr::mutate(photo_link = dplyr::case_when(is.na(my_crossing_reference) ~ paste0('<a href =', 'https://raw.githubusercontent.com/NewGraphEnvironment/', repo_name, '/main/data/photos/', pscis_crossing_id, '/crossing_all.JPG ',
                                                                                    'target="_blank">Culvert Photos</a>'),
                                              TRUE ~ paste0('<a href =', 'https://raw.githubusercontent.com/NewGraphEnvironment/', repo_name, '/main/data/photos/', my_crossing_reference, '/crossing_all.JPG ',
                                                            'target="_blank">Culvert Photos</a>'))) |>
  dplyr::mutate(model_link = paste0('<a href =', 'sum/bcfp/', pscis_crossing_id, '.html ', 'target="_blank">Model Data</a>')) |>
  dplyr::distinct(site_id, .keep_all = TRUE) #just for now



## Phase 2 --------------------------------------------------------------

#please note that the photos are only in those files because they are referenced in other parts of the document
tab_map_phase_2 <- dplyr::left_join(
  tab_cost_est_prep9,
  form_fiss_site |>
    dplyr::filter(is.na(ef) & location == "us") |>
    dplyr::select(site, utm_zone, easting = utm_easting, northing = utm_northing, comments),
  by = c('pscis_crossing_id' = 'site')
) |>
  # we must transform the data to latitude/longitude (CRS 4326)
  fpr::fpr_sp_assign_sf_from_utm() |>
  sf::st_transform(4326) |>
  # We don't have a priority ranking for the hab con sites at the moment so just just add the priority from the phase 1 assessments.
  dplyr::left_join(tab_map_phase_1 |>
                     sf::st_drop_geometry() |>
                     dplyr::select(pscis_crossing_id, priority = priority_phase1),
                   by = 'pscis_crossing_id') |>

  # Update the data link to point to the new location in docs
  dplyr::mutate(
    data_link = paste0(
      '<a href =',
      'sum/cv/', pscis_crossing_id,
      '.html ', 'target="_blank">Culvert Data</a>'
    )
  ) |>
  dplyr::mutate(
    model_link = paste0(
      '<a href =',
      'sum/bcfp/', pscis_crossing_id,
      '.html ', 'target="_blank">Model Data</a>'
    )
  ) |>
  dplyr::mutate(
    photo_link = paste0(
      '<a href =',
      'https://raw.githubusercontent.com/NewGraphEnvironment/', repo_name,'/main/data/photos/',
      pscis_crossing_id, '/crossing_all.JPG ',
      'target="_blank">Culvert Photos</a>'
    )
  )
