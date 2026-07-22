/*=============================================================================
  STOCK MARKET BUBBLES AND BANK SYSTEMIC RISK: EVIDENCE FROM VIETNAM
  Clean Stata coding sample

  Author: Kien Nguyen
  Software: Stata 17 

  Research context
  ----------------
  This coding sample adapts the empirical framework of Brunnermeier, Rother,
  and Schnabel (2019) to the Vietnamese banking sector. The implementation
  follows the methodology described in the accompanying thesis and is adjusted
  to the availability and frequency of Vietnamese data. Bubble length and
  bubble size variables from the original working file are omitted because
  they are not used in the reported regressions.

  Input-file selection
  --------------------
  When this do-file starts, Stata opens three file-selection windows. Select
  bank1.xlsx, bank2.xlsx, and Final Data.xlsx in that order. No cd command or
  manually entered folder path is required.

  Run the complete file from the top in the Do-file Editor.
=============================================================================*/

version 17.0
clear all
set more off
capture log close _all

/*=============================================================================
  0. SELECT INPUT FILES AND SET THE OUTPUT FOLDER
=============================================================================*/

capture window fopen BANK_FILE_1 ///
    "Step 1 of 3: Select bank1.xlsx" ///
    "Excel files (*.xlsx)|*.xlsx|All files (*.*)|*.*" xlsx
if _rc != 0 {
    display as error "No bank1.xlsx file was selected."
    exit 601
}

capture window fopen BANK_FILE_2 ///
    "Step 2 of 3: Select bank2.xlsx" ///
    "Excel files (*.xlsx)|*.xlsx|All files (*.*)|*.*" xlsx
if _rc != 0 {
    display as error "No bank2.xlsx file was selected."
    exit 601
}

capture window fopen MAIN_FILE ///
    "Step 3 of 3: Select Final Data.xlsx" ///
    "Excel files (*.xlsx)|*.xlsx|All files (*.*)|*.*" xlsx
if _rc != 0 {
    display as error "No Final Data.xlsx file was selected."
    exit 601
}

confirm file "${BANK_FILE_1}"
confirm file "${BANK_FILE_2}"
confirm file "${MAIN_FILE}"

global OUTPUT "`c(pwd)'/output"
capture mkdir "${OUTPUT}"

tempfile bank1 bank annual_bank macro vni_boom_bust ///
         weekly_bank vn100 vni_vol22 delta_covar final_data

/* Required user-written commands:
   radf, rangestat, csipolate, winsor2, and asdoc. */

/*=============================================================================
  1. ANNUAL BANK FINANCIAL STATEMENTS
=============================================================================*/

import excel using "${BANK_FILE_1}", ///
    sheet("data") firstrow case(lower) clear

sort id_code
save `bank1'

import excel using "${BANK_FILE_2}", ///
    sheet("Sheet3") firstrow case(lower) clear

sort id_code
merge 1:1 id_code using `bank1'
drop _merge

* Reshape annual bank variables from wide to long format.
reshape long duphong_chovay no_tw nopt tctd_gui vay_tctd tg_kh ///
    vonchu tts tm tm_nhtw tg_tctd chovay_tctd duphong chovay ///
    chovay1_, i(id_code) j(year)

save `annual_bank'

/*=============================================================================
  2. QUARTERLY MACROECONOMIC CONTROLS
=============================================================================*/

import excel using "${MAIN_FILE}", ///
    sheet("Macro controls") firstrow case(lower) clear

* Convert the monthly identifier to a quarterly identifier.
generate str2 m_str = substr(month, 6, 2)
generate m = real(m_str)
recode m (1/3 = 1) (4/6 = 2) (7/9 = 3) (10/12 = 4), generate(q)

generate str4 y_str = substr(month, 1, 4)
encode y_str, generate(y)
tostring q, generate(q_str)

generate str6 quarter = y_str + "-" + q_str

* Aggregate monthly variables to quarterly means.
egen double cpi = mean(cpimonthly), by(quarter)
egen double rate10 = mean(bond_yield_10ymonthly), by(quarter)

keep quarter real_gdpquarterly cpi rate10
duplicates drop

* Original macroeconomic transformations.
generate qdate = quarterly(quarter, "YQ")
format qdate %tq
sort qdate

generate double lgdp = log(real_gdpquarterly)
generate double dlgdp = lgdp[_n] - lgdp[_n-1]

generate double lcpi = log(cpi)
generate double dlcpi = lcpi - lcpi[_n-1]

generate double lrate10 = log(rate10)

keep qdate dlgdp dlcpi lrate10
sort qdate
save `macro'

