**************************************************************************
*			
*		 Clean NPI data (state district category date level)
*
**************************************************************************
use     "$npipath/npi.dta", clear

/* strip timestamp from date */
ren       date              timestamp
gen       date            = dofc(timestamp)
format    date              %d
drop      timestamp         index

/* create cumulative changes for each state-district-category */
egen      npi_group       = group(state district category)
su        npi_group,        meanonly

save      "$npipath/npi_norm.dta",                   replace 
clear

/* generating category wise dates from covid data*/
local     start             mdy(1, 29, 2020)
local     end               mdy(8, 31, 2020)
local     time_period     = (`end' - `start')
set       obs               `time_period'

gen       date            = `start'  + _n
format    date              %d

/* filling in npi_change in dates for all state-district-category groups */
forvalues cat             = 1/`r(max)' {
	gen   npicat_`cat'    = 0 
}

/* npi change for each category on every date */
reshape   long              npicat_,     i(date)     j(npi_group)
ren 	  npicat_           npi_change_d

/* merging with npi status */
merge     1:m               npi_group    date        using     ///
"$npipath/npi_norm.dta",    gen(merge_dates)

save $tmp/reshaped, replace
use $tmp/reshaped, clear
/* not matched from using:  after Aug 31 
   not matched from master: missing dates in npi data*/


/* npi change for all dates in the time period */     
egen      npi_change      = rowtotal(npi npi_change_d)
drop      npi               npi_change_d

/* collapsing entries at state district date category level*/
bysort    npi_group date:   replace npi_change =     sum(npi_change)
by 	      npi_group date:   keep    if     _n ==     _N

/* generate cumulative closure level */
sort      date
gsort     npi_group         date    -npi_change
bys       npi_group:        gen     npi_status  = sum(npi_change)

/* rounding off decimal errors in npi_status*/
replace   npi_status      = 0       if            npi_status < 0

/* picking the normalizing factor */ 
bys       npi_group:        egen    tmp         = max(npi_status)
gen       npi_norm        = (npi_status/tmp)
sum       npi_norm
drop      tmp

/* replacing state district and category names */
gsort     npi_group         -district

foreach   var in            state district category {
	bys   npi_group:        replace `var' = `var'[_n-1] if `var' == ""
}

gsort     npi_group         date    -npi_change

/* preparing file to merge with infections and deaths data */
replace   state           = subinstr(state, "_", " ", .)
ren       district          lgd_district_name
ren       state             lgd_state_name
drop      npi_group         excel_row                merge_dates ///
          npi_change        npi_status
ren		  npi_norm          npi_		  

/* unique at state district category date level */
replace    category       = substr(category, 1, strrpos(category, " ") ///
 - 1)      if               inlist(word(category, -1), "closure", "order")

reshape    wide             npi_,                    j(category) ///
           i(lgd_state_name lgd_district_name date)  string
		   
/* constructing cumulative npi measure */
egen      npi_cu          = rowtotal(npi_border      npi_curfew ///
          npi_industry      npi_lockdown             npi_retail ///
		  npi_school        npi_temple               npi_transport)		   

/* construct 7 day moving averages for cumulative npi measure */
egen     district        = group(lgd_state_name      lgd_district_name)
xtset    district          date 
egen     av_npi_cu       = filter(npi_cu),           coef(1 1 1 1 1 1 1)      ///
         lags(-3/3)        normalise

/* rescale all NPI variables between 0 and 1 in each state (with assumption that March lockdown */
foreach v in npi_cu av_npi_cu {
  bys lgd_state_name: egen state_max = max(`v')
  gen      `v'_scale    = `v' / state_max
  drop state_max
}

/* set up as panel */
egen      sdgroup                     = group(date   lgd_state_name)
label     var                         sdgroup        "state-date group"
xtset     district 					  date 
encode    lgd_state_name,             gen(state)

/* consistent districts for delhi */
drop if   lgd_district_name ==        "central" &    lgd_state_name == "delhi"
drop if   lgd_district_name ==        "shahdara" &   lgd_state_name == "delhi"
drop if   lgd_district_name ==        "south east" & lgd_state_name == "delhi"
		   
/* saving cleaned dataset */
save     "$npipath/npi_clean.dta",                   replace 
