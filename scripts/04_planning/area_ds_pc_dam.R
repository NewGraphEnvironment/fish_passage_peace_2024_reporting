# we need to remove area below Peace Canyon dam from queries for connectivity

# Grab the area upstream of the Peace Canyon dam
peace_canyon_us_poly <- fpr::fpr_db_query("SELECT * FROM FWA_WatershedAtMeasure(359572348, 1683907)")
mapview::mapview(peace_canyon_us_poly)

# Grab the study watershed group with watershed_group_code = 'UPCE'
watershed_group <- fpr::fpr_db_query("SELECT * FROM whse_basemapping.fwa_watershed_groups_poly
                                     WHERE watershed_group_code = 'UPCE'")
mapview::mapview(watershed_group)


# Visualize both those areas, and see where they overlap
mapview::mapview(list(peace_canyon_us_poly, watershed_group))


# Now grab the area downstream of Peace Canyon dam that is in the study watershed group. This is the area we want to exclude from queries for connectivity
peace_canyon_downstream_area <- fpr::fpr_db_query(
  "WITH upstream AS (
     SELECT (FWA_WatershedAtMeasure(
               359572348,
               1683907
             )).geom AS geom
   ),
   wg AS (
     SELECT geom
     FROM whse_basemapping.fwa_watershed_groups_poly
     WHERE watershed_group_code = 'UPCE'
   ),
   clip AS (
     SELECT ST_Intersection(u.geom, w.geom) AS geom
     FROM upstream u
     CROSS JOIN wg w
   )
   SELECT ST_Difference(w.geom, c.geom) AS geom
   FROM wg w, clip c;"
)

mapview::mapview(peace_canyon_downstream_area)


# save as a geojson
peace_canyon_downstream_area |>
  sf::st_write("data/inputs_extracted/area_ds_pc_dam.geojson", driver = "GeoJSON")


