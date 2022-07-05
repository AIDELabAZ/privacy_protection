* Project: WB Weather
* Created on: May 2020
* Created by: jdm
* Edited by : alj
* Stata v.16

* does
	* merges individual cleaned plot datasets together
	* adjusts binary variables
	* imputes values for continuous variables
	* collapses to wave 2 plot level data to household level for combination with other waves

* assumes
	* previously cleaned household datasets
	* customsave.ado
	* double counting assumed in labor - only use harvest labor 

* TO DO:
	* done 

* **********************************************************************
* 0 - setup
* **********************************************************************

* define paths
	loc		root	=	"$data/household_data/nigeria/wave_2/refined"
	loc 	export	=	"$data/household_data/nigeria/wave_2/refined"
	loc 	logout	=	"$data/household_data/nigeria/logs"

* open log
	cap 	log 	close
	log 	using 	"`logout'/ghsy2_merge", append

	
* **********************************************************************
* 1 - merge plot level data sets together
* **********************************************************************

* start by loading harvest quantity and value, since this is our limiting factor
	use 			"`root'/ph_secta3.dta", clear

	isid			cropplot_id

* merge in plot size data
	merge 			m:1 hhid plotid using "`root'/pp_sect11a1", generate(_11a1)
	*** 113 are missing in master, 9716 matched
	*** most unmerged (849) are from using, meaning we lack production data
	*** per Malawi (rs_plot) we drop all unmerged observations

	drop			if _11a1 != 3
	
* merging in irrigation data
	merge			m:1 hhid plotid using "`root'/pp_sect11b1", generate(_11b1)
	*** only 14 are missing in master, 9717 matched 
	*** we assume these are plots without irrigation
	
	replace			irr_any = 2 if irr_any == . & _11b1 == 1
	*** 14 changes made

	drop			if _11b1 == 2
	
* merging in planting labor data
	merge		m:1 hhid plotid using "`root'/pp_sect11c1", generate(_11c1)
	*** 203 are missing in master, 9528 matched
	*** we will impute the missing values later
	drop			if _11c1 == 2
	*** not going to actually use planting labor in analysis - will omit

* merging in pesticide and herbicide use
	merge		m:1 hhid plotid using "`root'/pp_sect11c2", generate(_11c2)
	*** 41 missing in master, 9690 
	*** we assume these are plots without pest or herb

	replace			pest_any = 2 if pest_any == . & _11c2 == 1
	replace			herb_any = 2 if herb_any == . & _11c2 == 1
	*** 41 changes made for each 
	
	drop			if _11c2 == 2

* merging in fertilizer use
	merge		m:1 hhid plotid using "`root'/pp_sect11d", generate(_11d)
	*** 503 missing from master, 9227 matched 
	*** we will impute the missing values later
	
	drop			if _11d == 2

* merging in harvest labor data
	merge		m:1 hhid plotid using "`root'/ph_secta2", generate(_a2)
	*** 32 missing from master, 9699 matched
	*** we will impute the missing values later
	*** only going to include harvest labor in analysis - will include this and rename generally
	*** can revisit this later

	drop			if _a2 == 2

* drop observations missing values (not in continuous)
	drop			if plotsize == .
	drop			if irr_any == .
	drop			if pest_any == .
	drop			if herb_any == .
	*** no observations dropped

	drop			_11a1 _11b1 _11c1 _11c2 _11d _a2

	
* **********************************************************************
* 1b - create total farm and maize variables
* **********************************************************************

* rename some variables
	rename			hrv_labor labordays
	rename			fert_use fert

* recode binary variables
	replace			fert_any = 0 if fert_any == 2
	replace			pest_any = 0 if pest_any == 2
	replace			herb_any = 0 if herb_any == 2
	replace			irr_any  = 0 if irr_any  == 2
	
* generate mz_variables
	gen				mz_lnd = plotsize	if mz_hrv != .
	gen				mz_lab = labordays	if mz_hrv != .
	gen				mz_frt = fert		if mz_hrv != .
	gen				mz_pst = pest_any	if mz_hrv != .
	gen				mz_hrb = herb_any	if mz_hrv != .
	gen				mz_irr = irr_any	if mz_hrv != .

