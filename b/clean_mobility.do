*******************************************************************************
*
*		Clean Mobility Data (state district data level)
*
*******************************************************************************
import    delimited                    "$npipath/google_mobility.csv", clear

/* renaming variables to merge with mobility key */
gen        lgd_state_name              = lower(sub_region_1)
gen        lgd_district_name_google    = lower(sub_region_2)
drop       sub_region_1 sub_region_2 

/* keeping states with npi_status */
keep   if  inlist(lgd_state_name,      "andhra pradesh",                  ///
                  "bihar",             "delhi",                           ///
				  "karnataka",         "maharashtra",                     ///  
				  "tamil nadu")

/* dropping missing variables */				  
drop   if  lgd_district_name_google == ""	
drop       country_region_code         country_region                     ///
           metro_area                  iso_3166_2_code                    ///
		   census_fips_code                                               ///

/* formatting date */
ren        date                        date_string
gen        date                        = date(date_string, "YMD")
format     date                        %d
drop       date_string

/* merging with mobility keys */
merge  m:1 lgd_district_name_google    lgd_state_name                      ///
           using                       "$npipath/google_district_key.dta", ///
		   gen(mobility_key)
		   
/* preparing for merge with npi data */		   
replace    lgd_district_name           = lgd_district_name_google          ///
       if  lgd_district_name==""
drop       mobility_key                lgd_district_name_google 


/* renaming variables */
ren        residential_percent_change_from_                               ///
		   stay_home 
		   
/* create 7 day moving averages for variables */
egen       district                    = group(lgd_state_name            ///
                                         lgd_district_name)
xtset      district                    date 
egen       av_stay_home                = filter(stay_home),              ///
           coef(1 1 1 1 1 1 1)         lags(-3/3)                        ///
		   normalise
drop       district		   	   
	
/* saving for merge */
save       "$npipath/mobility_clean.dta",                                 ///
           replace	  