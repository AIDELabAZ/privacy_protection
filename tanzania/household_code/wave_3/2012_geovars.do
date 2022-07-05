* Project: WB Weather
* Created on: Oct 2020
* Created by: jdm
* Edited by: jdm
* Stata v.16

* does
	* cleans geovars

* assumes
	* customsave.ado

* TO DO:
	* done

	
* **********************************************************************
* 0 - setup
* **********************************************************************

* define paths	
	loc root 		= "$data/household_data/tanzania/wave_3/raw"  
	loc export 		= "$data/household_data/tanzania/wave_3/refined"
	loc logout 		= "$data/household_data/tanzania/logs"
	
* open log	
	cap log 		close
	log using 		"`logout'/2012_geovars", append

	
* **********************************************************************
* 1 - NPSY3 (Wave 3) - geovars
* **********************************************************************

* import wave 3 geovars
	use 			"`root'/HouseholdGeovars_Y3.dta", clear

* rename variables
	isid 			y3_hhid

	rename 			land03 aez
	
	
* **********************************************************************
* 2 - end matter, clean up to save
* **********************************************************************

	keep 			y3_hhid aez

	compress
	describe
	summarize

* save file
		customsave , idvar(y3_hhid) filename("2012_geovars.dta") ///
			path("`export'") dofile(2012_geovars) user($user)

* close the log
	log	close

/* END */	