* collapse to plot level
	collapse (sum)	vl_hrv plotsize labordays fert ///
						mz_hrv mz_lnd mz_lab mz_frt ///
			 (max)	pest_any herb_any irr_any  ///
						mz_pst mz_hrb mz_irr mz_damaged, ///
						by(hhid plotid plot_id zone state lga sector ea)

* replace non-maize harvest values as missing
	tab				mz_damaged, missing
	loc	mz			mz_lnd mz_lab mz_frt mz_pst mz_hrb mz_irr
	foreach v of varlist `mz'{
	    replace		`v' = . if mz_damaged == . & mz_hrv == 0	
	}	
	replace			mz_hrv = . if mz_damaged == . & mz_hrv == 0		
	drop 			mz_damaged
	*** 3,631 changes made

	
* **********************************************************************
* 2 - impute: total farm value, labor, fertilizer use 
* **********************************************************************

* ******************************************************************************
* FOLLOWING WB: we will construct production variables on a per hectare basis,
* and conduct imputation on the per hectare variables. We will then create 
* 'imputed' versions of the non-per hectare variables (e.g. harvest, 
* value) by multiplying the imputed per hectare vars by plotsize. 
* This approach relies on the assumptions that the 1) GPS measurements are 
* reliable, and 2) outlier values are due to errors in the respondent's 
* self-reported production quantities (see rs_plot.do)
* ******************************************************************************


* **********************************************************************
* 2a - impute: total value
* **********************************************************************
	
* construct production value per hectare
	gen				vl_yld = vl_hrv / plotsize
	assert 			!missing(vl_yld)
	lab var			vl_yld "value of yield (2010USD/ha)"

* impute value per hectare outliers 
	sum				vl_yld
	bysort state :	egen stddev = sd(vl_yld) if !inlist(vl_yld,.,0)
	recode stddev	(.=0)
	bysort state :	egen median = median(vl_yld) if !inlist(vl_yld,.,0)
	bysort state :	egen replacement = median(vl_yld) if  ///
						(vl_yld <= median + (3 * stddev)) & ///
						(vl_yld >= median - (3 * stddev)) & !inlist(vl_yld,.,0)
	bysort state :	egen maxrep = max(replacement)
	bysort state :	egen minrep = min(replacement)
	assert 			minrep==maxrep
	generate 		vl_yldimp = vl_yld
	replace  		vl_yldimp = maxrep if !((vl_yld < median + (3 * stddev)) ///
						& (vl_yld > median - (3 * stddev))) ///
						& !inlist(vl_yld,.,0) & !mi(maxrep)
	tabstat			vl_yld vl_yldimp, ///
						f(%9.0f) s(n me min p1 p50 p95 p99 max) c(s) longstub
	*** reduces mean from 1182 to 890
	*** reduces max from 80806 to 28744
	
	drop			stddev median replacement maxrep minrep
	lab var			vl_yldimp	"value of yield (2010USD/ha), imputed"

* inferring imputed harvest value from imputed harvest value per hectare
	generate		vl_hrvimp = vl_yldimp * plotsize 
	lab var			vl_hrvimp "value of harvest (2010USD), imputed"
	lab var			vl_hrv "value of harvest (2010USD)"
	

* **********************************************************************
* 2b - impute: labor
* **********************************************************************

* construct labor days per hectare
	gen				labordays_ha = labordays / plotsize, after(labordays)
	lab var			labordays_ha "farm labor use (days/ha)"
	sum				labordays labordays_ha

