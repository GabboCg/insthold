get_crsp_m <- function(wrds, start_date, end_date) {

    # Download CRSP monthly stock file for common stocks (shrcd 10-11)
    crsp_raw <- DBI::dbGetQuery(wrds, glue::glue("
        SELECT a.permno, a.date, a.shrout, a.prc, a.cfacpr, a.cfacshr
        FROM crsp.msf AS a
        INNER JOIN crsp.msenames AS b
            ON  a.permno  = b.permno
            AND b.namedt <= a.date
            AND a.date   <= b.nameendt
        WHERE a.date BETWEEN '{start_date}' AND '{end_date}'
          AND b.shrcd BETWEEN 10 AND 11
    "))

    # Compute adjusted price, total shares outstanding, market cap,
    # and calendar month-end / quarter-end dates
    crsp_m <- crsp_raw |>
        mutate(
            permno = as.integer(permno),
            date   = as.Date(date),
            mdate  = lubridate::ceiling_date(date, "month")   - lubridate::days(1),
            qdate  = lubridate::ceiling_date(date, "quarter") - lubridate::days(1),
            p      = abs(prc) / cfacpr,          # cumulative-adj price
            tso    = shrout * cfacshr * 1e3,     # cumulative-adj shares outstanding
            me     = p * tso / 1e6               # market cap in $mil
        )

    # Keep last monthly observation per permno-qdate (quarter-end record)
    crsp_qend <- crsp_m |>
        group_by(permno, qdate) |>
        filter(mdate == max(mdate)) |>
        ungroup() |>
        distinct(permno, qdate, .keep_all = TRUE) |>
        select(permno, qdate, cfacshr, p, tso, me)

    return(crsp_qend)

}
