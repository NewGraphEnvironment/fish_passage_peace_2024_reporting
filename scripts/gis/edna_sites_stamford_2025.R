# read in the excel file
path <- "~/Projects/repo/fish_passage_peace_2024_reporting/data/inputs_raw/Williston-GR_eDNA-Results-List.xlsx"
path_out_repo <- "~/Projects/repo/fish_passage_peace_2024_reporting/data/gis/sites_edna_williston-grayling.geojson"
path_out_gis <- "~/Projects/gis/sern_peace_fwcp_2023/sites_edna_williston-grayling.geojson"

edna_raw <- readxl::read_excel(path) |>
  janitor::clean_names() |>
  dplyr::mutate(
    utm = stringr::str_replace_all(utm, "[A-Za-z]", "") |> # remove zone letters like 'U' or 'V'
  stringr::str_squish() # remove extra whitespace
  ) |>
  # we have utms for all but not lat long.
  tidyr::separate(utm,
                  into = c("utm_zone", "easting", "northing"),
                  # sep = " ",
                  convert = TRUE
  ) |>
  fpr::fpr_sp_assign_sf_from_utm() |>
  fpr::fpr_sp_assign_latlong(col_lat = "latitude", col_lon = "longitude")


  # burn to repo and gis project
  if(fs::file_exists(path_out_repo)){
    fs::file_delete(path_out_repo)
  }

edna_raw |>
  sf::st_transform(wsg = 4326) |>
  sf::st_write(
    path_out_repo
  )

if(fs::file_exists(path_out_gis)){
  fs::file_delete(path_out_gis)
}

edna_raw |>
  sf::st_write(
    path_out_gis
  )

