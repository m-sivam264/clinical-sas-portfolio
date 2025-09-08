
/*DM Domain Practice
	1. STUDYID - Equals to the value from raw.demog.STUDY
	2. DOMAIN - DM
	3. USUBJID - Derive by concatenating raw.demog.STUDY and raw.demog.PT variable values, separated with a hyphen in between.
	4. SUBJID - Equals to the value from raw.demog.PT
	5. SITEID - Equals to the first 2 characters from raw.demog.PT
	6. AGE - Equals to the value from raw.demog.AGE_RAW"
	7. AGEU - Equals to the value from raw.demog.AGE_RAWU
	8. SEX - Equals to the value from raw.demog.SEX after converting to standard controlled terminology.
	9. RACE - Derive sdtm.dm.RACE based on the values from raw.demog.RACE, raw.demog.RACE2, raw.demog.RACE3 and raw.demog.RACE4.
		If more than one of the above 4 variables is populated then assign a value of 'MULTIPLE', else assign the value from the 
		populated variable after converting to standard controlled terminology."
	10. ETHNIC - Equals to the value from raw.demog.ETHNIC after converting to standard controlled terminology.
	11. COUNTRY - "	Equals to the value from raw.demog.COUNTRY
*/

libname rawdata 'D:\Clinical_Projects\Domains_Learn\Classes\RAW';
libname DM 'D:\Clinical_Projects\Domains_Learn\Classes\DM';

data DM.DM1;
	set rawdata.Demog;

	STUDYID = left (STUDY); 
	DOMAIN = 'DM'; 
	USUBJID = catx('-', STUDY, PT) ;
	SUBJID = left (PT);
	SITEID = substr (PT,1,2);
	AGE = input(strip(AGE_RAW), best.);
	AGEU = upcase(strip(AGE_RAWU));

	if SEX = 'Female' then SEX = 'F';
	if SEX = 'Male' then SEX = 'M';
	If SEX = 'Others' then SEX = 'U';

	/*SEX = substr(strip(SEX),1,1);*/

	ETHNIC = upcase(strip(ETHNIC));
	COUNTRY = upcase(strip(COUNTRY));
	
	/*race*/
	length value $ 50;
	array races{4} RACE RACE2 RACE3 RACE4;
		count = 0;
		value = "";

	do i = 1 to 4;
	   if not missing(races[i]) then do;
	      count + 1;
	      value = races[i];
	   end;
	end;

	if count > 1 then RACE = "MULTIPLE";
	else if count = 1 then RACE = upcase(strip(value));
	else RACE = "";

	
	keep STUDYID DOMAIN USUBJID SUBJID SITEID AGE AGEU RACE SEX ETHNIC COUNTRY;
run;


/*deriving RFXSTDTC*/
/*"Derive the datetime value in ISO 8601 format by obtaining the earliest non-missing raw.ipadmin.IPSTDT_RAW and raw.ipadmin.
IPSTTM_RAW for each subject where raw.ipadmin.IPQTY_RAW is greater than 0."*/


data DM.DM2;
	set rawdata.Ipadmin;
	
	if IPQTY_RAW > 0;
	
	IPSTDT_CHAR = COMPRESS(strip(IPSTDT_RAW),'/');
	IPSTDT_NUM = input(IPSTDT_CHAR, date11.);
	
	IPSTTM_NUM = input(strip(IPSTTM_RAW), time5.);

	IPSTDT_TM_num = dhms(IPSTDT_num, hour(IPSTTM_num), minute(IPSTTM_num), second(IPSTTM_num));

	keep STUDY PT IPSTDT_NUM IPSTTM_NUM IPSTDT_TM_num;
run;


proc sort data = DM.DM2; by PT IPSTDT_TM_NUM; run;

data DM.DM3;
	set DM.DM2;
	by PT;
		
	if first.PT then do;
	RFXSTDTC = PUT(IPSTDT_TM_NUM, E8601DT19.);
	USUBJID =  catx('-', STUDY, PT);
	output;
	end;
	
	keep USUBJID RFXSTDTC;
