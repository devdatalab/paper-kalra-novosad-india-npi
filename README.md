# paper-kalra-novosad-india-npi

**Objective**: To assess the impact of non-pharmaceutical interventions (NPIs) on the first wave of COVID transmission and fatalities in India.

**Methods**: We collected data on NPIs, using government notifications and news reports, in six major Indian states from March to August 2020, and we matched these with district-level data on COVID related deaths and Google Mobility reports. We used a district fixed effect regression approach to measure the extent to which district-level lockdowns and mobility restrictions helped reduce deaths in 2020.

Replication code and data for [Kalra & Novodad (2021) "Impacts of regional lockdown policies on COVID-19 transmission in India in 2020"](url).

**Details**

To regenerate the tables and figures from the paper, take the following steps:
  1. Clone this repo
    - `clean_data` contains data on mobility and infections
    - `clean_data/<state_name>.xlsx` contains data on lockdown restrictions for sample states
  2. Open the do file `make_npi.do`. and set the globals `npipath`, `npicode/a`, and `tmp`
    - `$npipath` is the path name for clean data files in the cloned repository
    - `$npicode/a` is the target forlder for all outputs, such as tables and graphs
    - intermeditae files will be placed in `$tmp`
  3. Run the do file `make_npi.do`. This will run through all the other do files to regenerate the results. 
