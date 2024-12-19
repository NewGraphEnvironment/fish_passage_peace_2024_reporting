#combining pit tag data to individual fish data so that we can copy and paste directly into submission template
# would be good to include the comments and times/camera of photos in the fish csv and then paste them to the right of the pit tag.

source('scripts/packages.R')

# Pit Tags ------------------------------------------------------

# import the pit tag csv
# Pit tag data for ALL years is currently being stored on OneDrive .
path_tag <- fs::path('/Users/lucyschick/Library/CloudStorage/OneDrive-Personal/Projects/2024_data/fish/tag_01_05.csv')

# tag_01_05 does not have a column name so for that reason the call to read_csv needs to be different (change col_names to F for that file) and
# the column name will default to X1.
pit_tag <- readr::read_csv(path_tag, col_names = F) |>
  #separate the pit tag out from the rest of the info in the pit tag csv
  # https://stackoverflow.com/questions/66696779/separate-by-pattern-word-in-tidyr-and-dplyr
  tidyr::separate(col=X1, into=c('date', 'tag_id'), sep='\\s*TAG\\s*') |>
  tibble::rowid_to_column() |>
  dplyr::filter(str_like(date, '%2024%'))




#import csv with fish data
path_fish <-  fs::path('/Users/lucyschick/Library/CloudStorage/OneDrive-Personal/Projects/2024_data/fish_data_raw.xlsx')

# Read and clean the data
fish <- readxl::read_xlsx(path_fish, sheet = "fish_data") |>
  # remove the dates added by excel, they are wrong. We only want the time segments
  mutate(across(c(site_start_time, site_end_time,segment_start_time, segment_end_time, photo_time_start, photo_time_end),
                ~ format(., "%H:%M:%S")))


#join fish csv with pit tag csv based on tag row ID |>
fish_data_tags <- dplyr::left_join(fish,
                              pit_tag |>
                                dplyr::select(rowid, tag_id),
                              by = c("row_id" = "rowid")) |>
  # arrange columns
  dplyr::mutate(pit_tag_id = tag_id) |>
  dplyr::select(-tag_id) |>
  dplyr::relocate(row_id, .after = pit_tag_id) |>
  # add a period, a space and the row number to the pit tag to go in the comments to make it easy to pull anything out we want later
  dplyr::mutate(comments = case_when(
    !is.na(pit_tag_id) ~ paste0(comments,". Pit Tag ID: ", pit_tag_id, ". Row ID: ", row_id, ". "),
    T ~ comments))



# select a subsample of fish (lets go 15% since the sample size is small) to review manually to be sure the
# pit tags match which fish they go with
# set seed for reproducible sample - try running it again without setting the seed immediately before and see how it differs
set.seed(1234)

qa <- fish_data_tags |>
  filter(!is.na(row_id)) |>
  slice_sample(prop = 0.15) |>
  select(local_name, project_name, row_id, pit_tag_id, length, weight) |>
  arrange(row_id)



# burn the csv to the repo for cut and paste and to OneDrive for backup
fish_data_tags |>
  readr::write_csv('data/inputs_extracted/fish_data_tags_joined.csv',
                   na = "" ) |>
  readr::write_csv('/Users/lucyschick/Library/CloudStorage/OneDrive-Personal/Projects/2024_data/fish/fish_data_tags_joined.csv',
                   na = "" )




# Fish Data ------------------------------------------------------
# import raw fish data csv on onedrive, add common names and reference numbers
path <- 'Projects/2023_data/peace/fish/fish_data.csv'
stub_from <- 'C:/Users/matwi/OneDrive/'

fish_data <- readr::read_csv(file = paste0(stub_from, path)) |>
  janitor::clean_names() |>
  # there is an extra underscore in site names after ef that needs to be removed
  mutate(local_name = str_replace_all(local_name, 'ef_', 'ef'))

# cross reference with step 1 of hab con sheet to get ref numbers
ref_names <- left_join(
  fish_data,
  fpr_import_hab_con(backup = F, row_empty_remove = T, col_filter_na = T) |>
    pluck(1) |>
    select(reference_number, alias_local_name),
  by = c('local_name' = 'alias_local_name')
) |>
  relocate(reference_number, .before = 'local_name')

# import fish names and codes
hab_fish_codes <- fishbc::freshwaterfish |>
  select(species_code = Code, common_name = CommonName) |>
  # add option when there was no fish caught
  tibble::add_row(species_code = 'NFC', common_name = 'No Fish Caught') |>
  # CT is named differently in hab con sheet
  mutate(common_name = case_when(common_name == 'Cutthroat Trout' ~ 'Cutthroat Trout (General)', T ~ common_name))

# xref and change codes to common names in raw file
fish_names <- left_join(
  ref_names,
  hab_fish_codes,
  by = c('species' = 'species_code')
) |>
  # re arrange columns to align with step 3 of submission sheet, drop species code column
  select(-species) |>
  relocate(common_name, .before = 'length_mm') |>
  # burn cleaned file to repo
  readr::write_csv(file = 'data/inputs_raw/fish_data.csv', na = '')


