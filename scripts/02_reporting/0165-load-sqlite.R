# import data from sqlite -------------------------------------------------
##this is our new db made from 0282-extract-bcfishpass2-crossing-corrections.R and 0290
conn <- readwritesqlite::rws_connect("data/bcfishpass.sqlite")

## Do we still use all this objects? Try to clean up as you go Lucy

readwritesqlite::rws_list_tables(conn)
bcfishpass <- readwritesqlite::rws_read_table("bcfishpass", conn = conn)
# bcfishpass_archive <- readwritesqlite::rws_read_table("bcfishpass_archive_2022-03-02-1403", conn = conn)
# bcfishpass_column_comments <- readwritesqlite::rws_read_table("bcfishpass_column_comments", conn = conn)
# pscis_historic_phase1 <- readwritesqlite::rws_read_table("pscis_historic_phase1", conn = conn)
# pscis_historic_phase2 <- readwritesqlite::rws_read_table("pscis_historic_phase2", conn = conn)
bcfishpass_spawn_rear_model <- readwritesqlite::rws_read_table("bcfishpass_spawn_rear_model", conn = conn)
# rd_class_surface_prep <- readwritesqlite::rws_read_table("rd_class_surface", conn = conn)
xref_pscis_my_crossing_modelled <- readwritesqlite::rws_read_table("xref_pscis_my_crossing_modelled", conn = conn)
# wshds <- readwritesqlite::rws_read_table("wshds", conn = conn) |>
#   # remove any negative values
#   mutate(across(contains('elev'), ~ replace(., . < 0, NA))) |>
#   # but... we don't really need elev_min anyway b/c we have elevation site
#   select(-elev_min)
#   # mutate(aspect = as.character(aspect))
# pscis_assessment_svw <- readwritesqlite::rws_read_table("pscis_assessment_svw", conn = conn)
# photo_metadata <- readwritesqlite::rws_read_table("photo_metadata", conn = conn)
# form_pscis_raw <- readwritesqlite::rws_read_table("form_pscis_raw", conn = conn) |>
#   sf::st_drop_geometry()

readwritesqlite::rws_disconnect(conn)