run;

/* Deriving RFXENDTC
	"Derive the datetime value in ISO 8601 format by obtaining the latest non-missing raw.ipadmin.
IPSTDT_RAW and raw.ipadmin.IPSTTM_RAW for each subject where raw.ipadmin.IPQTY_RAW is greater than 0."
*/

data DM.DM4;
	set DM.DM2;
	by PT;
		
	if last.PT then do;
	RFXENDTC = PUT(IPSTDT_TM_NUM, E8601DT19.);
	USUBJID = catx('-', STUDY, PT) ;
	output;
	end;
	
	keep USUBJID RFXENDTC;
run;


/* RFENDTC
Derive the date value in ISO 8601 format by obtaining the value from raw.eos.EOSTDT_RAW where raw.eos.EOSCAT="End of Study"

*/

data DM.RFENDDTC;
	set rawdata.Eos;
	
	USUBJID = STUDY || '-' || PT ;
	if EOSCAT = 'End of Study' then do;
	RFENDTC_NUM = input(compress(strip(EOSTDT_RAW), '/'), date11.);;
	RFENDTC = put(RFENDTC_NUM, E8601DA10.);
	end;

	keep USUBJID RFENDTC;
run;

/*Deriving RFICDTC
	"	Derive the date value in ISO 8601 format by obtaining the value from raw.enrlment.ICDT_RAW."
*/

data DM.RFICDTC;
	set rawdata.Enrlment;
	
	USUBJID = catx('-', STUDY, PT) ;
	RFICDTC_CHAR = tranwrd(ICDT_RAW, '/','');	/*tranwrd-->searches and replaces*/
	RFICDTC_NUM = input(RFICDTC_CHAR, date11.);

	RFICDTC = put(RFICDTC_NUM, e8601da10.);

	keep USUBJID RFICDTC_CHAR RFICDTC_NUM RFICDTC;
run;


/* Deriving RFPENDTC
	"Derive the date value in ISO 8601 format by obtaining the latest date value from all raw datasets. 
	Date variables in a dataset can be identified with the suffix of 'DT_RAW'."


dt_raw var ds--> Adverse, Conmeds, ecg, enrlment, enoip, eos, eq5d3l, ipadmin, labchem, lab_hema, physmeas, rand, surg, vitals*/

data DM.Eos_dates;
    set rawdata.Eos(keep=STUDY PT EOSTDT_RAW);
   
        if not missing(EOSTDT_RAW) then do;
            dt_num = input(tranwrd(strip(EOSTDT_RAW), '/', ''), date11.);
        end;
    keep study pt dt_num;
run;

data DM.enrl_dates;
    set rawdata.enrlment(keep=study pt ICDT_RAW ENRLDT_RAW RANDDT_RAW);
    array dts {*} ICDT_RAW ENRLDT_RAW RANDDT_RAW;
    do i=1 to dim(dts);
        if not missing(dts{i}) then do;
            dt_num = input(compress(strip(dts{i}), '/'), date11.);
            output;
        end;
    end;
    keep study pt dt_num;
run;


data DM.Adverse_dates;
    set rawdata.Adverse(keep=STUDY PT AESTDT_RAW AEENDT_RAW);
    array dts {*} AESTDT_RAW AEENDT_RAW;
    do i=1 to dim(dts);
        if not missing(dts{i}) then do;
            dt_num = input(compress(strip(dts{i}), '/'), date11.);
            output;
        end;
    end;
    keep study pt dt_num;
run;

data DM.Conmeds_dates;
    set rawdata.Conmeds(keep=STUDY PT CMSTDT_RAW CMENDT_RAW);
    array dts {*} CMSTDT_RAW CMENDT_RAW;
    do i=1 to dim(dts);
        if not missing(dts{i}) then do;
            dt_num = input(compress(strip(dts{i}), '/'), date11.);
            output;
        end;
    end;
    keep study pt dt_num;
run;

