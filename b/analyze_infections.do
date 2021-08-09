*******************************************************************************
*
* 						Analyze COVID infections and NPI
*
*******************************************************************************

/* open covid infection and death data */
use       "$npipath/covid_clean.dta", clear

/* merge with NPI data */
merge 1:1 lgd_state_name              lgd_district_name date ///
		  using 		              "$npipath/npi_clean.dta", ///
		  gen(merge_infections)
		  
/* limit time line for merged data */
// keep  if  date >= td(1may2020)        & date <= td(31aug2020)		  
keep  if  date >= td(2mar2020)        & date <= td(31aug2020)

/* assert the only data that didn't match NPIs is from deaths without district reported */
assert merge_infections == 3 if lgd_district_name != "not reported"

/* trim to last date in august with full data */
sum death_growth, d
drop  if  date > td(28aug2020)

/* initiate graph style */
grstyle   init
grstyle   set                         plain,                    horizontal       ///
          grid

/**************************************/
/* create analysis dataset for graphs */
/**************************************/
preserve

/* collapse across districts for state-level graphs */
collapse (rawsum) av_death ///
    (mean)	av_npi_cu_scale, ///
    by(lgd_state_id lgd_state_name date)

/* calculate log deaths at collapsed state level */
gen      log_av_death                 = ln(1 + av_death)

/* calculate growth rates in collapsed data */
egen     lgroup                       = group(lgd_state_name)
xtset    lgroup                       date

gen      death_growth                 = log_av_death - L14.log_av_death
replace  death_growth                 = F14.death_growth

/* save the graph analysis dataset */
save "$tmp/npi_graphs", replace

restore

/**************************************/
/* create x-district analysis dataset */
/**************************************/

/* drop deaths without a reported district */
drop if inlist(lgd_district_name, "not reported")

/* drop delhi, where no deaths have rep */
drop if lgd_state_name == "delhi"

/* set as time series */
xtset      district            date

/* save regression analysis dataset */
save "$tmp/npi_regs", replace

*******************************************************************************
* 								Graphs
*******************************************************************************
		  

/*****************************************/
/* FIGURE 2: NPI vs. DEATH RATE BY STATE */
/*****************************************/
use "$tmp/npi_graphs", clear

/* replace death growth to zero when fewer that 1 new case pe */

/* Plot 7 day moving averages by state */
levelsof lgd_state_name, local(states)
foreach s in `states' {
 	graph	 twoway line ///
       log_av_death date 								 ///
       if 		 lgd_state_name == "`s'" & !mi(av_npi_cu_scale),	 title("`s'") 		 ///
       ytitle("log(Death)")		 || ///
       line 	 av_npi_cu_scale date 			 /// 
       if lgd_state_name == "`s'" & !mi(log_av_death),	 yaxis(2) 	 ///
       ytitle("NPI Intensity", axis(2)) 							 ///
       xtitle("Days") 				 legend(order(1 ///
       "Death Rates (7 day ma)" 2 "NPI Intensity (7 day ma)")) 
   
   graph export "$npicode/a/graph_log_av_death_`s'.png", ///
       replace

  /* try the plot with growth rates */

	graph	 twoway line ///
      death_growth date 								 ///
      if 		 lgd_state_name == "`s'" & !mi(av_npi_cu_scale),	 title("`s'") 						 ///
      ytitle("Death Growth Rate")		 || ///
      line 	 av_npi_cu_scale date 			 /// 
      if lgd_state_name == "`s'" & !mi(death_growth),	 yaxis(2) 		 			 ///
      ytitle("NPI Intensity", axis(2)) 							 ///
      xtitle("Days") 				 legend(order(1 ///
      "Death Growth Rates (7 day ma)" 2 "NPI Intensity (7 day ma)")) 
  
  graph export "$npicode/a/graph_death_growth_`s'.png", ///
      replace
}

	
*******************************************************************************
* 								Regressions
*******************************************************************************	

/***************************************************************************/
/* TABLE 1: state-by-state regression with district and date fixed effects */
/***************************************************************************/
use "$tmp/npi_regs", clear

levelsof lgd_state_name, local(states)
foreach s in `states' {

  di "STATE: `s'"
 
  quireg death_growth_w npi_cu_scale if lgd_state_name == "`s'", absorb(date sdgroup district)
 
}

/****************************************************************/
/* TABLE X: COMBINED NPI vs DEATHS, WITHOUT MAHARASHTRA */
/****************************************************************/
use "$tmp/npi_regs", clear

/* combined regression with district, date and state * date fixed effects */


quireg death_growth_w            npi_cu_scale, absorb(date sdgroup district)


/* regression with district, date and state * date fixed effects, without maharashtra */
quireg death_growth_w            npi_cu_scale     if             lgd_state_name != "maharashtra" ,  ///
		absorb(date sdgroup district)

/***********************************************************/
/* TABLE X: SAME REGRESSION BUT ONE INTERVENTION AT A TIME */
/***********************************************************/
use "$tmp/npi_regs", clear

/* regress growth rate in deaths on interventions: district, date and state * date fixed effects */ 

/* drop maharashtra, since we don't think it helps identify npi->deaths due to reverse causality */ 
drop if state == 5

foreach var in ///
    border curfew industry lockdown retail temple transport school {

  /* regress with result displayed */
  quireg death_growth_w npi_`var' , absorb(date district sdgroup) title("`var'")
}