* impute labor outliers, right side only 
	sum				labordays_ha, detail
	bysort state :	egen stddev = sd(labordays_ha) if !inlist(labordays_ha,.,0)
	recode 			stddev (.=0)
	bysort state :	egen median = median(labordays_ha) if !inlist(labordays_ha,.,0)
	bysort state :	egen replacement = median(labordays_ha) if ///
						(labordays_ha <= median + (3 * stddev)) & ///
						(labordays_ha >= median - (3 * stddev)) & !inlist(labordays_ha,.,0)
	bysort state :	egen maxrep = max(replacement)
	bysort state :	egen minrep = min(replacement)
	assert			minrep==maxrep
	gen				labordays_haimp = labordays_ha, after(labordays_ha)
	replace 		labordays_haimp = maxrep if !((labordays_ha < median + (3 * stddev)) ///
						& (labordays_ha > median - (3 * stddev))) ///
						& !inlist(labordays_ha,.,0) & !mi(maxrep)
	tabstat 		labordays_ha labordays_haimp, ///
						f(%9.0f) s(n me min p1 p50 p95 p99 max) c(s) longstub
	*** reduces mean from 329 to 258
	*** reduces max from 36937 to 9913

	drop			stddev median replacement maxrep minrep
	lab var			labordays_haimp	"farm labor use (days/ha), imputed"

* make labor days based on imputed labor days per hectare
	gen				labordaysimp = labordays_haimp * plotsize, after(labordays)
	lab var			labordaysimp "farm labor (days), imputed"


* **********************************************************************
* 2c - impute: fertilizer
* **********************************************************************

* construct fertilizer use per hectare
	gen				fert_ha = fert / plotsize, after(fert)
	lab var			fert_ha "fertilizer use (kg/ha)"
	sum				fert fert_ha

* impute labor outliers, right side only 
	sum				fert_ha, detail
	bysort state :	egen stddev = sd(fert_ha) if !inlist(fert_ha,.,0)
	recode 			stddev (.=0)
	bysort state :	egen median = median(fert_ha) if !inlist(fert_ha,.,0)
	bysort state :	egen replacement = median(fert_ha) if ///
						(fert_ha <= median + (3 * stddev)) & ///
						(fert_ha >= median - (3 * stddev)) & !inlist(fert_ha,.,0)
	bysort state :	egen maxrep = max(replacement)
	bysort state :	egen minrep = min(replacement)
	assert			minrep==maxrep
	gen				fert_haimp = fert_ha, after(fert_ha)
	replace 		fert_haimp = maxrep if !((fert_ha < median + (3 * stddev)) ///
						& (fert_ha > median - (3 * stddev))) ///
						& !inlist(fert_ha,.,0) & !mi(maxrep)
	tabstat 		fert_ha fert_haimp, ///
						f(%9.0f) s(n me min p1 p50 p95 p99 max) c(s) longstub
	*** reduces mean from 186 to 144
	*** reduces max from 24038 to 6735
	
	drop			stddev median replacement maxrep minrep
	lab var			fert_haimp	"fertilizer use (kg/ha), imputed"

* make labor days based on imputed labor days per hectare
	gen				fertimp = fert_haimp * plotsize, after(fert)
	lab var			fertimp "fertilizer (kg), imputed"
	lab var			fert "fertilizer (kg)"


* **********************************************************************
* 3 - impute: maize yield, labor, fertilizer use 
* **********************************************************************


* **********************************************************************
* 3a - impute: maize yield
* **********************************************************************

* construct maize yield
	gen				mz_yld = mz_hrv / mz_lnd, after(mz_hrv)
	lab var			mz_yld	"maize yield (kg/ha)"

*maybe imputing zero values	
	
* impute yield outliers
	sum				mz_yld
	bysort state : egen stddev = sd(mz_yld) if !inlist(mz_yld,.,0)
	recode 			stddev (.=0)
	bysort state : egen median = median(mz_yld) if !inlist(mz_yld,.,0)
	bysort state : egen replacement = median(mz_yld) if /// 
						(mz_yld <= median + (3 * stddev)) & ///
						(mz_yld >= median - (3 * stddev)) & !inlist(mz_yld,.,0)
	bysort state : egen maxrep = max(replacement)
	bysort state : egen minrep = min(replacement)
	assert 			minrep==maxrep
	generate 		mz_yldimp = mz_yld, after(mz_yld)
	replace  		mz_yldimp = maxrep if !((mz_yld < median + (3 * stddev)) ///
					& (mz_yld > median - (3 * stddev))) ///
					& !inlist(mz_yld,.,0) & !mi(maxrep)
	tabstat 		mz_yld mz_yldimp, ///
					f(%9.0f) s(n me min p1 p50 p95 p99 max) c(s) longstub
	*** reduces mean from 3574 to 2304
	*** reduces max from 855365 to 83842
					
	drop 			stddev median replacement maxrep minrep
	lab var 		mz_yldimp "maize yield (kg/ha), imputed"

