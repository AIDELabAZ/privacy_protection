* Project: WB Weather
* Created on: May 2020
* Created by: alj
* Edited by: ek
* Stata v.16

* does
	* reads in Nigeria, WAVE 2 (2012-2013),POST PLANTING, AG SECT11A1
	* determines primary and secondary crops, cleans plot size (hecatres)
	* outputs clean data file ready for combination with wave 2 plot data

* assumes
	* customsave.ado
	* land_conversion.dta conversion file

* TO DO:
	* complete

	
* **********************************************************************
* 0 - setup
* **********************************************************************

* define paths
	loc		root	=		"$data/household_data/nigeria/wave_2/raw"
	loc		cnvrt	=		"$data/household_data/nigeria/conversion_files"
	loc		export	=		"$data/household_data/nigeria/wave_2/refined"
	loc		logout	= 		"$data/household_data/nigeria/logs"

* open log
	cap log close
	log 	using	"`logout'/wave_2_pp_sect11a1", append

* **********************************************************************
* 1 - describing plot size - self-reported and GPS
* **********************************************************************

* import the first relevant data file
	use				"`root'/sect11a1_plantingw2", clear

* need plot id to uniquely identify
	describe
	sort 			hhid plotid
	isid 			hhid plotid

* determine self reported plotsize
	gen 			plot_size_SR = s11aq4a
	rename 			s11aq4b plot_unit
	lab	var			plot_size_SR "self reported size of plot, not standardized"
	lab var			plot_unit "self reported unit of measure"

* determine GPS plotsize
	gen 			plot_size_GPS = s11aq4c
	lab var			plot_size_GPS 	"GPS plot size in sq. meters"

	
* **********************************************************************
* 2 - conversion to hectares
* **********************************************************************

* merge in conversion file
	merge 			m:1 	zone using 	"`cnvrt'/land-conversion.dta"
		*** All observations matched.

	keep 			if 		_merge == 3
	drop 			_merge

	tab 			plot_unit

* convert to hectares
	gen 			plot_size_hec = .
	replace 		plot_size_hec = plot_size_SR*ridgecon	if plot_unit == 2
	*heaps
	replace 		plot_size_hec = plot_size_SR*heapcon	if plot_unit == 1
	*stands
	replace 		plot_size_hec = plot_size_SR*standcon	if plot_unit == 3
	*plots
	replace 		plot_size_hec = plot_size_SR*plotcon	if plot_unit == 4
	*acre
	replace 		plot_size_hec = plot_size_SR*acrecon	if plot_unit == 5
	*sqm
	replace 		plot_size_hec = plot_size_SR*sqmcon		if plot_unit == 7
	*hec
	replace 		plot_size_hec = plot_size_SR			if plot_unit == 6

	count			if plot_size_SR == . 
	*** 29 observations have . for plot_size_SR
	*** only losing 2 observations by not including "other" units
	rename 			plot_size_hec plot_size_hec_SR
	lab var			plot_size_hec_SR 	"SR plot size converted to hectares"
	
	count 			if plot_size_hec_SR !=.
	count			if plot_size_hec_SR == . 
	*** 60 observations do not have plot_size_hec_SR
	*** only 2 observations not converted - not including "other" units
	*** these 58 other observations have no unit given and so cannot be converted 
	*** will impute missing
	*** 5,833 observations have plot_size_hec_SR

* convert gps report to hectares
	count 			if plot_size_GPS == .  
	*** 738 observations have no GPS value 
	gen 			plot_size_2 = .
	replace 		plot_size_2 = plot_size_GPS*sqmcon
	rename 			plot_size_2 plot_size_hec_GPS
	lab	var			plot_size_hec_GPS "GPS measured area of plot in hectares"
	*** 738 observations do not have plot_size_hec_GPS
	*** these 738 observations have no value of GPS given so cannot be converted 
	*** will impute missing
	*** 5,155 observations have plot_size_hec_GPS

	count 			if plot_size_hec_GPS !=.
	count			if plot_size_hec_GPS == . 

	count	 		if plot_size_hec_SR != . & plot_size_hec_GPS != .
	*** 5125 observations have both self reported and GPS plot size in hectares
	*** 768 observations lack either the plot_size_hec_GPS or the plot_size_hec_SR

	pwcorr 			plot_size_hec_SR plot_size_hec_GPS
	*** relatively low correlation = 0.1278 between selfreported plot size and GPS

