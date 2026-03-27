get_bushee <- function(
    url = "https://accounting-faculty.wharton.upenn.edu/bushee/wp-content/uploads/sites/4/2025/07/iiclass.txt"
) {

    # Column names from Bushee's data documentation
    col_names <- c(
        "mgrno",   # Spectrum manager number  (key: links to TR 13F)
        "mgrver",  # Manager number version
        "permkey", # Permanent key
        "year",    # Calendar year of classification
        "type",    # Institution type (IIA, INV, BNK, ...)
        "tqi",     # Transient / Quasi-indexer / Dedicated  (DED, QIX, TRA)
        "p_tqi",   # Permanent TQI classification
        "isc",     # Investment style (LVA, LGR, SGR, SVA)
        "p_isc",   # Permanent investment style
        "gsc",     # Growth style (VAL, G&I, GRO)
        "p_gsc",   # Permanent growth style
        "tax",     # Tax-sensitivity classification
        "p_tax"    # Extended tax-sensitivity classification
    )

    bushee <- readr::read_table(
        url,
        col_names = col_names,
        na        = ".",
        col_types = readr::cols(
            mgrno   = readr::col_integer(),
            mgrver  = readr::col_integer(),
            permkey = readr::col_integer(),
            year    = readr::col_integer(),
            .default = readr::col_character()
        ),
        show_col_types = FALSE
    )

    return(bushee)

}
