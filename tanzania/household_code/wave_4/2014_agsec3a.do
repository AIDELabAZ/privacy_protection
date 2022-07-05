* Project: WB Weather
* Created on: May 2020
* Created by: McG
* Stata v.16

* does
	* cleans Tanzania household variables, wave 4 Ag sec3a
	* plot details, inputs, 2014 long rainy season
	* generates irrigation and pesticide dummies, fertilizer variables, and labor variables 
	
* assumes
	* customsave.ado
	* distinct.ado

* TO DO:
	* completed

	
* **********************************************************************
* 0 - setup
* **********************************************************************

* define paths
	loc root = "$data/household_data/tanzania/wave_4/raw"
	loc export = "$data/household_data/tanzania/wave_4/refined"
	loc logout = "$data/household_data/tanzania/logs"

* open log
	cap log close
	log using "`logout'/wv4_AGSEC3A", append

	
* ***********************************************************************
* 1 - prepare TZA 2014 (Wave 4) - Agriculture Section 3A 
* ***********************************************************************

* load data
	use 		"`root'/ag_sec_3a", clear

* dropping duplicates
	duplicates 		drop
	*** 0 obs dropped

* check for uniquie identifiers
	drop			if plotnum == ""
	isid			y4_hhid plotnum
	*** 1,262 obs dropped

* generate unique observation id
	gen				plot_id = y4_hhid + " " + plotnum
	isid			plot_id
	
* must merge in regional identifiers from 2008_HHSECA to impute
	merge			m:1 y4_hhid using "`export'/HH_SECA"
	tab				_merge
	*** 1,262 not matched, from using

	drop if			_merge == 2
	drop			_merge
	
* unique district id
	sort			region district
	egen			uq_dist = group(region district)
	distinct		uq_dist
	*** 159 distinct districts

* record if field was cultivated during long rains
	gen 			status = ag3a_03==1 if ag3a_03!=.
	lab var			status "=1 if field cultivated during long rains"
	*** 3,930 observations were cultivated (92%)

* drop uncultivated plots
	drop			if status == 0	
	*** 345 obs deleted
	
	
* ***********************************************************************
* 2 - generate fertilizer variables
* ***********************************************************************

* constructing fertilizer variables
	rename			ag3a_47 fert_any
	replace			fert_any = 2 if fert_any == .
	*** assuming missing values mean no fertilizer was used
	*** 21 changes made
	
	replace			ag3a_49 = 0 if ag3a_49 == .
	replace			ag3a_56 = 0 if ag3a_56 == .
	gen				kilo_fert = ag3a_49 + ag3a_56

* summarize fertilizer
	sum				kilo_fert, detail
	*** median 0, mean 38.45, max 50,050, s.d. 1131
	*** the top two obs are 50,050 kg and 50,000 kg
	*** the next highest ob is 2,500 - the high values seem unlikely

* replace any +3 s.d. away from median as missing
	replace			kilo_fert = . if kilo_fert > 5000
	sum				kilo_fert, detail
	replace			kilo_fert = . if kilo_fert > `r(p50)'+(3*`r(sd)')
	sum				kilo_fert, detail
	*** replaced 40 values, max is now 250
	*** this seems more like it to me
	
* impute missing values
	mi set 			wide 	// declare the data to be wide.
	mi xtset		, clear 	// clear any xtset that may have had in place previously
	mi register		imputed kilo_fert // identify kilo_fert as the variable being imputed
	sort			y4_hhid plotnum, stable // sort to ensure reproducability of results
	mi impute 		pmm kilo_fert i.uq_dist, add(1) rseed(245780) ///
						noisily dots force knn(5) bootstrap
	mi 				unset

* how did the imputation go?
	tab				mi_miss
	tabstat			kilo_fert kilo_fert_1_, by(mi_miss) ///
						statistics(n mean min max) columns(statistics) ///
						longstub format(%9.3g) 
	replace			kilo_fert = kilo_fert_1_
	drop			kilo_fert_1_
	*** imputed 40 values out of 3,930 total observations	

	
* ***********************************************************************
* 3 - generate irrigation, pesticide, and herbicide dummies
* ***********************************************************************
	