data DM.Ecg_dates;
    set rawdata.Ecg(keep=STUDY PT EGDT_RAW);
   
        if not missing(EGDT_RAW) then do;
            dt_num = input(tranwrd(strip(EGDT_RAW), '/', ''), date11.);
        end;
    keep study pt dt_num;
run;

data DM.Eoip_dates;
    set rawdata.Eoip(keep=STUDY PT EOSTDT_RAW);
   
        if not missing(EOSTDT_RAW) then do;
            dt_num = input(tranwrd(strip(EOSTDT_RAW), '/', ''), date11.);
        end;
    keep study pt dt_num;
run;


data DM.Eq5d3l_dates;
    set rawdata.Eq5d3l(keep=STUDY PT DT_RAW);
   
        if not missing(DT_RAW) then do;
            dt_num = input(tranwrd(strip(DT_RAW), '/', ''), date11.);
        end;
    keep study pt dt_num;
run;

data DM.Ipadmin_dates;
    set rawdata.Ipadmin(keep=STUDY PT IPSTDT_RAW);
   
        if not missing(IPSTDT_RAW) then do;
            dt_num = input(tranwrd(strip(IPSTDT_RAW), '/', ''), date11.);
        end;
    keep study pt dt_num;
run;

data DM.Lab_chem_dates;
    set rawdata.Lab_chem(keep=STUDY PT LBDT_RAW);
   
        if not missing(LBDT_RAW) then do;
            dt_num = input(tranwrd(strip(LBDT_RAW), '/', ''), date11.);
        end;
    keep study pt dt_num;
run;


data DM.Lab_hema_dates;
    set rawdata.Lab_hema(keep=STUDY PT LBDT_RAW);
   
        if not missing(LBDT_RAW) then do;
            dt_num = input(tranwrd(strip(LBDT_RAW), '/', ''), date11.);
        end;
    keep study pt dt_num;
run;

data DM.Physmeas_dates;
    set rawdata.Physmeas(keep=STUDY PT PMDT_RAW);
   
        if not missing(PMDT_RAW) then do;
            dt_num = input(tranwrd(strip(PMDT_RAW), '/', ''), date11.);
        end;
    keep study pt dt_num;
run;

data DM.Surg_dates;
    set rawdata.Surg(keep=STUDY PT SURGDT_RAW);
   
        if not missing(SURGDT_RAW) then do;
            dt_num = input(tranwrd(strip(SURGDT_RAW), '/', ''), date11.);
        end;
    keep study pt dt_num;
run;


data DM.Vitals_dates;
    set rawdata.Vitals(keep=STUDY PT VSDT_RAW);
   
        if not missing(VSDT_RAW) then do;
            dt_num = input(tranwrd(strip(VSDT_RAW), '/', ''), date11.);
        end;
    keep study pt dt_num;
run;

/********************************TRYINNG MACROS********************************************/
/*CONVERTING DATE VALUES TO REQUIRED NUMBER FORMATS */

/*

%macro dateconversion (new=,old=,dat=);
	libname practice 'D:\Clinical_Projects\Domains_Learn\Classes\intermediary datasets';
		data practice.&new;
		    set rawdata.&old;
		   			USUBJID = catx('-', STUDY, PT);
		            dt_num = input(tranwrd(strip(&dat), '/', ''), date11.);

		    keep study pt USUBJID &dat dt_num;
		run;

		proc sort data = practice.&new;
			by USUBJID;
		run;
%mend;

%dateconversion (new=Adverse_dates, old=Adverse, dat = AEENDT_RAW);
%dateconversion (new=Eos_dates, old=eos, dat = EOSTDT_RAW);
%dateconversion (new=Conmeds_dates, old=Conmeds, dat = CMENDT_RAW);
%dateconversion (new=ecg_dates, old=ecg, dat = EGDT_RAW);
%dateconversion (new=enrlment1_dates, old=enrlment, dat = ICDT_RAW);
%dateconversion (new=enrlment2_dates, old=enrlment, dat = ENRLDT_RAW);
%dateconversion (new=enrlment3_dates, old=enrlment, dat = RANDDT_RAW);
%dateconversion (new=eoip_dates, old=eoip, dat = EOSTDT_RAW);
%dateconversion (new=eq5d3l_dates, old=eq5d3l, dat = DT_RAW);
%dateconversion (new=ipadmin_dates, old=ipadmin, dat = IPSTDT_RAW);
%dateconversion (new=lab_chem_dates, old=lab_chem, dat = LBDT_RAW);
%dateconversion (new=lab_hema_dates, old=lab_hema, dat = LBDT_RAW);
%dateconversion (new=Physmeas_dates, old=Physmeas, dat = PMDT_RAW);
%dateconversion (new=Surg_dates, old=Surg, dat = SURGDT_RAW);
%dateconversion (new=vitals_dates, old=vitals, dat = VSDT_RAW);

*/
/********************************TRYINNG MACROS********************************************/

