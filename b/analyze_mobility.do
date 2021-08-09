******************************************************************************
*
*				Analyze Mobility and NPI
*
*****************************************************************************

grstyle init
grstyle set plain, horizontal ///
    grid

use "$npipath/mobility_clean.dta", clear

/* merge with NPI data */
merge 1:1 lgd_state_name lgd_district_name date ///
    using "$npipath/npi_clean.dta", ///
    gen(merge_mobility)

/* limit time line for merged data */
keep if date >= td(1mar2020) & date <= td(31aug2020) 

/* drop districts missing in NPI data after merge */
drop if inlist(lgd_district_name, "chengalpattu", " kallakurichi", "ranipet", ///
    "sitamarhi", "tenkasi", "tirupathur", ///
    "tuticorin") 

/* drop districts that didn't merge */
drop if merge_mobility != 3

/****************************************************/
/* create mobility graph data (state-date collapse) */
/****************************************************/

preserve
collapse (mean) av_stay_home ///
    (mean) av_npi_cu_scale, ///
    by(lgd_state_name date)

/* save state-date level mobility dataset */
save "$tmp/mobility_graph", replace
restore

/*****************************/
/* create regression dataset */
/*****************************/

/* drop delhi which has no district disaggregated data */
drop if lgd_state_name == "delhi"

/* save the district data for the mobility regressions */
save "$tmp/mobility_regs", replace

/**********************/
/* state-level graphs */
/**********************/
use "$tmp/mobility_graph", clear

/* stay-at-home and lockdown trends by state (7 day moving average) */
levelsof lgd_state_name, local(states)
foreach s in `states' {
  graph twoway line ///
      av_stay_home date ///
      if lgd_state_name == "`s'", title("`s'") ///
      ytitle("Population at Home (change from baseline)") || ///
      line av_npi_cu date /// 
      if lgd_state_name == "`s'", yaxis(2) ///
      ytitle("NPI Intensity", axis(2)) ///
      xtitle("Days") legend(order(1 ///
      "Population at Home (7 day ma)" 2 "NPI Intensity (7 day ma)")) 
  
  graph export "$npicode/a/graph_av_home_lockdown_`s'.png", ///
      replace

}

*******************************************************************************
* Regressions
******************************************************************************* 
use "$tmp/mobility_regs", clear

/* state-by-state regression with district and date fixed effects */
levelsof lgd_state_name, local(states)
foreach s in `states' {
  di "STATE: `s'"
  quireg stay_home npi_cu_scale if lgd_state_name == "`s'", absorb(date sdgroup district)

}

/* combined regression with district and date fixed effects*/ 
quireg stay_home npi_cu_scale, absorb(date sdgroup district)
