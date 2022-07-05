* Project: WB Weather
* Created on: April 2020
* Created by: jdm
* Stata v.16

* does
	* Executes all wave specific Ethiopia weather .do files
    * runs weather_command .ado file
	* outputs .dta rainfall data ready to merge with LSMS household data

* assumes
	* weather_command.ado
	* subsidiary, wave-specific .do files
	* customsave.ado

* TO DO:
	* completed

	
* **********************************************************************
* 0 - setup
* **********************************************************************

clear

* set max vars
	set maxvar 120000, perm  // this amount is only allowed for MP editions 

* define paths
	loc root = "$code/ethiopia/weather_code"


* **********************************************************************
* 1 - run .do files
* **********************************************************************


* do each of the file converters
	do "`root'/wave_1/ETH_ESSY1_converter.do"	//	convert wave 1 .csv to .dta
	do "`root'/wave_2/ETH_ESSY2_converter.do"	//	convert wave 2 .csv to .dta
	do "`root'/wave_3/ETH_ESSY3_converter.do"	//	convert wave 3 .csv to .dta


* do each of the weather commands
	do "`root'/wave_1/ETH_ESSY1_weather.do"		//	generate wave 1 .weather variables
	do "`root'/wave_2/ETH_ESSY2_weather.do"		//	generate wave 2 .weather variables
	do "`root'/wave_3/ETH_ESSY3_weather.do"		//	generate wave 3 .weather variables

	
/* END */
