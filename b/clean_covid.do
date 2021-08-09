******************************************************************************
*
*          Clean COViD data (state district date level)
*
******************************************************************************

/* open raw covid infection / death data */
use   "$npipath/covid_infected_deaths.dta",        clear

/* keep states with npi_status */
keep  if  inlist(              lgd_state_name,           "andhra pradesh",       ///
		  "bihar",             "delhi",                  "karnataka",            ///
          "maharashtra",       "tamil nadu")
		  
/* consistent variable name for COVID deaths */
rename    total_deaths         total_death		  
		  
/* create numeric district identifier and set as time series */
egen       district            = group(lgd_state_name    lgd_district_name)
xtset      district            date

/* drop state and district names not reported in covid data */
gsort      district            date

/* this loop no longer does anything. confirm this with an assertion */
// forval     i = 1/50 {
//            replace             total_death              = F.total_death        ///
// 		   if                  !mi(F.total_death)       & mi(total_death)
// }
assert ! (!mi(F.total_death) & mi(total_death))

/* create 7 day moving averages for cumulative deaths */
egen       av_death            = filter(total_death),  coef(1 1 1 1 1 1 1)      ///
           lags(-3/3)          normalise
label var  av_death            "7-day moving average cumulative deaths"		   

/* generate log deaths */
gen        log_death       = ln(1 + total_death)
label var  log_death       "log of total deaths in a district"

/* gen 14-day delayed date for death count */
gen        date_p14            = date + 14

/* generate weekly district-level growth rate in deaths */
gen        death_growth        = log_death - L14.log_death

/* push death growth rate forward 14 days to line up with NPIs with a 2-week lag */
replace    death_growth        = F14.death_growth

/* create a winsorized death growth rate. The deaths <0 are all data errors in places with <2 deaths/day, so not a big deal to set these to zero */
gen        death_growth_w      = death_growth
replace    death_growth_w      = 0                       if death_growth_w < 0
sum        death_growth_w,     d
replace    death_growth_w      = `r(p95)'                if  death_growth_w > `r(p95)' ///
&          !mi(death_growth_w)

drop       district		   

/* saving cleaned dataset */
save "$npipath/covid_clean.dta",                   replace