/* COMIBING ALL*/

data dm.all_dates;
	set DM.Vitals_dates DM.Surg_dates DM.Physmeas_dates DM.Lab_hema_dates 
		DM.Lab_chem_dates DM.Ipadmin_dates DM.Eq5d3l_dates DM.Eos_dates DM.Eoip_dates DM.Ecg_dates DM.Conmeds_dates DM.Adverse_dates DM.enrl_dates;
run;

/* FINDING LAST DATE / MAX --- RFPENDTC */

proc sql;
	create table DM.RFPENDTC as select STUDY, PT, 
			catx('-', STUDY, PT) as USUBJID,
			max(dt_num) as RFPENDTC_NUM,
			put(calculated RFPENDTC_NUM, E8601DA10.) as RFPENDTC
	from DM.all_dates
	group by STUDY, PT;
quit;


/* DTHDTC, DTHFL	Derive the date value in ISO 8601 format by obtaining the value from raw.eos.EOSDT_RAW where
 raw.eos.EOSCAT=""End of Study"" and raw.eos.EOSTERM=""Death"""*/

/*
proc sql;
	create table DM.DTHDTC as select USUBJID, DTHDTC_NUM, put(DTHDTC_NUM, e8601da10.) as DTHDTC, DTHFL
		from (
			select  catx('-', STUDY, PT) as USUBJID,
			input(tranwrd(EOSTDT_RAW, '/',''), date11.) as DTHDTC_NUM,
			'Y' as DTHFL
			from rawdata.Eos 
			where EOSCAT = "End of Study" and EOTERM = "Death"
			);
quit;

proc print data = DM.DTHDTC; run;*/


data DM.DTHDTC2;
	set rawdata.eos;

	USUBJID = catx('-', STUDY, PT);

	if EOSCAT = "End of Study" and EOTERM = "Death" then do;
		DTHDTC_NUM = input(compress(EOSTDT_RAW, '/'), date11.);
		DTHDTC = put(DTHDTC_NUM, e8601da10.);
		DTHFL = 'Y';
	end;

	keep USUBJID DTHDTC DTHFL;
run;


/*	ARMCD 
"	Derive sdtm.dm.ARMCD based on the information present in raw.enrlment and raw.rand datasets.
Part A)
1) Fetch the randomization number for each subject from raw.enrlment.RANDNO.
2) Fetch the raw.rand.TX_CD as ARMCD by joining the datasets based on RANDNO and raw.rand.RAND_ID.

Part B)
For the subjects with raw.enrlment.ICDT_RAW not null and raw.enrlment.ENRLDT_RAW is null, assign as 'SCRNFAIL'.
Part C)
For the subjects with raw.enrlment.ENRLDT_RAW not null and raw.enrlment.RANDDT_RAW is null, assign as 'NOTASSGN'."
*/