* inferring imputed harvest quantity from imputed yield value 
	generate 		mz_hrvimp = mz_yldimp * mz_lnd, after(mz_hrv)
	lab var 		mz_hrvimp "maize harvest quantity (kg), imputed"
	lab var 		mz_hrv "maize harvest quantity (kg)"


* **********************************************************************
* 3b - impute: maize labor
* **********************************************************************

* construct labor days per hectare
	gen				mz_lab_ha = mz_lab / mz_lnd, after(labordays)
	lab var			mz_lab_ha "maize labor use (days/ha)"
	sum				mz_lab mz_lab_ha

* impute labor outliers, right side only 
	sum				mz_lab_ha, detail
	bysort state :	egen stddev = sd(mz_lab_ha) if !inlist(mz_lab_ha,.,0)
	recode 			stddev (.=0)
	bysort state :	egen median = median(mz_lab_ha) if !inlist(mz_lab_ha,.,0)
	bysort state :	egen replacement = median(mz_lab_ha) if ///
						(mz_lab_ha <= median + (3 * stddev)) & ///
						(mz_lab_ha >= median - (3 * stddev)) & !inlist(mz_lab_ha,.,0)
	bysort state :	egen maxrep = max(replacement)
	bysort state :	egen minrep = min(replacement)
	assert			minrep==maxrep
	gen				mz_lab_haimp = mz_lab_ha, after(mz_lab_ha)
	replace 		mz_lab_haimp = maxrep if !((mz_lab_ha < median + (3 * stddev)) ///
						& (mz_lab_ha > median - (3 * stddev))) ///
						& !inlist(mz_lab_ha,.,0) & !mi(maxrep)
	tabstat 		mz_lab_ha mz_lab_haimp, ///
						f(%9.0f) s(n me min p1 p50 p95 p99 max) c(s) longstub
	*** reduces mean from 309 to 236
	*** reduces max from 8596 to 6924

	drop			stddev median replacement maxrep minrep
	lab var			mz_lab_haimp	"maize labor use (days/ha), imputed"

* make labor days based on imputed labor days per hectare
	gen				mz_labimp = mz_lab_haimp * mz_lnd, after(mz_lab)
	lab var			mz_labimp "maize labor (days), imputed"


* **********************************************************************
* 3c - impute: maize fertilizer
* **********************************************************************

* construct fertilizer use per hectare
	gen				mz_frt_ha = mz_frt / mz_lnd, after(mz_frt)
	lab var			mz_frt_ha "fertilizer use (kg/ha)"
	sum				mz_frt mz_frt_ha

* impute labor outliers, right side only 
	sum				mz_frt_ha, detail
	bysort state :	egen stddev = sd(mz_frt_ha) if !inlist(mz_frt_ha,.,0)
	recode 			stddev (.=0)
	bysort state :	egen median = median(mz_frt_ha) if !inlist(mz_frt_ha,.,0)
	bysort state :	egen replacement = median(mz_frt_ha) if ///
						(mz_frt_ha <= median + (3 * stddev)) & ///
						(mz_frt_ha >= median - (3 * stddev)) & !inlist(mz_frt_ha,.,0)
	bysort state :	egen maxrep = max(replacement)
	bysort state :	egen minrep = min(replacement)
	assert			minrep==maxrep
	gen				mz_frt_haimp = mz_frt_ha, after(mz_frt_ha)
	replace 		mz_frt_haimp = maxrep if !((mz_frt_ha < median + (3 * stddev)) ///
						& (mz_frt_ha > median - (3 * stddev))) ///
						& !inlist(mz_frt_ha,.,0) & !mi(maxrep)
	tabstat 		mz_frt_ha mz_frt_haimp, ///
						f(%9.0f) s(n me min p1 p50 p95 p99 max) c(s) longstub
	*** reduces mean from 268 to 211
	*** reduces max from 15686 to 5519

	drop			stddev median replacement maxrep minrep
	lab var			mz_frt_haimp	"fertilizer use (kg/ha), imputed"

