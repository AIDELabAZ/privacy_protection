# Privacy Protection, Measurement Error, and the Integration of Remote Sensing and Socioeconomic Survey Data: Replication Code

This README describes the directory structure and code used in the paper "[Privacy Protection, Measurement Error, and the Integration of Remote Sensing and Socioeconomic Survey Data][1]." Because the weather data contains confidential information, it is not publically available. This means that the weather code will not function, as that data is held by the World Bank. Without the weather data, the results cannot be replicated from raw data through the cleaning to final analysis. Rather, the data and code in the `analysis` folder allows a user to analyze the output of all the regressions specified in the [pre-analysis plan on OSF][3]. This allows the user to reproduce all results tables and figures in the published paper plus explore the results on their own. The household cleaning code can be used to clean the agriculture modules in the [LSMS-ISA data][2]. Contact Drs. Jeffrey D. Michler or Anna Josephson and they can share an intermediate - de-identified - version of the weather data for use in replicating the results. 

This README was last updated on 25 May 2022. 

 ## Index

 - [Project Team](#project-team)
 - [Data cleaning](#data-cleaning)
 - [Pre-requisites](#pre-requisites)
 - [Folder structure](#folder-structure)

## Project Team

Contributors:
* Jeffrey D. Michler [jdmichler@arizona.edu] (Conceptualizaiton, Supervision, Visualization, Writing)
* Anna Josephson [aljosephson@arizona.edu] (Conceptualizaiton, Supervision, Visualization, Writing)
* Talip Kilic (Conceptualization, Resources, Writing)
* Siobhan Murray (Conceptualization, Writing)
* Brian McGreal (Data curation)
* Alison Conley (Data curation)
* Emil Kee-Tui (Data curation)

## Data cleaning

The code in this repository is primarily for replicating the cleaning of the household LSMS-ISA data. This requires downloading this repo and the household data from the World Bank webiste. The `projectdo.do` should then replicate the data cleaning process.

### Pre-requisites

#### Stata req's

  * The data processing and analysis requires a number of user-written
    Stata programs:
    1. `weather_command`
    2. `blindschemes`
    3. `estout`
    4. `customsave`
    5. `winsor2`
    6. `mdesc`
    7. `distinct`

#### Folder structure

The [OSF project page][3] provides more details on the data cleaning.

For the household cleaning code to run, the public use microdata must be downloaded from the [World Bank Microdata Library][2]. Furthermore, the data needs to be placed in the following folder structure:<br>

```stata
weather_and_agriculture
├────household_data      
│    └──country          /* one dir for each country */
│       ├──wave          /* one dir for each wave */
│       └──logs
├──weather_data
│    └──country          /* one dir for each country */
│       ├──wave          /* one dir for each wave */
│       └──logs
├──merged_data
│    └──country          /* one dir for each country */
│       ├──wave          /* one dir for each wave */
│       └──logs
├──regression_data
│    ├──country          /* one dir for each country */
│    └──logs
└────results_data        /* overall analysis */
     ├──tables
     ├──figures
     └──logs
```

  [1]: https://doi.org/10.1016/j.jdeveco.2022.102927
  [2]: https://www.worldbank.org/en/programs/lsms/initiatives/lsms-ISA
  [3]: https://osf.io/8hnz5/
