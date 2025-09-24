/* ---- 22 -09 - 2025 SV CODE EXAMPLE ---- */

proc datasets lib = work kill ; run;

filename SVlog "D:\PROJECT_SDTM_20_09_2025\LOG\SV_logs\SVlog_SM.log";
filename SVout "D:\PROJECT_SDTM_20_09_2025\OUTPUT\SV_outputs\SVout_SM.lst";
proc printto log = SVlog print = SVout new;
run;

libname source "D:\PROJECT_SDTM_20_09_2025\DATA\RAWDATA\21_09_2025";
libname dm "D:\PROJECT_SDTM_20_09_2025\DATA\SDTM\DM";
libname sv "D:\PROJECT_SDTM_20_09_2025\DATA\SDTM\SV";


proc sort data = source.rawvs; by subjid;run;
proc sort data = source.rawdm; by subjid;run;
data vsdm;
 merge source.rawvs (in = a)
 		source.rawdm ( in = b keep = subjid site studyid);
	  by subjid;
	  if b;
	  USUBJID  = catx('-', UPCASE(strip(studyid)), site, put(subjcode,best.));
run;
data temp;
length VISIT1 $ 8.;
	set dm.dm_sm (keep = usubjid subjid rficdtc);
	
	
	rfdate = input (rficdtc, e8601da10.);

	VISIT1 = 'SCR';
	drop rficdtc subjid;
run;


proc sort data = vsdm ; by usubjid;run;
proc sort data = temp ; by usubjid;run;

data sv1;
	set temp (rename = (rfdate = svdate))
		vsdm (keep = USUBJID vsdate VISIT rename = (vsdate = svdate visit = VISIT1));

	*VISITNUM = 1;
	*if SUBJID = 'Jagadish';

run;

proc sort data = sv1;
	by USUBJID visit1 svdate;
	where svdate ne .;
run;

data sv_start sv_end;
	set sv1;
	by USUBJID visit1 svdate;

	if first.visit1 then do;
		SVSTDTC = SVDATE;
		format SVSTDTC E8601DA10.;
	output sv_start;
	end;

	IF LAST.VISIT1 THEN do;
		SVENDTC = SVDATE;
		format SVENDTC E8601DA10.;
	output sv_end;
	end;

	*keep SUBJID VISIT1 VISITNUM SVSTDTC SVENDTC SVDATE;
*proc sort;
*by subjid visit1 svstdtc;
run;


data sv3;
	merge sv_start (in = a keep = USUBJID VISIT1 SVSTDTC)
		sv_end (in = b keep = USUBJID VISIT1 SVENDTC);
		by USUBJID;
		IF A;

		VISIT = VISIT1;

/*		VISITNUM = input(compress(visit, '', 'kd'), best.);*/
/*		if visit = 'SCR' then VISITNUM = -1;*/
/*		else if visit = '*/

	drop VISIT1;
run;

proc sort data = sv3;
	by usubjid svstdtc;
run;

data jag;
    length VISIT $25.;
    set sv3;
	by usubjid svstdtc;

	DOMAIN = 'SV';
	VISIT = UPCASE (VISIT);
	SVPRESP = '';
	SVOCCUR = '';
	VISITDY = .;
	
	retain VISITNUM;
	if first.usubjid then VISITNUM = 1;
	else VISITNUM = int(VISITNUM + 1);

	if visit = 'UNSHU' or visit = 'UNSHULE' then do;
	    VISITNUM = VISITNUM - 0.9;
		VISIT = catx("-","Unscheduled", put(VISITNUM, best.));
		SVPRESP = '';
		SVOCCUR = '';
		SVUPDES = 'Source Domain Code';
	end;
run;

/*
proc format;
	value $visit
		'SCR' = 'Screening'
		'VISIT1' = 'Treatment - 1'
		'VISIT2' = 'Treatment - 2'
		'VISIT3' = 'Treatment - 3'
		'FLU1' = 'Follow Up - 1'
		'FLU2' = 'Follow Up - 2';
run;
*/

data vsfmt;
	length VISIT $ 30.;
	set jag;
	if visit = 'SCR' then VISIT = 'Screening';
	else if visit = 'VISIT1' then VISIT = 'Treatment - 1';
	else if visit = 'VISIT2' then VISIT = 'Treatment - 2';
	else if visit = 'VISIT3' then VISIT = 'Treatment - 3';
	else if visit = 'FLU1' then VISIT = 'Follow Up - 1';
	else if visit = 'FLU2' then VISIT = 'Follow Up - 2';

    if visit = 'Screening' then  VISITDY = -5;
	else if visit = 'Treatment - 1' then  VISITDY = 1;
	else if visit =  'Treatment - 2' then  VISITDY = 25;
	else if visit = 'Treatment - 3' then  VISITDY = 55;
	else if visit = 'Follow Up - 1' then  VISITDY = 85;
	else if visit = 'Follow Up - 2' then  VISITDY = 115;

	 if index(VISIT,"Unscheduled") > 0 then VISITNUM = 99;
run;


proc sort data = dm.dm_SM out = dm_ksg;
	by USUBJID;
run;

proc sort data = vsfmt;
	by USUBJID;
run;

data jag2;
	merge vsfmt (in = a)
			dm_ksg (in = b keep = STUDYID USUBJID SUBJID RFSTDTC);
		BY USUBJID;
		if a;

		if not missing(RFSTDTC) and not missing(SVSTDTC) then do;
			svst_dy = SVSTDTC;
			rf_dy = input (RFSTDTC, E8601DA10.);

			if svst_dy >= rf_dy then SVSTDY = svst_dy - rf_dy + 1;
			else if svst_dy < rf_dy then SVSTDY = svst_dy - rf_dy;
		end;
		
		if not missing(RFSTDTC) and not missing(SVENDTC) then do;
			svst_dy = SVENDTC;
			rf_dy = input (RFSTDTC, E8601DA10.);

			if svst_dy >= rf_dy then SVENDY = svst_dy - rf_dy + 1;
			else if svst_dy < rf_dy then SVENDY = svst_dy - rf_dy;
		end;

		drop svst_dy rf_dy RFSTDTC;

run;


data sv.SV_SM;
	retain STUDYID DOMAIN USUBJID VISITNUM VISIT SVPRESP SVOCCUR VISITDY SVSTDTC SVENDTC SVSTDY SVENDY SVUPDES;

	set jag2;

	label 	DOMAIN = 'Domain Abbreviation'
			VISITNUM = 'Visit Number'
			VISIT = 'Visit Name'
			SVPRESP = 'Pre-specified'
			SVOCCUR = 'Occurrence'
			VISITDY = 'Planned Study Day of Visit'
			SVSTDTC = 'Start Date/Time of Observation'
			SVENDTC = 'End Date/Time of Observation'
			SVSTDY = 'Study Day of Start of Observation'
			SVENDY = 'Study Day of End of Observation'
			SVUPDES = 'Description of Unplanned Visit';
			drop subjid;
run;

proc printto;
run;

proc export data = sv.SV_sm
	outfile = 'D:\PROJECT_SDTM_20_09_2025\DATA\SDTM\SV\SV_SM.xlsx'
	dbms = xlsx
	replace;
run;
