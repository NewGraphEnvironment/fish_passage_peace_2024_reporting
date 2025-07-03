# read in the data, add the columns we want and burn to mergin for processing


# 1. change this to the correct project name in our GIS folder and delete this comment
dir_project <- 'sern_peace_fwcp_2023'
path <- "~/Projects/gis/sern_peace_fwcp_2023/background_layers.gpkg"

# originally this was done in the bcfishpass.sqlite but now we will get direct from the background_layers.gpkg
pscis_raw <- sf::st_read(path, layer =  "whse_fish.pscis_assessment_svw") |>
  sf::st_drop_geometry()
planning_raw <- sf::st_read(path, layer =  "bcfishpass.crossings_vw")

# sometimes we are in areas where we don't care if we are upstream of another anthropogenic barrier (ex. peace and kootenay
# where we have dams.  We want to exclude the ids of the dams so that we capture the xings that are as far downstream as possible
# but are perhaps upstream of these)
barriers_ok <- c(
  "785afb41-dfdf-423c-a291-e213d4b44f26", #WC Bennett
  "320902cd-48fc-40e5-8c0f-191086f332aa", #peace canyon
  "957546a9-e6c7-46bf-947a-b17d8a818d71" #site C
  )

barrier_site_c <- "957546a9-e6c7-46bf-947a-b17d8a818d71"

### If you can - and its helpful perhaps break out litle bits of this big MULTIPLE join
### join and run them a move at a time to see what is going on
planning <- dplyr::left_join(

  planning_raw,

  ### joining pcsis_raw to planning_raw when the aggregated_crossings_id is the same as the stream_crossing_id
  planning_raw2 <- dplyr::left_join(

    #arranging the planning_raw table by aggregated_crossings_id
    planning_raw |>
      dplyr::arrange(aggregated_crossings_id),

    # selecting certain columns from the pscis table
    pscis_raw %>%
      dplyr::mutate(stream_crossing_id = as.character(stream_crossing_id)) %>%
      dplyr::select(
        stream_crossing_id,
        outlet_drop,
        downstream_channel_width,
        habitat_value_code,
        image_view_url),

    by = c('aggregated_crossings_id' = 'stream_crossing_id')) |>

    # filtering where pscis_status is NA or not equal to 'HABITAT CONFIRMATION' and barrier_status is not equal to
    # 'PASSABLE' or 'UNKNOWN'
    dplyr::filter(is.na(pscis_status) | (pscis_status != 'HABITAT CONFIRMATION' &
                                           pscis_status != 'DESIGN' &
                                    barrier_status != 'PASSABLE' &
                                    barrier_status != 'UNKNOWN')) |>
    ### over 1km of rearing habitat to start. Don't forget about fpr_dbq_lscols .  Also - if not familiar have a look at
    ###  our tables in methods of past reports (Skeena has salmon) which explain the thresholds in general. Look at the
    ### csv in bcfishpass that decided what they are too though because they are new!
    dplyr::filter(bt_rearing_km > 1) |>
    dplyr::filter(crossing_type_code == 'CBS') |>

  # here is where we want no barriers downstream except when they are "ok"
    # dplyr::filter(is.na(barriers_anthropogenic_dnstr)) |>
    dplyr::filter(
      # Exclude rows where barriers_anthropogenic_dnstr is NA
      !is.na(barriers_anthropogenic_dnstr),
      purrr::map_lgl(
        stringr::str_split(barriers_anthropogenic_dnstr, ";"),
        # - All barrier IDs are in barriers_ok
        ~ all(.x %in% barriers_ok) &&
          # - The entry is not exactly "barrier_site_c"
          !(length(.x) == 1 && .x == barrier_site_c)
      )
    )|>

    # remove the geometry column so not class sf
    sf::st_drop_geometry(planning_raw2) |>

    ### make a note that this is the column that you will use to in the mergin project to query in the "Query Builder"
    ### so that you filter to only see the ones that you tagged as "my_review" = TRUE. Do a bit of homework to see how
    ### to use the `Query Builder`.  Note also that you can add a query that will make it so that you only
    ### see the ones that you have not yet reviewed. I will leave it to you to try to do that. Can help of course if need be
    dplyr::mutate(my_review = 'yes') |>
    dplyr::select(aggregated_crossings_id,
                  my_review,
                  outlet_drop,
                  downstream_channel_width,
                  habitat_value_code,
                  image_view_url),

  by = 'aggregated_crossings_id'

) |>
  dplyr::mutate(
    my_priority = NA_character_,
    my_priority_comments = NA_character_,
    my_citation_key1 = NA_character_,
    my_citation_key2 = NA_character_,
    my_citation_key3 = NA_character_
  )

#  testing here
# t <- planning_raw2 |>
#   dplyr::select(
#     aggregated_crossings_id,
#     barriers_anthropogenic_dnstr,
#     bt_rearing_km,
#     crossing_type_code
#     )



### this is going to write it into the mergin project.
planning |>
  sf::st_write(fs::path('~/Projects/gis',
                      dir_project,
                      paste0('planning_', format(lubridate::now(), "%Y%m%d")),
                      ext = 'geojson'),
               delete_dsn = TRUE
               )




































