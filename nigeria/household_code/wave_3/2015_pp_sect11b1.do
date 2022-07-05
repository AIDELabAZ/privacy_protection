* Project: WB Weather
* Created on: May 2020
* Created by: alj
* Edited by: ek
* Stata v.16

* does
	* reads in Nigeria, WAVE 3 (2015-2016) POST PLANTING, NIGERIA AG SECT11B1
	* determines irrigation and plot use
	* outputs clean data file ready for combination with wave 3 hh data

* assumes
	* customsave.ado
	
* **********************************************************************
* 0 - setup
* **********************************************************************
	
* define paths	
	loc root = "$data/household_data/nigeria/wave_3/raw"
	loc export = "$data/household_data/nigeria/wave_3/refined"
	loc logout = "$data/household_data/nigeria/logs"

* close log (in case still open)
	*log close
	
* open log	
	cap log close
	log using "`logout'/pp_sect11b1", append

* **********************************************************************
* 1 - determine irrigation and plot use
* **********************************************************************
		
* import the first relevant data file
		use "`root'/sect11b1_plantingw3", clear 	

describe
sort hhid plotid
isid hhid plotid

*is this plot irrigated?
rename s11b1q39 irr_any
	lab var			irr_any "=1 if any irrigation was used"

* check to see if values are missing
	mdesc			irr_any
	***99 missing
	
	
* convert missing values to "no"
	replace			irr_any = 2 if irr_any == .
	
* **********************************************************************
* 2 - end matter, clean up to save
* **********************************************************************

	keep 			hhid zone state lga sector hhid ea plotid ///
					irr_any

* create unique household-plot identifier
	isid			hhid plotid
	sort			hhid plotid
	egen			plot_id = group(hhid plotid)
	lab var			plot_id "unique plot identifier"
	
	compress
	describe
	summarize 


* save file
		customsave , idvar(hhid) filename("pp_sect11b1.dta") ///
			path("`export'/`folder'") dofile(pp_sect11b1) user($user)

* close the log
	log	close

/* END */