/*	ARM
"Assign as 'Active' when sdtm.dm.ARMCD is equal to 'ACTIVE'.
Else assign as 'Placebo' when sdtm.dm.ARMCD is equal to 'PBO'.
Else assign as 'Screen Failure' when sdtm.dm.ARMCD=""SCRNFAIL"".
Else assign as 'Not Assigned' when sdtm.dm.ARMCD=""NOTASSGN"""
*/
proc sort data = rawdata.rand; by RAND_ID; run;
proc sort data = rawdata.enrlment; by RANDNO; run;
data DM.RANDENRLMENT;
	merge rawdata.rand (in = a) 
		rawdata.enrlment (in = b rename = (RANDNO = RAND_ID));
	by RAND_ID;
	if b;
	USUBJID = catx('-', STUDY, PT);
run;

/* THIS IS ACCORDING TO DM SPECIFICATION FILE --  WHERE ARMNRS, ACTARMUD NOT FOUND

proc sql;
	create table DM.ARMCD as select USUBJID, RANDNO, ARMCD,
	
	case
		when ARMCD = 'ACTIVE' then 'Active'
		when ARMCD = 'PBO' then 'Placebo'
		when ARMCD = 'SCRNFAIL' then 'Screen Failure'
		when ARMCD = 'NOTASSGN' then 'Not Assigned'
	end as ARM
		from (
			select USUBJID, RAND_ID as RANDNO,
			case 
				when not missing(ICDT_RAW) and missing(ENRLDT_RAW) then 'SCRNFAIL'
				when not missing(ENRLDT_RAW) and missing(RANDDT_RAW) then 'NOTASSGN'
				else TX_CD
			end as ARMCD from DM.RANDENRLMENT
			);
quit;*/

proc sql;
	create table DM.ARMCD as select USUBJID, RANDNO, ARMCD,
	
	case
		when ARMCD = 'ACTIVE' then 'Active'
		when ARMCD = 'PBO' then 'Placebo'
		else ''
	end as ARM
		from (
			select USUBJID, RAND_ID as RANDNO,
			case 
				when not missing(ICDT_RAW) and missing(ENRLDT_RAW) then ''
				when not missing(ENRLDT_RAW) and missing(RANDDT_RAW) then ''
				else TX_CD
			end as ARMCD from DM.RANDENRLMENT
			);
quit;

proc sql;
	create table DM.ARMNRS as select USUBJID,
		case
			when not missing(ICDT_RAW) and missing(ENRLDT_RAW) then 'SCRNFAIL'
			when not missing(ENRLDT_RAW) and missing(RANDDT_RAW) then 'NOTASSGN'
		end as ARMNRS from DM.RANDENRLMENT;
quit;



/*	ACTARMCD
"Derive sdtm.dm.ACTARMCD based on the information present in raw.ipadmin and raw.box datasets.
Part A)
1) Fetch the raw.ipadmin.IPBOXID from the earliest record with non-missing IPQTY_RAW for each subject.
2) Fetch the raw.box.CONTENT as ACTARMCD by joining the datasets based on IPBOXID and raw.box.KITID.
Part B)
For subjects with sdtm.dm.ARMCD in (""SCRNFAIL"" ""NOTASSGN"") assign the value of sdtm.dm.ARMCD.
Part C)
For the subjects with raw.rand.RANDDT_RAW not null and sdtm.dm.RFXSTDTC is null, assign as 'NOTTRT'."
*/

proc sort data = rawdata.ipadmin; by PT IPSTDT_RAW; run;

data DM.BOXIDS;
	set rawdata.ipadmin;
	by PT;

	if not missing(IPQTY_RAW) then do;
		if first.PT;
		output;
	end;

	*keep IPBOXID IPQTY_RAW;
run;

proc sort data = rawdata.box; by KITID; run;
proc sort data = DM.BOXIDS; by IPBOXID; run;

data DM.BOXKITID;
	merge rawdata.box (in = a rename = (KITID = BOXID))
			DM.BOXIDS (in = b rename = (IPBOXID = BOXID));
		by BOXID;
		
		if b;
		
		length ACTARM $ 14 USUBJID $ 14;
		USUBJID = catx('-', STUDY, PT);
		ACTARMCD = strip(CONTENT);

		

		if ACTARMCD = 'ACTIVE' then ACTARM = 'Active';
		else if ACTARMCD = 'PBO' then ACTARM = 'Placebo';
		else if ACTARMCD = 'SCRFAIL' then ACTARM = 'Screen Failure';
		else if ACTARMCD = 'NOTASSGN' then ACTARM = 'Not Assigned';

		keep USUBJID ACTARMCD ACTARM;
