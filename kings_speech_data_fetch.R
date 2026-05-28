library(httr)
library(jsonlite)
library(tidyverse)

# =================================
# BUILDING TABLE FROM KINGS SPEECH
# =================================

# manually adding announced titles from Kings speech
kings_bills <- data.frame(
  announced_bill_title = c(
    "Civil Aviation Bill",
    "Clean Water Bill",
    "Commonhold and Leasehold Reform Bill",
    "Competition Reform Bill",
    "Digital Access to Services Bill",
    "Education for All Bill",
    "Electricity Generator Levy Bill",
    "Energy Independence Bill",
    "Enhancing Financial Services Bill",
    "European Partnership Bill",
    "Highways (Financing) Bill",
    "Immigration and Asylum Bill",
    "National Security Bill",
    "Health Bill",
    "Nuclear Regulation Bill",
    "Overnight Visitor Levy Bill",
    "Police Reform Bill",
    "Regulating for Growth Bill",
    "Remediation Bill",
    "Removal of Peerages Bill",
    "Small Business Protections (Late Payments) Bill",
    "Social Housing Bill",
    "Sovereign Grant Bill",
    "Sporting Events Bill",
    "Steel Industry (Nationalisation) Bill",
    "Tackling State Threats Bill",
    "Armed Forces Bill*",
    "Courts and Tribunals Bill*",
    "Cyber Security and Resilience (Network and Information Systems) Bill*",
    "Northern Ireland Troubles Bill*",
    "High Speed Rail (Crewe - Manchester) Bill / Northern Powerhouse Rail*",
    "Public Office (Accountability) Bill*",
    "Railways Bill*",
    "Representation of the People Bill*"
  ),

  bill_id = c(
    4125,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    4129,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    4128,
    4126,
    0,
    4127,
    4123,
    0,
    4065,
    4083,
    4035,
    4022,
    3094,
    4019,
    4030,
    4080
  )
)

not_introduced_kings_bills <- kings_bills |>
  filter(bill_id == 0)

introduced_kings_bills <- kings_bills |>
  filter(bill_id != 0)

kings_ids <- introduced_kings_bills$bill_id

# building bill webpage urls
bills_webpages <- data.frame(
  bill_id = kings_ids,
  URL = sprintf("https://bills.parliament.uk/bills/%s/stages", kings_ids)
)

# =====================
# FETCH BILLS FROM API
# =====================

# fetching all bills data to get titles and House introduced
bills_url <- "https://bills-api.parliament.uk/api/v1/Bills?Take=10000"

bills_response <- GET(
  bills_url,
  add_headers(accept = "text/plain")
)

# tidying up response
bills_text <- content(bills_response, as = "text", encoding = "UTF-8")
bills_json <- fromJSON(bills_text)

all_bills <- bills_json$items |>
  tibble()

# matching by bill ID to join with data on annouced titles
main_table <- kings_bills |>
  left_join(all_bills, by = c("bill_id" = "billId")) |>
  select(announced_bill_title, bill_id, shortTitle, originatingHouse) |> 
  # remove [HL] from shortTitle
  mutate(
    `shortTitle` = str_remove(`shortTitle`, " \\[HL\\]$")
  )


# ========================================
# FETCH KINGS SPEECH BILL STAGES FROM API
# ========================================

# Function to get stages data for all King's speech bills
get_bill_stages <- function(kings_ids) {
  stages_url <- sprintf(
    "https://bills-api.parliament.uk/api/v1/Bills/%s/Stages?Take=500",
    kings_ids
  )

  stages_response <- GET(
    stages_url,
    add_headers(accept = "text/plain")
  )

  stages_text <- content(stages_response, as = "text", encoding = "UTF-8")
  stages_json <- fromJSON(stages_text)

  first_and_current_stages <- stages_json$items |>
    tibble() |>
    unnest(stageSittings, names_sep = "_") |>
    filter(
      stageSittings_date == min(stageSittings_date) |
        stageSittings_date == max(stageSittings_date)
    )
}

# Repeat for each King's Speech bills
stages <- lapply(kings_ids, get_bill_stages) |>
  bind_rows() |>
  select(description, stageSittings_billId, stageSittings_date) |>
  pivot_wider(names_from = description, values_from = stageSittings_date) |>
  select(stageSittings_billId, `1st reading`) # when Royal Assent is reached add in column

# Join date introduced data with main table
main_table_final <- main_table |>
  left_join(stages, by = c("bill_id" = "stageSittings_billId")) |>
  mutate(
    `1st reading` = format(
      as.Date(`1st reading`, format = "%Y-%m-%d"),
      "%d %B %Y"
    )
  ) |>
  mutate(`Royal Assent date` = NA, `Act title` = NA) |>
  rename(
    "King's Speech announcement" = "announced_bill_title",
    "Introduced title" = "shortTitle",
    "House introduced to" = "originatingHouse",
    "Introduction date" = "1st reading",
  ) |>
  # adding in bill webpage urls
  left_join(bills_webpages, by = c("bill_id" = "bill_id")) |>
  #  for introduced bills with bill webpages, hyperlink the introduced title with url
  mutate(
    `Introduced title` = if_else(
      is.na(URL) |
        URL == "" |
        is.na(`Introduced title`) |
        `Introduced title` == "",
      `Introduced title`,
      sprintf('<a href="%s" target="_blank">%s</a>', URL, `Introduced title`)
    )
  ) |>
  select(-URL)

