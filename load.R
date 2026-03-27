#!/usr/bin/env Rscript
# ======================================================== #
#
#               Institutional Ownership Breadth
#
#                 Gabriel E. Cabrera-Guzmán
#                The University of Manchester
#
#                       Spring, 2026
#
#                https://gcabrerag.rbind.io
#
# ------------------------------ #
# email: gabriel.cabreraguzman@postgrad.manchester.ac.uk
# ======================================================== #

# Load packages
library(tidyverse)
library(lubridate)
library(DBI)
library(dbplyr)
library(RPostgres)
library(glue)
library(zoo)

# Load auxiliary functions
source("R/get-crsp-m.R")
source("R/get-insthold.R")
source("R/get-bushee.R")

# WRDS connection
wrds <- dbConnect(
    Postgres(),
    host    = "wrds-pgdata.wharton.upenn.edu",
    dbname  = "wrds",
    port    = 9737,
    sslmode = "require",
    user    = Sys.getenv("WRDS_USER"),
    password = Sys.getenv("WRDS_PASSWORD")
)

# Sample period
start_date <- "2020-01-01"
end_date   <- "2025-12-31"

# Create output folder if needed
if (!dir.exists("data")) dir.create("data")

# ==========================================
#                 CRSP Block
# —————————————————–––––––––––––––––––––––––

# Download monthlt CRSP         
crsp_qend <- get_crsp_m(wrds, start_date, end_date)

# Save CRSP quarter-end file
write_csv(crsp_qend, "data/crso_m.csv")

# ==========================================
#      Calculate Institutional Measures
# —————————————————–––––––––––––––––––––––––

# TR 13F: Merge, Holdings, Adjust    
insthold_13f_s34 <- get_insthold(wrds, start_date, end_date, crsp_qend)
write_rds(insthold_13f_s34, "data/insthold_13f_s34.rds")

# Institutional measure at security level                  
holdings_f <- insthold_13f_s34 |> filter(shares_adj > 0)

# Number of owners (institutions holding the stock) per permno-rdate
io_numowners <- holdings_f |>
    group_by(permno, rdate) |>
    summarise(numowners = n(), .groups = "drop")

# Total number of 13F filers in each quarter (max is the same for all stocks)
io_numinst <- holdings_f |>
    group_by(permno, rdate) |>
    summarise(numinst = max(num_inst), .groups = "drop")

# New entrants, exits, and total adjusted shares
io_total <- holdings_f |>
    group_by(permno, rdate) |>
    summarise(
        newinst  = sum(first_report), # filers new this quarter
        oldinst  = sum(last_report),  # filers that will not report next quarter
        io_total = sum(shares_adj),
        .groups  = "drop"
    )

# Sum of squared shares (for HHI concentration)
io_uss <- holdings_f |>
    group_by(permno, rdate) |>
    summarise(io_ss = sum(shares_adj ^ 2), .groups = "drop")

# Combine all security-level metrics
io_metrics <- io_numowners |>
    inner_join(io_numinst,  by = c("permno", "rdate")) |>
    inner_join(io_total,    by = c("permno", "rdate")) |>
    inner_join(io_uss,      by = c("permno", "rdate"))

# ==========================================
#            Concentration (HHI)
# —————————————————–––––––––––––––––––––––––

# Concentration (HHI)
# Change in Breadth (Lehavy & Sloan 2008) 
# dbreadth = [(numowners(t) - newinst(t)) - (numowners(t-1) - oldinst(t-1))] / numinst(t-1)
io_metrics <- io_metrics |>
    mutate(
        ioc_hhi = io_ss / io_total ^ 2,
        d_owner = numowners - oldinst
    ) |>
    arrange(permno, rdate) |>
    group_by(permno) |>
    mutate(
        lag_numinst = lag(numinst),
        lag_d_owner = lag(d_owner)
    ) |>
    ungroup() |>
    mutate(
        dbreadth = ((numowners - newinst) - lag_d_owner) / lag_numinst
    ) |>
    select(permno, rdate, numowners, io_total, ioc_hhi, dbreadth)

# ==========================================
#     Add CRSP Market Data to Holdings  
# —————————————————–––––––––––––––––––––––––

# Right join so that common stocks with no 13F data are retained
io_ts <- io_metrics |>
    right_join(crsp_qend, by = c("permno" = "permno", "rdate" = "qdate")) |>
    arrange(permno, rdate) |>
    filter(tso > 0) |>
    mutate(
        io_missing = if_else(is.na(io_total), 1L, 0L),
        ior        = coalesce(io_total, 0) / tso,
        io_g1      = if_else(ior > 1, 1L, 0L)
    )

# Drop exact duplicates
io_ts <- io_ts |> distinct(permno, rdate, .keep_all = TRUE)

# ==========================================
#      Bushee Investor Classification
# —————————————————–––––––––––––––––––––––––

# Download Bushee (1998, 2001) DED / QIX / TRA classification
bushee <- get_bushee()

# Tag each holding with its manager's TQI type for the filing year
holdings_typed <- insthold_13f_s34 |>
    filter(shares_adj > 0) |>
    mutate(year = lubridate::year(rdate)) |>
    left_join(
        bushee |> select(mgrno, year, tqi),
        by = c("mgrno", "year"), 
        relationship = "many-to-many"
    )

# Per-type ownership ratio: io_ded, io_qix, io_tra
for (t in c("DED", "QIX", "TRA")) {
    
    col_name   <- paste0("io_", tolower(t))
    type_shares <- holdings_typed |>
        filter(tqi == t) |>
        group_by(permno, rdate) |>
        summarise(type_shares = sum(shares_adj), .groups = "drop")

    io_ts <- io_ts |>
        left_join(type_shares, by = c("permno", "rdate")) |>
        mutate(!!col_name := coalesce(type_shares / tso, 0)) |>
        select(-type_shares)
    
}

# Save
write_rds(io_ts, "data/io_ts.rds")
