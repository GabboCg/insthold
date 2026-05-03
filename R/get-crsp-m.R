get_crsp_m <- function(wrds, start_date, end_date) {

    # Download CRSP monthly stock file for common stocks (shrcd 10-11)
    crsp_raw <- DBI::dbGetQuery(wrds, glue::glue("
       SELECT a.permno, a.mthcaldt, a.shrout, a.mthprc, 
              a.mthcumfacpr, a.mthcumfacshr
        FROM crsp.msf_v2 AS a
        WHERE a.mthcaldt BETWEEN '{start_date}' AND '{end_date}'
          AND a.ShareType = 'NS'
          AND a.SecurityType = 'EQTY'
          AND a.SecuritySubType = 'COM'
          AND a.USIncFlg = 'Y'
          AND a.IssuerType IN ('ACOR', 'CORP')
    "))

    # Compute adjusted price, total shares outstanding, market cap,
    # and calendar month-end / quarter-end dates
    crsp_m <- crsp_raw |>
        mutate(
            permno = as.integer(permno),
            date   = as.Date(mthcaldt),
            mdate  = lubridate::ceiling_date(date, "month")   - lubridate::days(1),
            qdate  = lubridate::ceiling_date(date, "quarter") - lubridate::days(1),
            p      = abs(mthprc) / mthcumfacpr,        # cumulative-adj price
            tso    = shrout * mthcumfacshr * 1e3,   # cumulative-adj shares outstanding
            me     = p * tso / 1e6                     # market cap in $mil
        )

    # Keep last monthly observation per permno-qdate (quarter-end record)
    crsp_qend <- crsp_m |>
        group_by(permno, qdate) |>
        filter(mdate == max(mdate)) |>
        ungroup() |>
        distinct(permno, qdate, .keep_all = TRUE) |>
        select(permno, qdate, cfacshr = mthcumfacshr, p, tso, me)

    return(crsp_qend)

}