write_csv(main_table_final, "main_table.csv")


# ======================================
# FETCH KINGS SPEECH BILL NEWS FROM API
# ======================================

# Function to get bill news data for all King's speech bills
get_news <- function(kings_ids) {
  news_url <- sprintf(
    "https://bills-api.parliament.uk/api/v1/Bills/%s/NewsArticles",
    kings_ids
  )

  news_response <- GET(
    news_url,
    add_headers(accept = "text/plain")
  )

  news_text <- content(news_response, as = "text", encoding = "UTF-8")
  news_json <- fromJSON(news_text)

  news_data <- news_json$items |>
    tibble() |>
    mutate(billId = kings_ids)
}

# Repeat for each King's Speech bills
news_data <- lapply(kings_ids, get_news)

# Collate data into one table and tidy to include only relevant data
news_data <- news_data |>
  bind_rows() |>
  select(billId, title, content)

news_cleaned <- news_data |>
  mutate(
    content = str_remove_all(
      content,
      'style="[^"]*"'
    ),
    content = str_remove_all(content, "<[^>]+>"),
    content = str_remove_all(content, " What happens next"),
    content = str_remove_all(content, "\\?"),
    content = str_replace_all(content, "&#39;", "'"),
    content = str_replace_all(content, "What happens next", " "),
    content = str_replace_all(content, "[\\s]+", " ")
  ) |>
  filter(title != "2019 Parliament") |>
  # if title = "2024 Parl", mutate to "High speed rail", else keep existing title
  mutate(
    title = ifelse(
      title == "2024 Parliament",
      "High Speed Rail (Crewe - Manchester) Bill / Northern Powerhouse Rail",
      title
    )
  )

news_final <- left_join(
  kings_bills,
  news_cleaned,
  by = c("bill_id" = "billId")
) |>
  mutate(
    content = ifelse(
      is.na(content),
      "Bill not yet introduced.", # review this text
      content
    )
  ) |>
  rename(
    "King's Speech announcement" = "announced_bill_title",
    "Introduced title" = "title",
    "Progress summary" = "content"
  )


# ==========================================
# FETCH KINGS SPEECH BILL BRIEFINGS FROM API
# ==========================================

# Function to get Library briefings data for all King's speech bills
get_publications <- function(kings_ids) {
  publications_url <- sprintf(
    "https://bills-api.parliament.uk/api/v1/Bills/%s/Publications",
    kings_ids
  )

  publications_response <- GET(
    publications_url,
    add_headers(accept = "text/plain")
  )

  publications_text <- content(
    publications_response,
    as = "text",
    encoding = "UTF-8"
  )
  publications_json <- fromJSON(publications_text)

  publications_data <- publications_json$publications |>
    tibble() |>
    unnest(publicationType, names_sep = "_") |>
    unnest(links, names_sep = "_") |>
    mutate(billId = publications_json$billId) |> # Create column with bill ID
    relocate(billId)
}

# Repeat for each King's Speech bills
publications_data <- lapply(kings_ids, get_publications)

# Collate data into one table and remove unnecessary columns
publications_data <- publications_data |>
  bind_rows() |>
  filter(publicationType_name == "Briefing papers") |>
  filter(house == "Commons") |>
  select(billId, title, links_url) |> # delete columns other than those showing bill IDs, member name and member party
  mutate(
    title = ifelse(
      title == "Briefing Paper on Second Reading",
      "High Speed Rail (Crewe / Manchester) Bill 2024-25",
      title
    ),
    links_url = ifelse(
      links_url ==
        "https://commonslibrary.parliament.uk/research-briefings/cbp-9541/",
      "https://commonslibrary.parliament.uk/research-briefings/cbp-10066/",
      links_url
    )
  )

publications_final <- publications_data |>
  rename(
    "Briefing paper" = "title",
    "URL" = "links_url"
  )

news_publications <- left_join(
  news_final,
  publications_final,
  by = c("bill_id" = "billId")
) |>
  # remove [HL] - news from introduced titles
  mutate(
    `Introduced title` = str_remove(`Introduced title`, " \\[HL\\] - news$")
  ) |>
  # for bills with briefing papers, hyperlink the briefing paper title with url
  mutate(
    `Briefing paper` = if_else(
      is.na(URL) | URL == "" | is.na(`Briefing paper`) | `Briefing paper` == "",
      `Briefing paper`,
      sprintf('<a href="%s" target="_blank">%s</a>', URL, `Briefing paper`)
    )
  ) |>
  select(-URL) |>
  # for bills with >1 briefing paper, condensing into one row
  group_by(`King's Speech announcement`) |>
  mutate(
    `Briefing paper` = paste(`Briefing paper`, collapse = "<br><br>")
  ) |>
  slice(1) |> # keep one row per bill
  ungroup()

write.csv(news_publications, "news.csv")