run;



/*
		DMDTC
dm.rficdtc in is08601 as dmdtc
*/

proc sql;
	create table DM.DMDTC as select USUBJID, RFICDTC as DMDTC 
	from DM.RFICDTC;
quit;
	

/* PRE FINAL DOMAIN PREP*/

proc sort data = DM.DM1; by USUBJID; run;
proc sort data = DM.DM3; by USUBJID; run;
proc sort data = DM.DM4; by USUBJID; run;
proc sort data = DM.DMDTC; by USUBJID; run;
proc sort data = DM.BOXKITID; by USUBJID; run;
proc sort data = DM.ARMCD; by USUBJID; run;
proc sort data = DM.DTHDTC2; by USUBJID; run;
proc sort data = DM.RFPENDTC; by USUBJID; run;
proc sort data = DM.RFICDTC; by USUBJID; run;
proc sort data = DM.RFENDDTC; by USUBJID; run;
proc sort data = DM.ARMNRS; by USUBJID; run;





/* adding RFXSTDTC*/
data DM.ONE;
	merge DM.DM1 (in = a)
		DM.DM3 (in = b);
	by USUBJID;
	if a;
run;

/*adding RFSTDTC */

data DM.TWO;
	set DM.ONE;

	if not missing (RFXSTDTC) then do;
	RFSTDTC = scan(RFXSTDTC,1,'T');
	end;
run;


/* for missing RFSTDTC values*/

data DM.ENRLMENT;
	set rawdata.Enrlment;

	USUBJID = catx('-', STUDY, PT);
	if ~missing(RANDDT_RAW) then RFSTDTC_MISS=put(input(RANDDT_RAW,date11.),yymmdd10.);
	keep USUBJID RANDDT_RAW  RFSTDTC_MISS;
run;

proc sort data = DM.Enrlment; by USUBJID; run;
data DM.THREE;
	merge DM.TWO (in = a)
		DM.ENRLMENT (in = b);
	by USUBJID;

	if missing(RFSTDTC) then do;
		RFSTDTC = RFSTDTC_MISS;
	end;
	drop  RANDDT_RAW RFSTDTC_MISS;
run;

/*adding RFENDTC*/

data DM.FOUR;
	merge DM.THREE (in = a)
		DM.RFENDDTC (in = b);
	by USUBJID;

	if a;
run;

/*adding RFXENDDTC*/
data DM.FIVE;
	merge DM.FOUR (in = a)
		DM.DM4 (in = b);
	by USUBJID;
	if a;
run;

/*adding RFICDTC*/
data DM.SIX;
	merge DM.FIVE (in = a)
		DM.RFICDTC (in = b);
	by USUBJID;
	if a;

	drop RFICDTC_NUM RFICDTC_CHAR;
run;

/*Else assign the value of sdtm.dm.RFICDTC for RFSTDTC*/

data DM.SEVEN;
	set DM.SIX;

	if RFSTDTC = '' then RFSTDTC = RFICDTC;
run;

/*adding RFPENDTC*/
data DM.EIGHT;
	merge DM.SEVEN (in = a)
		DM.RFPENDTC (in = b);
	by USUBJID;

	drop STUDY PT RFPENDTC_NUM;
run;

/*adding DTHDTC, DTHFL*/

data DM.NINE;
	merge DM.EIGHT (in = a)
		DM.DTHDTC2 (in = b);
	by USUBJID;
	if a;

	if missing(DTHFL) then DTHFL = 'N';
run;

/* adding ARMCD, ARM*/

data DM.TEN;
	merge DM.NINE (in = a)
		DM.ARMCD (in = b);
	by USUBJID;
	if a;

	drop RANDNO;
