/* CO Domain */



filename logfile "D:\PROJECT_SDTM_20_09_2025\LOG\colog_SM.log";
filename outfile "D:\PROJECT_SDTM_20_09_2025\OUTPUT\coout_sm.lst";

proc printto log = logfile print = outfile new; run; 

proc datasets lib = work kill ; run;

libname source "D:\PROJECT_SDTM_20_09_2025\DATA\RAWDATA\21_09_2025";
libname output 'D:\PROJECT_SDTM_20_09_2025\DATA\SDTM';
/*

data source.comment_new1;
   length vsco $1000; 
   infile datalines truncover;
   input subjid $ codate  :ddmmyy10.  seq vsco $char1000.;
   format     codate ddmmyy10.;
datalines;
Pooja 30/04/2022 1 In a typical clinical trial programming workflow, raw clinical data is first standardized into SDTM (Study Data Tabulation Model) datasets. These SDTM domains provide a consistent structure for regulatory agencies. Next, SDTM data is transformed into ADaM (Analysis Data Model) datasets, which are designed to support statistical analysis and traceability. From ADaM datasets, programming teams generate TLFs (Tables, Listings, and Figures) that summarize the study results. Alongside datasets and outputs, supportive documentation is produced, including the SDRG (Study Data Reviewer's Guide), ADRG (Analysis Data Reviewer's Guide), and the Define-XML metadata file. These documents explain dataset structures, derivations, and analysis methodology. The full package is prepared for regulatory submission to agencies such as the FDA in the United States and PMDA in Japan. This process ensures compliance with CDISC standards, provides transparency to reviewers, and supports efficient and accurate drug approval evaluations.
;
run;
 
data source.comment_new2;
   length aeco $1000; 
   infile datalines truncover;
   input subjid $ codate  :ddmmyy10.  seq eval$  aeco $char1000.;
   format     codate ddmmyy10.;
datalines;
SHRAVYA  01/04/2022 2 child the AE (Adverse Events) domain captures details about subjects' medical events during a clinical
run;*/

/*
special purpose 4
 dm
 se
 sv
 co

 STUDYID - DM
 DOMAIN = CO
 RDOMAIN = PARENT RECORD DOMAIN 
 USUBJID = DM
 COSEQ = RAWCOMENT DATA
 IDVAR = PARENT RECORD DOMAIN
 IDVARVAL = ''
 COREF = NULL
 COVAL = <=200, COVAL1, COVAL2,
 COEVAL = RAWCOMENT DATA
 COEVALID = ''
 CODTC = DATE
 CODY = RFSTDTC and CODTC --> DM*/

proc sort data = source.rawdm out = rawdm;
	by subjid;
run;

data co1;
	set rawdm (keep = studyid subjid subjcode site);
	SUBJID = upcase(SUBJID);
	STUDYID = upcase(STUDYID);
	USUBJID = catx('-', STUDYID, site, SUBJCODE);
	keep USUBJID SUBJID STUDYID;
	where SUBJID = 'Pooja' /*or SUBJID = 'SHRAVYA'*/;
/*	and SUBJID = 'SHRAVYA';*/
run;

data co2;
	set rawdm (keep = studyid subjid subjcode site);
	SUBJID = upcase(SUBJID);
	STUDYID = upcase(STUDYID);
	USUBJID = catx('-', STUDYID, site, SUBJCODE);
	keep USUBJID SUBJID STUDYID;
	where SUBJID = 'SHRAVYA';
/*	and SUBJID = 'SHRAVYA';*/
run;

data comment1;
	set source.comment_new1;
	subjid = upcase(subjid);
run;

data comment2;
	set source.comment_new2;
	subjid = upcase(subjid);
run;

data co3;
	merge co1 comment1;
	by subjid;
run;

data co4;
	merge co2 comment2;
	by subjid;
run;

/*
string funnctions

index => index(variable, 'wrd')
substr => substr(variable, 1, how many charecters);
scan => scan(variable, position, 'delimiter');
length => length(variable);
FIND(string, substring)
*/

%macro comment(dsin, dsout, varin);
	data &dsout;
		set &dsin;
		length COVAL1 - COVAL5 $ 200;
		start = 1;

		array coval[5] $200 COVAL1 - COVAL5;

		do i = 1 to dim(coval);
			temp_string = substr(&varin, start, 200);

			find_space = length(strip(temp_string));
			do j = find_space to 1 by -1;
				if substr(temp_string, j, 1) = ' ' then do;
					coval[i] = substr(temp_string, 1, j-1);
					start = start + j;
					leave;
				end;
				end;

			if coval[i] = '' then do;
				coval[i] = temp_string;
				start = start + 200;
			end;
		end;
		if COVAL1 ne '';
	drop i j temp_string find_space &varin start;
	run;
%mend comment;

options symbolgen mprint;
%comment (co3, vscom, vsco);
%comment (co4, aecom, aeco);

proc sort data = vscom; by USUBJID; run;
proc sort data = aecom; by USUBJID; run;

data co5;
	set vscom aecom;
run;

proc sort data = co5; by USUBJID; run;
proc sort data = output.dm_sm out = dm; by USUBJID; run;

data co6;
	retain STUDYID DOMAIN RDOMAIN USUBJID COSEQ IDVAR IDVARVAL COVAL1 COVAL2 COVAL3 COVAL4 COVAL5 EVAL COEVAL COEVALID CODTC CODY;
	merge co5 (in = a )
			dm (in = b keep = USUBJID RFSTDTC);
	by USUBJID;
	if a;
	
	DOMAIN = 'CO';
	if cmiss(COVAL1, COVAL2, COVAL3, COVAL4, COVAL5) => 3 then RDOMAIN = 'AE';
	else if cmiss(COVAL1, COVAL2, COVAL3, COVAL4, COVAL5) < 1 then RDOMAIN = 'VS';

	if first.USUBJID then COSEQ = 1;
	else COSEQ + 1;

	IDVAR = seq;
	IDVARVAL = '';

	if not missing(eval) then do;
		COEVALID = 'DERMATOLOGIST 1';
		COEVAL = upcase(strip(eval));
	end;
	else do;
		COEVALID = '';
		COEVAL = '';
	end;

	CODTC = put(codate, e8601da10.);
	
		rf_dy = input(RFSTDTC, e8601da10.);

		if codate < rf_dy then CODY = codate - rf_dy;
		else if codate >= rf_dy then CODY = codate - rf_dy + 1;
		else CODY = .;
	drop subjid codate seq rf_dy RFSTDTC eval;
/*	drop subjid codate seq;*/
run;

/* ------- FINISHED ------ */

%macro label;
	label
	%do j = 1 %to 5;
		COVAL&j = "Comment &j"
	%end;
	;
%mend label;


data output.CO_SM;
	set co6;
	
	%label;

	label IDVAR = 'Identifying Variable'
			RDOMAIN = 'Related Domain Abbreviation'
			DOMAIN = 'Domain Abbreviation'
			STUDYID = 'Study Identifier'
			COSEQ = 'Sequence Number'
			IDVARVAL = 'Identifying Variable Value'
			COEVAL = 'Evaluator'
			COEVALID = 'Evaluator Identifier'
			CODTC = 'Date/Time of Comment'
			CODY = 'Study Day of Comment';
run;

proc prtin data = output.co_sm; run;

proc printto;
run;