* make labor days based on imputed labor days per hectare
	gen				mz_frtimp = mz_frt_haimp * mz_lnd, after(mz_frt)
	lab var			mz_frtimp "fertilizer (kg), imputed"
	lab var			mz_frt "fertilizer (kg)"

	
* **********************************************************************
* 4 - collapse to household level
* **********************************************************************


* **********************************************************************
* 4a - generate total farm variables
* **********************************************************************

* generate plot area
	bysort			hhid (plot_id) : egen tf_lnd = sum(plotsize)
	assert			tf_lnd > 0 
	sum				tf_lnd, detail

* value of harvest
	bysort			hhid (plot_id) : egen tf_hrv = sum(vl_hrvimp)
	sum				tf_hrv, detail
	
* value of yield
	generate		tf_yld = tf_hrv / tf_lnd
	sum				tf_yld, detail
	
* labor
	bysort 			hhid (plot_id) : egen lab_tot = sum(labordaysimp)
	generate		tf_lab = lab_tot / tf_lnd
	sum				tf_lab, detail

* fertilizer
	bysort 			hhid (plot_id) : egen fert_tot = sum(fertimp)
	generate		tf_frt = fert_tot / tf_lnd
	sum				tf_frt, detail

* pesticide
	bysort 			hhid (plot_id) : egen tf_pst = max(pest_any)
	tab				tf_pst
	
* herbicide
	bysort 			hhid (plot_id) : egen tf_hrb = max(herb_any)
	tab				tf_hrb
	
* irrigation
	bysort 			hhid (plot_id) : egen tf_irr = max(irr_any)
	tab				tf_irr
	
	
* **********************************************************************
* 4b - generate maize variables 
* **********************************************************************	
	
* generate plot area
	bysort			hhid (plot_id) :	egen cp_lnd = sum(mz_lnd) ///
						if mz_hrvimp != .
	assert			cp_lnd > 0 
	sum				cp_lnd, detail

* value of harvest
	bysort			hhid (plot_id) :	egen cp_hrv = sum(mz_hrvimp) ///
						if mz_hrvimp != .
	sum				cp_hrv, detail
	
* value of yield
	generate		cp_yld = cp_hrv / cp_lnd if mz_hrvimp != .
	sum				cp_yld, detail
	
* labor
	bysort 			hhid (plot_id) : egen lab_mz = sum(mz_labimp) ///
						if mz_hrvimp != .
	generate		cp_lab = lab_mz / cp_lnd
	sum				cp_lab, detail

* fertilizer
	bysort 			hhid (plot_id) : egen fert_mz = sum(mz_frtimp) ///
						if mz_hrvimp != .
	generate		cp_frt = fert_mz / cp_lnd
	sum				cp_frt, detail

* pesticide
	bysort 			hhid (plot_id) : egen cp_pst = max(mz_pst) /// 
						if mz_hrvimp != .
	tab				cp_pst
	
* herbicide
	bysort 			hhid (plot_id) : egen cp_hrb = max(mz_hrb) ///
						if mz_hrvimp != .
	tab				cp_hrb
	
* irrigation
	bysort 			hhid (plot_id) : egen cp_irr = max(mz_irr) ///
						if mz_hrvimp != .
	tab				cp_irr

* verify values are accurate
	sum				tf_* cp_*
	
* collapse to the household level
	loc	cp			cp_*
	foreach v of varlist `cp'{
	    replace		`v' = 0 if `v' == .
	}		
	
* count before collapse
	count
	***5044 obs
	
	collapse (max)	tf_* cp_*, by(zone state lga sector ea hhid)

* count after collapse 
	count 
	*** 5044 to 2768 observations 
	