* renaming irrigation
	rename			ag3a_18 irrigated 
	replace			irrigated = 2 if irrigated == .
	
* constructing pesticide/herbicide variables
	gen				pesticide_any = 2
	gen				herbicide_any = 2
	replace			pesticide_any = 1 if ag3a_65a == 1
	replace			herbicide_any = 1 if ag3a_60 == 1
	lab define		pesticide_any 1 "Yes" 2 "No"
	lab values		pesticide_any pesticide_any
	lab values		herbicide_any pesticide_any	


* ***********************************************************************
* 4 - generate labor variables
* ***********************************************************************

* per Palacios-Lopez et al. (2017) in Food Policy, we cap labor per activity
* 7 days * 13 weeks = 91 days for land prep and planting
* 7 days * 26 weeks = 182 days for weeding and other non-harvest activities
* 7 days * 13 weeks = 91 days for harvesting
* we will also exclude child labor_days
* in this survey we can't tell gender or age of household members
* since we can't match household members we deal with each activity seperately

*change missing to zero and then back again
	mvdecode		ag3a_72_1 ag3a_72_2 ag3a_72_3 ag3a_72_4 ///
						ag3a_72_5 ag3a_72_6 ag3a_72_7 ag3a_72_8 ag3a_72_9 ///
						ag3a_72_10 ag3a_72_11 ag3a_72_12 ag3a_72_13 ag3a_72_14 ///
						ag3a_72_15 ag3a_72_16 ag3a_72_17 ag3a_72_18, mv(0)

	mvencode		ag3a_72_1 ag3a_72_2 ag3a_72_3 ag3a_72_4 ///
						ag3a_72_5 ag3a_72_6 ag3a_72_7 ag3a_72_8 ag3a_72_9 ///
						ag3a_72_10 ag3a_72_11 ag3a_72_12 ag3a_72_13 ag3a_72_14 ///
						ag3a_72_15 ag3a_72_16 ag3a_72_17 ag3a_72_18, mv(0)
	*** this allows us to impute only the variables we change to missing				
						
* summarize household individual labor for land prep to look for outliers
	sum				ag3a_72_1 ag3a_72_2 ag3a_72_3 ag3a_72_4 ag3a_72_5 ag3a_72_6
	*** no obs > 90, one = 90

* summarize household individual labor for weeding/ridging to look for outliers
	sum				ag3a_72_7 ag3a_72_8 ag3a_72_9 ag3a_72_10 ag3a_72_11 ag3a_72_12
	*** no obs > 90, one = 90
	
* summarize household individual labor for harvest to look for outliers
	sum				ag3a_72_13 ag3a_72_14 ag3a_72_15 ag3a_72_16 ag3a_72_17 ag3a_72_18
	*** no obs > 90
	
* no imputation necessary as no values are dropped
	
* compiling labor inputs
	egen			hh_labor_days = rsum(ag3a_72_1 ag3a_72_2 ag3a_72_3 ag3a_72_4 ///
						ag3a_72_5 ag3a_72_6 ag3a_72_7 ag3a_72_8 ag3a_72_9 ///
						ag3a_72_10 ag3a_72_11 ag3a_72_12 ag3a_72_13 ag3a_72_14 ///
						ag3a_72_15 ag3a_72_16 ag3a_72_17 ag3a_72_18)

* generate hired labor by gender and activity
	gen				plant_w = ag3a_74_1
	gen				plant_m = ag3a_74_2
	gen				other_w = ag3a_74_5
	gen				other_m = ag3a_74_6
	gen				hrvst_w = ag3a_74_13
	gen				hrvst_m = ag3a_74_14

* summarize hired individual labor to look for outliers
	sum				plant* other* hrvst* if ag3a_73 == 1

* replace outliers with missing
	replace			plant_w = . if plant_w > 90  // 1 change
	replace			plant_m = . if plant_m > 90 // 1 change
	replace			other_w = . if other_w > 181
	replace			other_m = . if other_m > 181 
	replace			hrvst_w = . if hrvst_w > 90 // 2 changes
	replace			hrvst_m = . if hrvst_m > 90 // 1 change
	*** only 5 values replaced

