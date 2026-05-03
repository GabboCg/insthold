# Institutional Ownership Breadth

[![R](https://img.shields.io/badge/R-%3E%3D4.1-276DC3?logo=r&logoColor=white)](https://www.r-project.org/)
[![WRDS](https://img.shields.io/badge/Data-WRDS-003366)](https://wrds-www.wharton.upenn.edu/)

## Overview

An R pipeline to construct a quarterly panel of institutional ownership metrics for US common stocks using 13F filings (Thomson Reuters / WRDS) and CRSP monthly data, extended with [Bushee (1998, 2001)](https://accounting-faculty.wharton.upenn.edu/bushee/) investor-type classifications.

The output is `io_ts`: a stock × quarter dataset covering 2020–2025.

## Data Sources

| Source | Description | Access |
|---|---|---|
| `crsp.msf` + `crsp.msenames` | Monthly stock file, common stocks (shrcd 10–11) | WRDS |
| `tr_13f.s34type1` | 13F manager–quarter index (vintage dates) | WRDS |
| `tr_13f.s34type3` | 13F position-level holdings | WRDS |
| `crsp.msenames` | CUSIP → PERMNO mapping | WRDS |
| Bushee `iiclass.txt` | Investor type classification (DED/QIX/TRA) | [Wharton](https://accounting-faculty.wharton.upenn.edu/bushee/) |

A WRDS account with access to CRSP and Thomson Reuters 13F is required.

## Output Variables (`io_ts`)

| Variable | Description |
|---|---|
| `permno` | CRSP permanent security identifier |
| `rdate` | 13F report date (**calendar** quarter end: Mar 31, Jun 30, Sep 30, Dec 31) |
| `numowners` | Number of institutions holding the stock |
| `io_total` | Total adjusted shares held by institutions |
| `ioc_hhi` | Herfindahl–Hirschman Index of ownership concentration |
| `dbreadth` | Change in institutional breadth (Lehavy & Sloan 2008) |
| `p` | Adjusted price at quarter end |
| `tso` | Total shares outstanding (adjusted) |
| `me` | Market capitalisation (USD millions) |
| `ior` | Institutional ownership ratio (`io_total / tso`) |
| `io_missing` | 1 if stock has no 13F data in that quarter |
| `io_g1` | 1 if `ior > 1` (data quality flag) |
| `io_ded` | Ownership ratio — Dedicated institutions (Bushee) |
| `io_qix` | Ownership ratio — Quasi-indexers (Bushee) |
| `io_tra` | Ownership ratio — Transient institutions (Bushee) |

> **Note on the Bushee coverage gap.**
> `io_ded + io_qix + io_tra ≤ ior` in general.
> `ior` is computed from *all* 13F filers; the type-specific ratios only count
> managers that appear in `iiclass.txt` for the relevant year.
> The difference — `ior − (io_ded + io_qix + io_tra)` — represents ownership
> held by managers not classified by Bushee (new funds, foreign managers, or
> years outside his coverage). This residual is left implicit; it is not
> redistributed to any category.

---

## Breadth Formula

$$
\Delta\text{Breadth}_t = \frac{(\text{NumOwners}_t - \text{NewInst}_t) - (\text{NumOwners}_{t-1} - \text{OldInst}_{t-1})}{\text{NumInst}_{t-1}}
$$

where *NewInst* are first-time filers and *OldInst* are last-time filers in a given quarter. This corrects for universe changes driven by the \$100M AUM filing threshold (Lehavy & Sloan, 2008).

---

## Repository Structure

```
Insthold/
├── load.R                        # Main script — runs the full pipeline
├── R/
│   ├── get-crsp-m.R              # Step 1:   download CRSP, build crsp_qend
│   ├── get-insthold.R            # Steps 2–4: 13F merge, CUSIP map, share adjustment
│   └── get-bushee.R              # Step 7:   download Bushee investor classifications
└── data/
    ├── crso_m.csv                # CRSP quarter-end panel
    ├── insthold_13f_s34.rds      # Raw adjusted holdings (permno × rdate × mgrno)
    └── io_ts.rds                 # Final stock-quarter panel
```

---

## Usage

1. Set WRDS credentials in `load.R` (or via environment variables).
2. Adjust `start_date` / `end_date` as needed.
3. Run `load.R` from the project root:

```r
source("load.R")
```

The script produces:

- **`data/crso_m.csv`** — CRSP quarter-end panel (`permno × qdate`)
- **`data/insthold_13f_s34.rds`** — Raw adjusted holdings (`permno × rdate × mgrno`)
- **`data/io_ts.rds`** — Final stock-quarter panel with all ownership metrics

## References

- Bushee, B. J. (1998). The influence of institutional investors on myopic R&D investment behavior. *The Accounting Review*, 73(3), 305–333.
- Bushee, B. J. (2001). Do institutional investors prefer near-term earnings over long-run value? *Contemporary Accounting Research*, 18(2), 207–246.
- Lehavy, R., & Sloan, R. G. (2008). Investor recognition and stock returns. *Review of Accounting Studies*, 13(2–3), 327–361.