* check correlation within +/- 3sd of mean (GPS)
	sum 			plot_size_hec_GPS, detail
	pwcorr 			plot_size_hec_SR plot_size_hec_GPS if ///
						inrange(plot_size_hec_GPS,`r(p50)'-(3*`r(sd)'),`r(p50)'+(3*`r(sd)'))
	*** correlation of points with +/- 3sd is lower 0.0708

* check correlation within +/- 3sd of mean (GPS and SR)
	sum 			plot_size_hec_GPS, detail
	sum 			plot_size_hec_SR, detail
	pwcorr 			plot_size_hec_SR plot_size_hec_GPS if ///
						inrange(plot_size_hec_GPS,`r(p50)'-(3*`r(sd)'),`r(p50)'+(3*`r(sd)')) & ///
						inrange(plot_size_hec_SR,`r(p50)'-(3*`r(sd)'),`r(p50)'+(3*`r(sd)'))
	*** correlation between self reported and GPS for values within +/- 3 sd's of GPS and SR is still lower 0.0697

* examine larger plot sizes
	tab				plot_size_hec_GPS 	if 	plot_size_hec_GPS > 2
	*** 198 GPS which are greater than 2
	tab				plot_size_hec_GPS 	if 	plot_size_hec_GPS > 20
	*** but none which are greater than 20 
	*** no wholly unreasonably GPS values 

* correlation at higher plot sizes
	list 			plot_size_hec_GPS plot_size_hec_SR 	if ///
						plot_size_hec_GPS > 3 & !missing(plot_size_hec_GPS), sep(0)
	pwcorr 			plot_size_hec_GPS plot_size_hec_SR 	if 	///
						plot_size_hec_GPS > 3 & !missing(plot_size_hec_GPS)
	*** correlation at higher plot sizes is higher - but still lower than overall: 0.1157

* examine smaller plot sizes
	tab				plot_size_hec_GPS 	if 	plot_size_hec_GPS < 0.1
	*** 1,344  below 0.1
	tab				plot_size_hec_GPS 	if 	plot_size_hec_GPS < 0.05
	*** 714 below 0.5
	tab				plot_size_hec_GPS 	if 	plot_size_hec_GPS < 0.005
	*** only 13 below 0.005
	*** none are unrealistically small

*correlation at lower plot sizes
	list 			plot_size_hec_GPS plot_size_hec_SR 	if 	///
						plot_size_hec_GPS < 0.01, sep(0)
	pwcorr 			plot_size_hec_GPS plot_size_hec_SR 	if ///
						plot_size_hec_GPS < 0.01
	*** very small relationship between GPS and SR plotsize, correlation = 0.0208
	
	list 			plot_size_hec_GPS plot_size_hec_SR 	if 	///
						plot_size_hec_GPS < 0.01, sep(0)
	pwcorr 			plot_size_hec_GPS plot_size_hec_SR 	if ///
						plot_size_hec_GPS < 0.01
	*** still small relationship between GPS and SR plotsize, correlation = 0.0208
	
* compare GPS and SR
* examine GPS 
	sum 			plot_size_hec_GPS
	sum 			plot_size_hec_SR
	*** GPS tending to be smaller than self-reported - and more realistic
	*** as in Y1, will not include SR in imputation - only will include GPS 
	
	*hist	 		plot_size_hec_GPS 	if 	plot_size_hec_GPS < 0.3
	*hist 			plot_size_hec_GPS 	if 	plot_size_hec_GPS < 0.2
	***appears that GPS becomes less accurate around 0.05

*make GPS values missing if below 0.05 for impute
*	replace plot_size_hec_GPS = . if plot_size_hec_GPS <0.05
	*** 714 changed to missing
	
* impute missing plot sizes using predictive mean matching
	mi set 			wide // declare the data to be wide.
	mi xtset		, clear // this is a precautinary step to clear any existing xtset
	mi register 	imputed plot_size_hec_GPS // identify plotsize_GPS as the variable being imputed
	sort			hhid plotid, stable // sort to ensure reproducability of results
	mi impute 		pmm plot_size_hec_GPS i.state, add(1) rseed(245780) noisily dots ///
						force knn(5) bootstrap
	mi unset

* look at the data
	tab				mi_miss
	tabstat 		plot_size_hec_GPS plot_size_hec_SR plot_size_hec_GPS_1_, ///
						by(mi_miss) statistics(n mean min max) columns(statistics) ///
						longstub format(%9.3g)
	*** imputed values change VERY little - mean from 0.51 to 0.508 -- all very reasonable changes
	*** good impute

* drop if anything else is still missing
	list			plot_size_hec_GPS plot_size_hec_SR 	if 	///
						missing(plot_size_hec_GPS_1_), sep(0)
	drop 			if missing(plot_size_hec_GPS_1_)
	*** 0 observations deleted

	
* **********************************************************************
* 3 - end matter, clean up to save
* **********************************************************************

	rename			plot_size_hec_GPS_1_ plotsize
	lab	var			plotsize	"plot size (ha)"

	keep 			hhid zone state lga hhid ea plotid plotsize

* create unique household-plot identifier
	isid				hhid plotid
	sort				hhid plotid
	egen				plot_id = group(hhid plotid)
	lab var				plot_id "unique plot identifier"

	compress
	describe
	summarize

* save file
		customsave , idvar(plot_id) filename("pp_sect11a1.dta") ///
			path("`export'") dofile(pp_sect11a1) user($user)

* close the log
	log	close

/* END */