* return non-maize production to missing
	replace			cp_yld = . if cp_yld == 0
	replace			cp_irr = 1 if cp_irr > 0	
	replace			cp_irr = . if cp_yld == . 
	replace			cp_hrb = 1 if cp_hrb > 0
	replace			cp_hrb = . if cp_yld == .
	replace			cp_pst = 1 if cp_pst > 0
	replace			cp_pst = . if cp_yld == .
	replace			cp_frt = . if cp_yld == .
	replace			cp_lnd = . if cp_yld == .
	replace			cp_hrv = . if cp_yld == .
	replace			cp_lab = . if cp_yld == .

* verify values are accurate
	sum				tf_* cp_*

* label variables
	lab var			tf_lnd	"Total farmed area (ha)"
	lab var			tf_hrv	"Total value of harvest (2010 USD)"
	lab var			tf_yld	"value of yield (2010 USD/ha)"
	lab var			tf_lab	"labor rate (days/ha)"
	lab var			tf_frt	"fertilizer rate (kg/ha)"
	lab var			tf_pst	"Any plot has pesticide"
	lab var			tf_hrb	"Any plot has herbicide"
	lab var			tf_irr	"Any plot has irrigation"
	lab var			cp_lnd	"Total maize area (ha)"
	lab var			cp_hrv	"Total quantity of maize harvest (kg)"
	lab var			cp_yld	"Maize yield (kg/ha)"
	lab var			cp_lab	"labor rate for maize (days/ha)"
	lab var			cp_frt	"fertilizer rate for maize (kg/ha)"
	lab var			cp_pst	"Any maize plot has pesticide"
	lab var			cp_hrb	"Any maize plot has herbicide"
	lab var			cp_irr	"Any maize plot has irrigation"
	
	
* impute missing labor
	*** max is determined by comparing the right end tail distribution to wave 1 maxes using a kdensity peak.
	sum 			tf_lab , detail			
	
	*kdensity 		tf_lab if tf_lab > 1400
	*** peak is around 1900
	*kdensity tf_lab if tf_lnd < 0.1
	
	replace 		tf_lab = . if tf_lab > 1400 
	*** 71 changes
	*& tf_lnd < 0.1

	sum 			tf_lab
	
	mi set 			wide 	// declare the data to be wide.
	mi xtset		, clear 	// clear any xtset that may have had in place previously
	mi register		imputed tf_lab // identify tf_lab as the variable being imputed
	sort			hhid state zone, stable // sort to ensure reproducability of results
	mi impute 		pmm tf_lab i.state tf_lnd, add(1) rseed(245780) ///
						noisily dots force knn(5) bootstrap
	mi 	unset	
	
	*** review imputation
	sum				tf_lab_1_
	replace 		tf_lab = tf_lab_1_
	sum 			tf_lab, detail
	*** mean 182.44, max 1351.86
	drop			mi_miss tf_lab_1_
	mdesc			tf_lab
	*** none missing
	
* impute tf_hrv outliers
	*kdensity 		tf_yld if tf_yld > 9000
	*** max is 11000
	sum 			tf_yld, detail
	*** mean 835, max 17300
	
	replace 		tf_hrv =. if tf_yld > 9000
	
	mi set 			wide 	// declare the data to be wide.
	mi xtset		, clear 	// clear any xtset that may have had in place previously
	mi register		imputed tf_hrv // identify tf_hrv as the variable being imputed
	sort			hhid state zone, stable // sort to ensure reproducability of results
	mi impute 		pmm tf_hrv i.state tf_lnd tf_lab, add(1) rseed(245780) ///
						noisily dots force knn(5) bootstrap
	mi unset
	
	sort 			tf_hrv
	replace    		tf_hrv = tf_hrv_1_	if 	tf_hrv == .
	replace 		tf_yld = tf_hrv / tf_lnd
	sum 			tf_yld, detail
	*** mean 707.25, max 13591.4
	mdesc 			tf_yld
	*** 0 missing
	drop 			mi_miss tf_hrv_1_ 
						
