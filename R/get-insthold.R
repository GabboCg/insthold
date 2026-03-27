get_insthold <- function(wrds, start_date, end_date, crsp_m) {
    
    # CRSP merge — qdate is already a proper Date from get_crsp_m()
    crsp_m <- crsp_m |>
        rename(fdate = qdate)
    
    # CRSP identifying information
    msenames_db <- tbl(wrds, in_schema("crsp", "msenames"))
    
    # Institutional holding (13f)
    tr_13f_s34type1_db <- tbl(wrds, in_schema("tr_13f", "s34type1"))
    tr_13f_s34type3_db <- tbl(wrds, in_schema("tr_13f", "s34type3"))
    
    # Merge TR-13f S34type1 and S34type3 Sets 
    # First, Keep First Vintage with Holdings Data for Each RDATE-MGRNO Combinations 
    first_vint <- tr_13f_s34type1_db  |>
        select(
            rdate, fdate, mgrno, mgrname
        ) |>
        distinct_all() |>
        group_by(mgrno, rdate) |>
        filter(
            fdate == min(fdate)
        ) |>
        arrange(mgrno, rdate) |>
        ungroup() |>
        collect()
    
    # Marker for First and Last Quarters of Reporting & Reporting Gaps                      
    # Exercise Helpful Mostly For Clean Time-Series Analysis                                  
    first_vint <- first_vint |>
        mutate(
            fyearqtr = zoo::as.yearqtr(paste0(year(rdate), "-", quarter(rdate)))
        ) |>
        group_by(
            mgrno
        ) |>
        mutate(
            first_report = ifelse(row_number(mgrno) == 1 | (fyearqtr - lag(fyearqtr, 1)) > 0.25, 1, 0)
        ) |>
        distinct(mgrno, rdate, .keep_all = TRUE) |> 
        arrange(mgrno, desc(rdate)) |>
        mutate(
            last_report = ifelse(row_number(mgrno) == 1 | (lag(fyearqtr, 1) - fyearqtr) > 0.25, 1, 0)
        ) |>
        filter(
            rdate >= start_date & rdate <= end_date
        ) |>
        arrange(mgrno, rdate) |>
        distinct() |>
        group_by(rdate) |>
        mutate(num_inst = n()) |>
        arrange(fdate, mgrno) |>
        ungroup()
    
    # Extract Holdings and Adjust Shares Held
    # FDATE -Vintage Date- is used in Shares' Adjustment 
    holdings_v1 <- first_vint |>
        select(-mgrname) |>
        left_join(
            tr_13f_s34type3_db |>
                select(fdate, cusip, mgrno, shares) |>
                collect(), 
            by = c("fdate", "mgrno")
        ) |>
        filter(shares > 0)
    
    # Remove to save space 
    rm(first_vint)
    
    # Map TR-13F's Historical CUSIP to CRSP Unique Identifier PERMNO */
    # Keep Securities in CRSP Common Stock Universe */
    holdings_v2 <- holdings_v1 |>
        left_join(
            msenames_db |> 
                distinct(ncusip, permno) |>
                filter(!is.na(ncusip)) |>
                collect(),
            by = c("cusip" = "ncusip")
        ) |>
        drop_na(permno) |>
        distinct(
            rdate, fdate, first_report, last_report, mgrno, permno, 
            num_inst, shares
        ) 
    
    # Remove to save space 
    rm(holdings_v1)
    
    # Adjust Shares using CRSP Adjustment Factors aligned at Vintage Dates 
    holdings <- holdings_v2 |>
        inner_join(
            crsp_m, 
            by = c("permno", "fdate")
        ) |>
        mutate(
            shares_adj = shares * cfacshr
        ) |>
        arrange(permno, rdate, mgrno) |>
        distinct(permno, rdate, mgrno, .keep_all = TRUE)
    
    # Remove to save space 
    rm(holdings_v2)
    
    # return results
    return(holdings)
    
}
