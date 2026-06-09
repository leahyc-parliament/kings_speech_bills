install.packages("tidyverse")
library(tidyverse)

original_gov_bills <- read.csv("back_up_data/gov_bills_29_05_2026.csv") |> 
slice(-c(1, 2, 3, 4)) #only for testing, remove eventually

new_gov_bills <- read.csv("https://api.parliament.uk/bill-papers/bills.csv") |>
  mutate(
    `Bill.papers.URL` = str_replace(
      `Bill.papers.URL`,
      "https://api.parliament.uk/bill-papers/bills/",
      ""
    ),
    `Bill.papers.URL` = as.integer(`Bill.papers.URL`)
  ) |>
  rename(
    `bill_id` = `Bill.papers.URL`
  ) |>
  filter(
    (!Type %in%
      c(
        "Private Members' Bill (under the Ten Minute Rule)",
        "Private Members' Bill (Starting in the House of Lords)",
        "Private Members' Bill (Presentation Bill)",
        "Private Members' Bill (Ballot Bill)",
        "Private Bill",
        "Consolidation Bill"
      )),
    (`Originating.session` %in% "59/2")
  ) |>
  select(`bill_title` = `Bill.short.title`, `bill_id`) |>
  anti_join(original_gov_bills, by = "bill_id")

write.csv(
  new_gov_bills,
  "new_gov_bills.csv",
  row.names = FALSE
)

# write.csv(
#   new_gov_bills,
#   paste0("C:\\Users\\leahyc\\OneDrive - UK Parliament\\Government Bills Alerts\\first_new_gov_bills_", Sys.Date(), ".csv"),
#   row.names = FALSE
# )

  # paste0("new_gov_bills_", Sys.Date(), ".csv"),