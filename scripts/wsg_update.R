wsg <- fpr::fpr_db_query("select * from whse_basemapping.fwa_watershed_groups_poly")

# we made the geojson with this https://www.arcgis.com/home/item.html?id=92a3811bca8d455da3c4ae22553c1129&sublayer=0
# https://services6.arcgis.com/ubm4tcTYICKBpist/arcgis/rest/services/FWCP_Peace_Study_Area_View/FeatureServer/0/query?where=1%3D1&outFields=*&f=geojson

aoi <- sf::st_read("/Users/airvine/Projects/gis/sern_peace_fwcp_2023/fwcp_peace_region.geojson") |>
  sf::st_transform(3005) |>
  # reduce in size a bit so we don't catch all the joining wsg and deal with inaccuracy of the polygon representing basin
  sf::st_buffer(dist = -5000)

t <- ngr::ngr_spk_join(
  target_tbl = wsg,
  mask_tbl = aoi,
  target_col_return = "*",
  mask_col_return = "Shape__Area",
  join_fun = sf::st_intersects
) |>
  dplyr::filter(!is.na(Shape__Area)) |>
  dplyr::arrange(watershed_group_code)


# burn to test
t |>
  sf::st_write("/Users/airvine/Projects/gis/sern_peace_fwcp_2023/basin_test.geojson", delete_dsn = TRUE)

# now that we know it is correct
# grab the csv of our watershed groups from github
params_raw <- readr::read_csv("https://raw.githubusercontent.com/smnorris/bcfishpass/main/parameters/example_newgraph/parameters_habitat_method.csv")

# add our new wsgs and remove dupes

wsg_extra <- data.frame(
  watershed_group_code = c(
    "KHOR",
    "UARL",
    "MUSK",
    "KETL",
    "SIML",
    "SKGT",
    "UNRS",
    "BRID",
    "GRNL",
    "BIGC"
  )
)
params <- dplyr::bind_rows(
  t |>
    dplyr::select(watershed_group_code) |>
    sf::st_drop_geometry(),
  params_raw
) |>
  dplyr::bind_rows(wsg_extra) |>
  dplyr::distinct(watershed_group_code, .keep_all = TRUE) |>
  dplyr::arrange(watershed_group_code) |>
  dplyr::mutate(model = 'cw')

# burn it out direct to bcfishpass as we have a branch ready to go
params |>
  readr::write_csv(
    "~/Projects/repo/bcfishpass/parameters/example_newgraph/parameters_habitat_method.csv"
  )