/*=============================================================================
  3. VN-INDEX BUBBLE, BOOM, AND BUST VARIABLES
=============================================================================*/

import excel using "${MAIN_FILE}", ///
    sheet("VNI") firstrow case(lower) clear

generate qdate = qofd(date)
format qdate %tq

* Construct the end-of-quarter VN-Index.
sort qdate date
by qdate: generate double vnindex = vni[_N]

keep qdate vnindex
duplicates drop
isid qdate

* Estimate the BSADF test.
tsset qdate
radf vnindex, pre(vnindex_) bs graph

* Construct the aggregate bubble indicator from the 95% threshold.
generate byte vni_bubble = vnindex_Exceeding95

* Drop observations for which the BSADF indicator is unavailable.
drop if missing(vni_bubble)

sort qdate
tsset qdate

* Identify the beginning of each consecutive BSADF-dated bubble episode.
generate byte bubble_start = ///
    vni_bubble == 1 & L.vni_bubble != 1

* Assign a unique identifier to each bubble episode.
generate long bubble_id = sum(bubble_start)
replace bubble_id = . if vni_bubble == 0

* Identify the maximum VN-Index level within each bubble episode.
bysort bubble_id: egen double episode_peak = max(vnindex) ///
    if vni_bubble == 1

* Identify the first quarter in which the episode peak is reached.
generate double peak_candidate = qdate ///
    if vni_bubble == 1 & vnindex == episode_peak

bysort bubble_id: egen double peak_qdate = min(peak_candidate)
format peak_qdate %tq

* The boom phase runs from the beginning of the episode through its peak.
generate byte vni_boom = ///
    vni_bubble == 1 & qdate <= peak_qdate

* The bust phase runs from the quarter after the peak to the end of the episode.
generate byte vni_bust = ///
    vni_bubble == 1 & qdate > peak_qdate

* Verify that every bubble quarter is classified exactly once.
assert vni_bubble == vni_boom + vni_bust
assert !(vni_boom == 1 & vni_bust == 1)

* Verify the six-month minimum-duration requirement.
capture drop episode_length

bysort bubble_id (qdate): generate episode_length = _N ///
    if !missing(bubble_id)

assert episode_length >= 2 if !missing(bubble_id)

* Display automatically dated episodes in chronological order.
sort bubble_id qdate

list bubble_id qdate vnindex peak_qdate ///
    episode_length vni_bubble vni_boom vni_bust ///
    if vni_bubble == 1, sepby(bubble_id) noobs

* Only now remove the temporary dating variables.
keep qdate vni_bubble vni_boom vni_bust

sort qdate
isid qdate

save "${OUTPUT}/vni_boom_bust.dta", replace

/*=============================================================================
  4. WEEKLY DELTA-COVAR
=============================================================================*/

/*-----------------------------------------------------------------------------
  4.1 Weekly bank losses and the value-weighted system loss
-----------------------------------------------------------------------------*/

import excel using "${MAIN_FILE}", ///
    sheet("bank stock daily") firstrow case(lower) clear

generate w_id = dow(date)
keep if w_id == 5

rename market_capitalization mv

* The original condition "m == 0" was a variable-name typo; mv is intended.
drop if mv == . | mv == 0

sort bank_id date
keep bank_id date mv

by bank_id: generate double x = -(mv / mv[_n-1] - 1)
by bank_id: generate double mv_lag = mv[_n-1]

sort date
by date: egen double mv_all = total(mv_lag)
by date: egen double x_s = total(mv_lag * x / mv_all)

sort bank_id date
save `weekly_bank'

/*-----------------------------------------------------------------------------
  4.2 Weekly VN100 return
-----------------------------------------------------------------------------*/

import excel using "${MAIN_FILE}", ///
    sheet("VN100") firstrow case(lower) clear

generate w_id = dow(date)
keep if w_id == 5

sort date
generate double r_vn100_w = vn100 / vn100[_n-1] - 1
save `vn100'

/*-----------------------------------------------------------------------------
  4.3 VN-Index 22-trading-day rolling volatility
-----------------------------------------------------------------------------*/

import excel using "${MAIN_FILE}", ///
    sheet("VNI") firstrow case(lower) clear

sort date 
generate t = _n
rangestat (sd) vni_vol22 = vni, interval(t -21 0)
keep if t >= 22

