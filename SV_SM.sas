/* ---- 22 -09 - 2025 SV CODE EXAMPLE ---- */

proc datasets lib = work kill ; run;

filename SVlog "D:\PROJECT_SDTM_20_09_2025\LOG\SV_logs\SVlog_SM.log";
filename SVout "D:\PROJECT_SDTM_20_09_2025\OUTPUT\SV_outputs\SVout_SM.lst";
proc printto log = SVlog print = SVout new;
run;

libname source "D:\PROJECT_SDTM_20_09_2025\DATA\RAWDATA\21_09_2025";
libname output "D:\PROJECT_SDTM_20_09_2025\DATA\SDTM\DM";
libname out "D:\PROJECT_SDTM_20_09_2025\DATA\SDTM\SV";

data temp;
length VISIT1 $ 8.;
	set output.dm_sm (keep = subjid rficdtc);
	
	subjid = propcase(SUBJID);
	rfdate = input (rficdtc, e8601da10.);

	VISIT1 = 'SCR';
	

	drop rficdtc;
run;


data sv1;
	set temp (rename = (rfdate = svdate))
		source.rawvs (keep = subjid vsdate visit rename = (vsdate = svdate visit = VISIT1));

	*VISITNUM = 1;
	*if SUBJID = 'Jagadish';

run;

proc sort data = sv1;
	by subjid visit1 svdate;
run;

data sv_start sv_end;
	set sv1;
	by subjid visit1 svdate;

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
	merge sv_start (in = a keep = SUBJID VISIT1 SVSTDTC)
		sv_end (in = b keep = SUBJID VISIT1 SVENDTC);
		by SUBJID;
		IF A;

		VISIT = VISIT1;

/*		VISITNUM = input(compress(visit, '', 'kd'), best.);*/
/*		if visit = 'SCR' then VISITNUM = -1;*/
/*		else if visit = '*/

	drop VISIT1;
run;

proc sort data = sv3;
	by subjid svstdtc;
run;
data jag;
	set sv3;
	by subjid svstdtc;

	DOMAIN = 'SV';
	VISIT = UPCASE (VISIT);
	SUBJID = UPCASE(SUBJID);
	SVPRESP = 'Y';
	SVOCCUR = 'Y';
	VISITDY = .;

	retain VISITNUM;
	if first.subjid then VISITNUM = 1;
	else VISITNUM = int(VISITNUM + 1);

	if visit = 'UNSHU' or visit = 'UNSHULE' then do;
		VISIT = 'UNSHU';
		VISITNUM = VISITNUM - 0.9;
		SVPRESP = '';
		SVOCCUR = '';
		SVUPDES = 'Adverse Event Occoured';
	end;

run;

proc sort data = output.dm_sm out = dm_sm;
	by SUBJID;
run;

proc sort data = jag;
	by subjid;
run;

data jag2;
	merge jag (in = a)
			dm_sm (in = b keep = STUDYID USUBJID SUBJID RFSTDTC);
		BY SUBJID;
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

		drop svst_dy rf_dy RFSTDTC SUBJID;

run;


data out.SV_SM;
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
run;

proc printto;
run;

proc export data = out.SV_sm
	outfile = 'D:\PROJECT_SDTM_20_09_2025\DATA\SDTM\SV\SV_SM.xlsx'
	dbms = xlsx
	replace;
run;
