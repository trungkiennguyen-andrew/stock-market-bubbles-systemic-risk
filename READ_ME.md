# Coding Sample: Stock Market Bubbles and Bank Systemic Risk

**Author:** Nguyen Trung Kien
**Software:** Stata 17 or later

## Overview

This coding sample accompanies my undergraduate thesis, *Stock Market Bubbles and Bank Systemic Risk: Evidence from Vietnam*. The Stata do-file constructs the analysis dataset, identifies stock-market bubble episodes, estimates bank-level systemic risk, runs the main panel regressions and robustness checks, and produces diagnostic outputs.

The final regression sample is an unbalanced panel of 28 listed Vietnamese commercial banks from 2009Q1 to 2024Q4, comprising 884 bank-quarter observations.

## Data

The code uses three Excel workbooks containing:

1.  annual bank financial statements;
2.  quarterly macroeconomic variables; and
3.  daily bank-stock, VN-Index, and VN100 market data.

The source workbooks are not included because the underlying bank and market data are licensed or proprietary. When the do-file is run, Stata prompts the user to select the required workbooks. They should be selected in the following order:

1.  the workbook containing annual bank data, including sheet `data`;
2.  the workbook containing the additional bank variable, including sheet `Sheet3`; and
3.  the main market and macroeconomic workbook, including sheets `Macro controls`, `VNI`, `bank stock daily`, and `VN100`.

The filenames may differ, but the sheet names and variable structure must match those expected by the do-file.

## Stata Requirements

The following user-written Stata commands must be installed before running the code:

-   `radf`
-   `rangestat`
-   `csipolate`
-   `winsor2`
-   `asdoc`

If a command is unavailable, it can be located in Stata using `findit command_name` and installed from the search results.

## How to Run the Code

1.  Open the main `.do` file in Stata.
2.  Run the file from beginning to end.
3.  Select the three input workbooks in the order listed above when prompted.
4.  Allow the program to complete without running individual sections out of sequence.

The script creates an `output` folder automatically in the current working directory. The output path can be checked after execution using: shell open "\${OUTPUT}"

## Empirical Workflow

The do-file performs the following steps:

1.  imports, cleans, merges, and reshapes the annual bank-level accounting data;
2.  imports and prepares the quarterly macroeconomic controls;
3.  identifies VN-Index bubble episodes from BSADF statistics and bootstrap critical values;
4.  separates each retained episode into boom and bust phases at its global within-episode VN-Index peak;
5.  estimates weekly bank-level Delta-CoVaR and aggregates it to quarterly frequency;
6.  interpolates annual accounting variables to quarterly frequency using cubic splines;
7.  constructs the final bank-quarter panel and applies the sample restrictions;
8.  estimates the baseline fixed-effects models and robustness specifications; and
9.  produces the systemic-risk figure, correlation matrix, and variance-inflation-factor diagnostics.

## Main Variable Construction

### Bubble, Boom, and Bust Indicators

A bubble episode is a maximal sequence of consecutive quarters in which the BSADF statistic exceeds its corresponding 95 percent right-tailed bootstrap critical value. An episode must last for at least two consecutive quarters, corresponding to approximately six months.

Within each retained episode, the boom phase runs from episode inception through the quarter containing the global VN-Index peak. The bust phase begins in the following quarter and continues through episode termination. The indicators are mutually exclusive and satisfy:

Bubble = Boom + Bust

The classification is implemented algorithmically; no bubble, boom, or bust dates are assigned manually. The full VN-Index series produces two retained episodes: 2006Q4-2007Q3 and 2017Q3-2018Q3. Because the bank-level regression sample begins in 2009Q1, only the second episode enters the regression analysis.

### Bank-Level Systemic Risk

Bank-level systemic risk is measured using Delta-CoVaR estimated from weekly equity losses. CoVaR is estimated at the 98th conditional quantile and compared with its median-state counterpart. The conditioning variables include the lagged VN100 weekly return and the lagged 22-trading-day rolling standard deviation of the VN-Index level.

### Accounting Variables

Annual total assets, total loans, and total equity are interpolated separately for each bank using cubic-spline interpolation before the corresponding quarterly control variables are constructed. The resulting values are smoothed within-year estimates and do not represent newly observed accounting information.

Before the regression analysis, the dependent variable and continuous bank-level control variables are winsorized at the 1st and 99th percentiles.

## Econometric Specifications

The main specifications relate bank-level Delta-CoVaR to either the aggregate bubble indicator or the separate boom and bust indicators. All baseline models include bank fixed effects, bank-level controls, macroeconomic controls, and standard errors clustered at the bank level.

The do-file also reports:

-   a Wald test of equality between the boom- and bust-phase coefficients;
-   specifications with seasonal fixed effects;
-   regressions excluding 2020Q1-2021Q4; and
-   regressions that retain the full sample and include a COVID-period indicator.

## Output Files

After successful execution, the `output` folder contains:

-   `vni_boom_bust.dta` --- quarterly bubble, boom, and bust indicators;
-   `analysis_panel.dta` --- final bank-quarter analysis dataset;
-   `mean_delta_covar.pdf` and `mean_delta_covar.png` --- mean Delta-CoVaR figure;
-   `corr_matrix1.doc` --- pairwise correlation matrix;
-   `vif1.doc` --- VIF diagnostics for the aggregate bubble specification; and
-   `vif2.doc` --- VIF diagnostics for the boom--bust specification.

Regression estimates and hypothesis-test results are displayed in Stata's Results window.

## Reproducibility Notes

-   Run the do-file from the beginning because later sections depend on temporary files and variables created earlier.
-   Do not change the expected worksheet names unless the corresponding `sheet()` options are also updated.
-   Results may differ across software or package versions because the bubble critical values are obtained through bootstrap simulation.

## Authorship and Methodological References

The do-file was prepared by Nguyen Trung Kien for the accompanying undergraduate thesis. The empirical procedures draw on established methods for BSADF bubble dating, peak-based boom-bust classification, and CoVaR estimation. Full methodological references and discussion are provided in the thesis.