generate w_id = dow(date)
keep if w_id == 5
keep date vni_vol22
save `vni_vol22'

/*-----------------------------------------------------------------------------
  4.4 Merge weekly variables and estimate Delta-CoVaR
-----------------------------------------------------------------------------*/

use `weekly_bank', clear
merge m:1 date using `vn100', nogen
merge m:1 date using `vni_vol22', nogen

drop if bank_id == ""
sort bank_id date

by bank_id: generate double r_vn100_l1 = r_vn100_w[_n-1]
by bank_id: generate double vni_vol22_l1 = vni_vol22[_n-1]

keep bank_id date x x_s r_vn100_l1 vni_vol22_l1

generate beta_s = .
generate double delta_covar_w = .

global m1 r_vn100_l1 vni_vol22_l1
levelsof bank_id, local(ids)

quietly foreach id of local ids {
    tempvar x_i x_i_50

    * Bank-specific tail sensitivity.
    qreg x_s x $m1 if bank_id == "`id'", q(0.98)
    replace beta_s = _b[x] if bank_id == "`id'"

    * Bank VaR at the 98th conditional quantile.
    qreg x $m1 if bank_id == "`id'", q(0.98)
    predict double `x_i' if bank_id == "`id'"

    * Bank VaR at the conditional median.
    qreg x $m1 if bank_id == "`id'", q(0.5)
    predict double `x_i_50' if bank_id == "`id'"

    * Weekly Delta-CoVaR.
    replace delta_covar_w = beta_s * (`x_i' - `x_i_50') ///
        if bank_id == "`id'"

    drop `x_i' `x_i_50'
}

generate qdate = qofd(date)
sort bank_id qdate
by bank_id qdate: egen double delta_covar = mean(delta_covar_w)

keep bank_id qdate delta_covar
duplicates drop
summarize delta_covar

sort bank_id qdate
save `delta_covar'

/*=============================================================================
  5. MERGE DATA AND INTERPOLATE ANNUAL BANK VARIABLES
=============================================================================*/
merge m:1 qdate using `macro', nogen
merge m:1 qdate using "${OUTPUT}/vni_boom_bust.dta", nogen

drop if bank_id == ""

generate year = year(dofq(qdate))
rename bank_id id_code

ds
global qvars `r(varlist)'

merge m:1 id_code year using `annual_bank', nogen
drop if qdate == .

ds $qvars stt id_name exchange, not
global yvars `r(varlist)'

sort id_code year qdate
foreach var of global yvars {
    by id_code year: replace `var' = . if _n < _N
}

by id_code year: generate byte q_id = _n

/* Consistent quarterly bank financial statements are unavailable for the full
   sample. Annual balance-sheet variables are therefore converted to quarterly
   frequency using cubic-spline interpolation, following the frequency-
   conversion approach used in the reference study. */
foreach var of global yvars {
    by id_code: csipolate `var' qdate, generate(`var'1)
}

* Bank size.
generate double size = log(tts1)

* Loan growth.
generate double lloans = log(chovay1)
sort id_code qdate
by id_code: generate double dlloans = lloans - lloans[_n-1]

* Leverage.
generate double lev = tts1 / vonchu1

keep $qvars size dlloans lev exchange

* Verify the boom-bust decomposition.
assert vni_bubble == vni_boom + vni_bust ///
    if !missing(vni_bubble, vni_boom, vni_bust)

sort id_code qdate
save `final_data'

/*=============================================================================
  6. FINAL SAMPLE AND PANEL REGRESSIONS
=============================================================================*/

use `final_data', clear
keep if inrange(qdate, tq(2009q1), tq(2024q4))

* Original pooled 1st/99th percentile winsorization.
winsor2 delta_covar size dlloans lev, replace

encode id_code, generate(id)
xtset id qdate

* COVID-19 period indicator.
generate byte covid = inrange(qdate, tq(2020q1), tq(2021q4))
label define covid_lbl 0 "Non-COVID" 1 "COVID"
label values covid covid_lbl

global bank size dlloans lev
global macro dlgdp dlcpi lrate10

/*-----------------------------------------------------------------------------
  6.1 Descriptive-statistics sample
-----------------------------------------------------------------------------*/

* Define the descriptive-statistics sample using the boom-bust specification.
quietly xtreg delta_covar vni_boom vni_bust ///
    size dlloans lev $macro, fe vce(cluster id)

generate byte sample = e(sample)