run;

/*adding ACTARMCD, ACTARM  */
data DM.ELEVEN;
	merge DM.TEN (in = a)
		DM.BOXKITID (in = b);
	by USUBJID;
	if a;
run;

data DM.TWELVE;
	length ARMNRS $ 20;
	merge DM.ELEVEN (in = a)
		DM.ARMNRS (in = b);
	by USUBJID;
	if a;

	if not missing(ARMCD) and missing(ACTARMCD) then ARMNRS = 'Not Treated';
run;

proc sql;
	create table DM.ACTARMUD as select USUBJID, ARMCD, ACTARMCD,
		case
			when not missing(ARMCD) and missing(ACTARMCD) then ''
			when ARMCD ^= ACTARMCD then 'Treatment Error'
			else ''
		end as ACTARMUD from DM.TWELVE;
quit;


data DM.THIRTEEN;
	merge DM.TWELVE (in = a)
		DM.ACTARMUD (in = b);
	by USUBJID;
	if a;
run;


/* adding DMDTC & DMDY */
/*if dmdtc greater than or equal to rfstdtc then dmdtc-rfstdtc+1 else dmdtc-rfstdtc*/

data DM.FOURTEEN;
	merge DM.THIRTEEN (in = a)
		DM.DMDTC (in = b);
	by USUBJID;
	if a;
	
	if not missing(DMDTC) then DMDTC_NUM = input(DMDTC, E8601DA10.);
	RFSTDTC_NUM = input(RFSTDTC, E8601DA10.);

	if DMDTC >= RFSTDTC then DMDY = DMDTC_NUM - RFSTDTC_NUM + 1;
	else DMDY = DMDTC_NUM - RFSTDTC_NUM;
	
	drop DMDTC_NUM RFSTDTC_NUM;
run;

/*FINAL DOMAIN*/

libname SDTM 'D:\Clinical_Projects\Domains_Learn\Classes\SDTM DOMAINS';


proc sql;
	create table SDTM.DM_SIVA_M as
	select STUDYID, DOMAIN, USUBJID, SUBJID, RFSTDTC, RFENDTC, RFXSTDTC, RFXENDTC, RFICDTC, RFPENDTC,DTHDTC, DTHFL, SITEID,
			AGE, AGEU, SEX, RACE, ETHNIC,
			ARMCD, ARM, ACTARMCD, ACTARM, ARMNRS, ACTARMUD, COUNTRY, DMDTC, DMDY
	from DM.FOURTEEN;
quit; 
proc datasets lib=SDTM nolist;
    modify DM_SIVA_M;

	label STUDYID = 'Study Identifier'
			DOMAIN = 'Domain Abbreviation'
			USUBJID = 'Unique Subject Identifier'
			SUBJID = 'Subject Identifier for the Study'
			RFSTDTC = 'Subject Reference Start Date/Time'
			RFENDTC = 'Subject Reference End Date/Time'
			RFXSTDTC = 'Date/Time of First Study Treatment'
			RFXENDTC = 'Date/Time of Last Study Treatment'
			RFICDTC = 'Date/Time of Informed Consent'
			RFPENDTC = 'Date/Time of End of Participation'
			DTHDTC = 'Date/Time of Death'
			DTHFL = 'Subject Death Flag'
			SITEID = 'Study Site Identifier'
			AGE = 'Age'
			AGEU = 'Age Units'
			SEX = 'Sex'
			RACE = 'Race'
			ETHNIC = 'Ethnicity'
			ARMCD = 'Planned Arm Code'
			ARM = 'Description of Planned Arm'
			ACTARMCD = 'Actual Arm Code'
			ACTARM = 'Description of Actual Arm'
			ARMNRS = 'Reason Arm and/or Actual Arm is Null'
			ACTARMUD = 'Description of Unplanned Actual Arm'
			COUNTRY = 'Country'
			DMDTC = 'Date/Time of Collection'
			DMDY = 'Study Day of Collection';
quit;


proc print data = SDTM.DM_SIVA_M ; run;
