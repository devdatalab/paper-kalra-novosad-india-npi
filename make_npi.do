/**********************************************************************************************/
/* program quireg : display a name, beta coefficient and p value from a regression in one line */
/***********************************************************************************************/
cap prog drop quireg
prog def quireg, rclass
{
  syntax varlist(fv ts) [pweight aweight] [if], [cluster(varlist) title(string) vce(passthru) noconstant s(real 40) absorb(varlist) disponly robust]
  tokenize `varlist'
  local depvar = "`1'"
  local xvar = subinstr("`2'", ",", "", .)

  if "`cluster'" != "" {
    local cluster_string = "cluster(`cluster')"
  }

  if mi("`disponly'") {
    if mi("`absorb'") {
      cap qui reg `varlist' [`weight' `exp'] `if',  `cluster_string' `vce' `constant' robust
      if _rc == 1 {
        di "User pressed break."
      }
      else if _rc {
        display "`title': Reg failed"
        exit
      }
    }
    else {
      /* if absorb has a space (i.e. more than one var), use reghdfe */
      if strpos("`absorb'", " ") {
        cap qui reghdfe `varlist' [`weight' `exp'] `if',  `cluster_string' `vce' absorb(`absorb') `constant' 
      }
      else {
        cap qui areg `varlist' [`weight' `exp'] `if',  `cluster_string' `vce' absorb(`absorb') `constant' robust
      }
      if _rc == 1 {
        di "User pressed break."
      }
      else if _rc {
        display "`title': Reg failed"
        exit
      }
    }
  }
  local n = `e(N)'
  local b = _b[`xvar']
  local se = _se[`xvar']

  quietly test `xvar' = 0
  local star = ""
  if r(p) < 0.10 {
    local star = "*"
  }
  if r(p) < 0.05 {
    local star = "**"
  }
  if r(p) < 0.01 {
    local star = "***"
  }
  di %`s's "`title' `xvar': " %10.5f `b' " (" %10.5f `se' ")  (p=" %5.2f r(p) ") (n=" %6.0f `n' ")`star'"
  return local b = `b'
  return local se = `se'
  return local n = `n'
  return local p = r(p)
}
end
/* *********** END program quireg **********************************************************************************************/

global npipath data
global npicode .

/* NOTE: NEED TO SET $tmp TO A TEMPORARY PATH FOR THIS TO RUN */
// global tmp .....

/* transform the NPI spreadsheets into a single npi dataset */
shell python $npicode/b/read_npi_excel.py

/* reshape the NPI sheet into a state-district-date level dataset */
do $npicode/b/clean_npi.do

/* clean the google mobility data into a standardized district-data dataset */
do $npicode/b/clean_mobility.do

/* standardize the COVID infections/deaths data [may not be necessary] */
do $npicode/b/clean_covid.do

/* run analysis */
do $npicode/b/analyze_infections.do

do $npicode/b/analyze_mobility.do

/* export core datasets to CSV */
foreach dataset in covid_clean google_district_key mobility_clean npi_clean {
  use $npipath/`dataset', clear
  export delimited using clean_data/`dataset'.csv, replace
}
shell cp $npipath/*.xlsx clean_data/   // fix comment coloring */