summarize delta_covar vni_bubble vni_boom vni_bust ///
    size dlloans lev $macro if sample == 1

/*-----------------------------------------------------------------------------
  6.2 Bank fixed-effects regressions
-----------------------------------------------------------------------------*/

xtreg delta_covar vni_bubble size dlloans lev $macro, ///
    fe vce(cluster id)

xtreg delta_covar vni_boom vni_bust size dlloans lev $macro, ///
    fe vce(cluster id)

* Test whether the boom and bust coefficients are equal.
test vni_boom = vni_bust
lincom vni_bust - vni_boom

/*-----------------------------------------------------------------------------
  6.3 Bank fixed effects and seasonal-quarter indicators
-----------------------------------------------------------------------------*/

capture drop qtr
generate qtr = quarter(dofq(qdate))
label define qtr_lbl 1 "Q1" 2 "Q2" 3 "Q3" 4 "Q4", replace
label values qtr qtr_lbl

xtreg delta_covar vni_bubble size dlloans lev $macro i.qtr, ///
    fe vce(cluster id)

xtreg delta_covar vni_boom vni_bust size dlloans lev $macro i.qtr, ///
    fe vce(cluster id)

/*-----------------------------------------------------------------------------
  6.4 COVID-19 robustness checks
-----------------------------------------------------------------------------*/

* Exclude the COVID-19 period.
xtreg delta_covar vni_bubble size dlloans lev $macro ///
    if sample == 1 & covid == 0, fe vce(cluster id)

xtreg delta_covar vni_boom vni_bust size dlloans lev $macro ///
    if sample == 1 & covid == 0, fe vce(cluster id)

* Control for the COVID-19 period.
xtreg delta_covar vni_bubble covid size dlloans lev $macro ///
    if sample == 1, fe vce(cluster id)

xtreg delta_covar vni_boom vni_bust covid size dlloans lev $macro ///
    if sample == 1, fe vce(cluster id)

/*=============================================================================
  7. FIGURE AND DIAGNOSTIC CHECKS
=============================================================================*/

* Plot the dependent variable.
preserve

collapse (mean) delta_covar, by(qdate)
sort qdate

local xmin     = tq(2009q1)
local xmax     = tq(2025q1)
local xlabmin  = tq(2009q1)
local xlabmax  = tq(2025q1)

twoway ///
    (line delta_covar qdate, ///
        lcolor(midblue) lwidth(medthick)), ///
    xscale(range(`xmin' `xmax')) ///
    xlabel(`xlabmin'(8)`xlabmax', ///
        format(%tq) labsize(small)) ///
    ylabel(, format(%6.3f) labsize(small) angle(horizontal)) ///
    xtitle("") ///
    ytitle("Mean Delta-CoVaR") ///
    title("Bank systemic risk over time", ///
        size(medsmall)) ///
    subtitle("Quarterly average across listed Vietnamese banks", ///
        size(small)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(fig_delta_covar, replace)

graph export "${OUTPUT}/mean_delta_covar.pdf", replace
graph export "${OUTPUT}/mean_delta_covar.png", ///
    width(2400) replace

restore

* Pairwise correlation matrix.
asdoc pwcorr delta_covar vni_bubble vni_boom vni_bust ///
    size dlloans lev $macro, sig star(0.05) dec(3) ///
    save(output/corr_matrix1.doc) replace

* Variance inflation factors: aggregate bubble specification.
preserve
    sort id qdate
    quietly foreach var of varlist delta_covar vni_bubble ///
        size dlloans lev $macro {
        by id: egen double `var'_i = mean(`var')
        summarize `var', meanonly
        replace `var' = `var' - `var'_i + r(mean)
    }

    quietly regress delta_covar vni_bubble size dlloans lev $macro
    asdoc vif, dec(3) save(output/vif1.doc) replace label
restore

* Variance inflation factors: separate boom and bust specification.
preserve
    sort id qdate
    quietly foreach var of varlist delta_covar vni_boom vni_bust ///
        size dlloans lev $macro {
        by id: egen double `var'_i = mean(`var')
        summarize `var', meanonly
        replace `var' = `var' - `var'_i + r(mean)
    }

    quietly regress delta_covar vni_boom vni_bust ///
        size dlloans lev $macro
    asdoc vif, dec(3) save(output/vif2.doc) replace label
restore

save "${OUTPUT}/analysis_panel.dta", replace
display as result "Analysis completed. Files are saved in ${OUTPUT}."
shell open "${OUTPUT}"
