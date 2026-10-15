# 2026 King's Speech Bill: Progress of Legislation

This repository contains the data processing scripts and automation workflows used to maintain and update the Shiny app accompanying the House of Commons Library briefing:

**2026 King's Speech Bill: Progress of Legislation**  
https://commonslibrary.parliament.uk/research-briefings/cbp-10893/

The app tracks the progress of bills announced in the 2026 King's Speech, from announcement through the parliamentary legislative process to Royal Assent.

---

## Overview

Data on bill progress is sourced from Parliament's API. However, bills do not appear in the API until they have been formally introduced and received their First Reading.

To bridge the gap between a bill being announced in the King's Speech and its appearance in the API, additional monitoring of House activity and alerting processes are used.

This repository contains:

- R scripts to pull and wrangle data from Parliament's API for Shiny app updates and email alert system.
- Scheduled workflows for running R scripts.
- Data files as csv for both the Shiny app and email alert system.

---

## Repository Structure

### `kings_speech_data_fetch.R`

Retrieves data from Parliament's API, performs the necessary cleaning and transformation, and outputs the datasets used by the Shiny app.

The script generates the following files in the `app_data/` directory:

- `download_file.csv`
- `main_table.csv`
- `news.csv`

These files are read directly by the Shiny application from this repo.

---

### `run_data_fetch.yaml`

The data update process for the Shiny app is automated using the GitHub Actions workflow:

```
.github/workflows/run_data_fetch.yaml
```

This workflow executes `kings_speech_data_fetch.R` on a daily schedule.

The workflow is configured to run at **10:30 AM**, although GitHub Actions scheduled workflows rarely actually execute at the time they are supposed to. Delays of several hours are normal.

The workflow:

1. Connects to Parliament's API
2. Retrieves the latest data on a bills stage through Parliament
3. Cleans and transforms the data
4. Updates the output CSV files in `app_data/`
5. Commits and pushes any changes back to the repository

---

### `gov_bill_alerts.R`

Supports the monitoring of government bills announced in the King's Speech that have not yet appeared in Parliament's API.

A Power Automate flow runs twice weekly and distributes email alerts based on the outputs of this script and a Power BI report, helping identify newly introduced bills. Upon introduction, the bill will be entered into Parliament's API and assigned an ID. This ID must be manually entered into the bill list in kings_speech_data_fetch.R and pushed to this repo.

---

### `run_gov_bill_alerts.yaml`

Part of the process for sending out email alerts on new government bills introduced is automated using the GitHub Actions workflow:

```
.github/workflows/run_gov_bill_alerts.yaml
```

This workflow executes `gov_bill_alerts.R` on a twice weekly schedule.

The workflow is configured to run at **15:00 PM**, although GitHub Actions scheduled workflows rarely actually execute at the time they are supposed to. Delays of several hours are normal.

The workflow:

1. Connects to Parliament's API
2. Retrieves the latest data on existing government bills for this session
3. Cleans and transforms the data
4. Updates the output CSV files in `alerts_data/`
5. Commits and pushes any changes back to the repository

---

## Maintenance

### Updating the Shiny App

The Shiny application reads the generated CSV files from the `app_data/` directory of this repo. Any changes to the structure of:

- `download_file.csv`
- `main_table.csv`
- `news.csv`

will require corresponding updates to the app code.