* impute cp_lab
	sum 			cp_lab, detail
	*scatter		cp_lnd cp_lab
	*kdensity 		cp_lab if cp_lab > 1800
	*kdensity 		cp_lab if cp_lab > 1800 & cp_lab < 4000
	*** max is 2100. the 1800 is the max of cp_lab in wave 2

	replace 		cp_lab = . if cp_lab > 1800
	*** 17 changes
	
	mi set 			wide 	// declare the data to be wide.
	mi xtset		, clear 	// clear any xtset that may have had in place previously
	mi register		imputed cp_lab // identify cp_lab as the variable being imputed
	sort			hhid state zone, stable // sort to ensure reproducability of results
	mi impute 		pmm cp_lab i.state cp_lnd, add(1) rseed(245780) ///
						noisily dots force knn(5) bootstrap
	mi 	unset	
	
	*** review imputation
	sum				cp_lab_1_
	replace 		cp_lab = cp_lab_1_
	sum 			cp_lab, detail
	*** mean 195.75, max 1682.47
	drop			mi_miss cp_lab_1_
	mdesc			cp_lab if cp_lnd !=.
	*** none missing
	
* cp yield outliers
	sum 			cp_yld, detail
	*** mean 2375.3, std dev 5878.58, max is 83841.6
	sum 			cp_hrv, detail
	*** mean 803.43, std dev 1000.29, max 9600
	*kdensity cp_yld if cp_yld > 20000
	
	sum cp_hrv if cp_lnd < 0.1 & cp_yld > 10000, detail
	
	* change outliers to missing
	replace 		cp_hrv = . if cp_yld > 15000 & cp_lnd < 0.5
	*** 15 changes made
	replace 		cp_hrv = . if cp_yld > 15000
	*** 4 changes

* impute missing values (impute in stages to get imputation near similar land values)
	sum 			cp_hrv
	
	mi set 			wide 	// declare the data to be wide.
	mi xtset		, clear 	// clear any xtset that may have had in place previously
	mi register		imputed cp_hrv // identify cp_hrv as the variable being imputed
	sort			hhid state zone, stable // sort to ensure reproducability of results
	mi impute 		pmm cp_hrv i.state cp_lnd cp_lab if cp_lnd < 0.03, add(1) rseed(245780) ///
						noisily dots force knn(5) bootstrap
						
	sort			hhid state zone, stable // sort to ensure reproducability of results
	mi impute 		pmm cp_hrv i.state cp_lnd cp_lab if cp_lnd < 0.1, add(1) rseed(245780) ///
						noisily dots force knn(5) bootstrap
					
	sort			hhid state zone, stable // sort to ensure reproducability of results
	mi impute 		pmm cp_hrv i.state cp_lnd cp_lab if cp_lnd < 0.6, add(1) rseed(245780) ///
						noisily dots force knn(5) bootstrap					
						
	mi 				unset	

	sort 			cp_hrv
	replace 		cp_hrv = cp_hrv_3_ if cp_hrv == . & cp_hrv_2_ == . & cp_hrv_1_
	replace 		cp_hrv = cp_hrv_2_ if cp_hrv == . & cp_hrv_1_ == .
	replace 		cp_hrv = cp_hrv_1_ if cp_hrv == . 
	replace 		cp_yld = cp_hrv / cp_lnd
	sum 			cp_yld, detail
	*** mean 1834.03, std. dev 2047.3, max 14682.85

	mdesc			cp_yld cp_hrv if cp_lnd != .
	*** none missing
	
	drop mi_miss cp_hrv_1_ cp_hrv_2_ cp_hrv_3_			

* **********************************************************************
* 4 - end matter, clean up to save
* **********************************************************************

* verify unique household id
	isid			hhid

* merge in geovars
	merge			m:1 hhid using "`root'/NGA_geovars", force
	keep			if _merge == 3
	drop			_merge
	
* generate year identifier
	gen				year = 2012
	lab var			year "Year"
		
	order 			zone state lga sector ea hhid aez year /// 	
					tf_hrv tf_lnd tf_yld tf_lab tf_frt ///
					tf_pst tf_hrb tf_irr cp_hrv cp_lnd cp_yld cp_lab ///
					cp_frt cp_pst cp_hrb cp_irr
	compress
	describe
	summarize 
	
* saving production dataset
	customsave , idvar(hhid) filename(hhfinal_ghsy2.dta) path("`export'") ///
			dofile(ghsy2_merge) user($user) 

* close the log
	log	close

/* END */