* impute missing values (need to do it for men and women's planting and harvesting)
	mi set 			wide 	// declare the data to be wide.
	mi xtset		, clear 	// clear any xtset that may have had in place previously
	
	* impute women's planting labor
		mi register		imputed plant_w // identify kilo_fert as the variable being imputed
		sort			y4_hhid plotnum, stable // sort to ensure reproducability of results
		mi impute 		pmm plant_w i.uq_dist if ag3a_73 == 1, add(1) rseed(245780) ///
							noisily dots force knn(5) bootstrap
	
	* impute women's harvest labor
		mi register		imputed hrvst_w // identify kilo_fert as the variable being imputed
		sort			y4_hhid plotnum, stable // sort to ensure reproducability of results
		mi impute 		pmm hrvst_w i.uq_dist if ag3a_73 == 1, add(1) rseed(245780) ///
							noisily dots force knn(5) bootstrap

	* impute men's planting labor
		mi register		imputed plant_m // identify kilo_fert as the variable being imputed
		sort			y4_hhid plotnum, stable // sort to ensure reproducability of results
		mi impute 		pmm plant_m i.uq_dist if ag3a_73 == 1, add(1) rseed(245780) ///
							noisily dots force knn(5) bootstrap
	
	* impute men's harvest labor
		mi register		imputed hrvst_m // identify kilo_fert as the variable being imputed
		sort			y4_hhid plotnum, stable // sort to ensure reproducability of results
		mi impute 		pmm hrvst_m i.uq_dist if ag3a_73 == 1, add(1) rseed(245780) ///
							noisily dots force knn(5) bootstrap
							
	mi 				unset
	
* how did the imputation go?
	replace			plant_w = plant_w_1_ // 6 changes
	replace			hrvst_w = hrvst_w_2_ // 6 changes
	replace			plant_m = plant_m_3_ // 3 changes
	replace			hrvst_m = hrvst_m_4_ // 4 changes
	drop			mi_miss1- hrvst_m_4_
	*** why so many changes?
	*** seems like more than 5 imputations are happening maybe?
	*** Wv3 has a total of 2 changes for three imputed values
	*** are these the right imputed variabes for each var? I think so...
	*** what am I missing?

* generate total hired labor days
	egen			hired_labor_days = rsum(plant_w plant_m other_w ///
						other_m hrvst_w hrvst_m)

* generate total labor days (household plus hired)
	gen				labor_days = hh_labor_days + hired_labor_days
	

* **********************************************************************
* 5 - end matter, clean up to save
* **********************************************************************

* keep what we want, get rid of the rest
	keep			y4_hhid plotnum plot_id irrigated fert_any kilo_fert ///
						pesticide_any herbicide_any labor_days plotnum ///
						region district ward ea y4_rural clusterid strataid ///
						hhweight
	order			y4_hhid plotnum plot_id
	
* renaming and relabelling variables
	lab var			y4_hhid "Unique Household Identification NPS Y4"
	lab var			y4_rural "Cluster Type"
	lab var			hhweight "Household Weights (Trimmed & Post-Stratified)"
	lab var			plotnum "Plot ID Within household"
	lab var			plot_id "Unquie Plot Identifier"
	lab var			clusterid "Unique Cluster Identification"
	lab var			strataid "Design Strata"
	lab var			region "Region Code"
	lab var			district "District Code"
	lab var			ward "Ward Code"
	lab var			ea "Village / Enumeration Area Code"
	lab var			labor_days "Total Labor (days), Imputed"
	lab var			irrigated "Is plot irrigated?"
	lab var			pesticide_any "Was Pesticide Used?"
	lab var			herbicide_any "Was Herbicide Used?"	
	lab var			kilo_fert "Fertilizer Use (kg), Imputed"
	
* prepare for export
	isid			y4_hhid plotnum
	compress
	describe
	summarize 
	sort plot_id
	customsave , idvar(plot_id) filename(AG_SEC3A.dta) path("`export'") ///
		dofile(2014_AGSEC3A) user($user)

* close the log
	log	close

/* END */
