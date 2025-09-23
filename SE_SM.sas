/* SE Domain */

proc datasets lib = work kill ; run;


filename selog "D:\PROJECT_SDTM_20_09_2025\LOG\SE_logs\selog_SM.log";
filename seout "D:\PROJECT_SDTM_20_09_2025\OUTPUT\SE_outputs\seout_SM.txt";

proc printto log = selog print = seout new;
run;

libname source 'D:\PROJECT_SDTM_20_09_2025\DATA\RAWDATA\21_09_2025';
libname seout 'D:\PROJECT_SDTM_20_09_2025\DATA\SDTM\SE';

data se_1;
	length DOMAIN $2 ELEMENT $20 EPOCH $20 ETCD $8;
	set output.dm_sm (drop=domain);
	DOMAIN = 'SE';
	SESEQ = 0;
	TAETORD = 0;
	
	if RFSTDTC ne '' then do;
		SESEQ   + 1;
		TAETORD + 1;
		ETCD     = 'SCRN';
		ELEMENT  = 'Screening';
		EPOCH    = 'SCREENING';
		SESTDTC  = RFICDTC;

		if not missing(RFXSTDTC) then SEENDTC = RFXSTDTC;
		else SEENDTC = RFICDTC;  
		output;

		if not missing(ACTARMCD) then do;
			SESEQ   + 1;
			TAETORD + 1;
			ETCD     = 'TRT';
			ELEMENT  = 'Treatment';
			EPOCH    = 'TREATMENT';
			SESTDTC  = RFXSTDTC;
			
			death_num = .; treat_num = .;
			if not missing(DTHDTC) then do;
				death_num = input(DTHDTC, e8601da10.);
				treat_num = input(RFXENDTC, e8601da10.);
			end;
			if not missing(death_num) and not missing(treat_num) and death_num < treat_num then SEENDTC = DTHDTC;
			else SEENDTC = RFXENDTC;
		
		output;
		
			SESEQ   + 1;
			TAETORD + 1;
			ETCD     = 'FUP';
			ELEMENT  = 'Follow-up';
			EPOCH    = 'FOLLOW UP';
			SESTDTC  = RFXENDTC;
			
			death_num2 = .; rfp_num = .;
			if not missing(DTHDTC) then do;
				death_num2 = input(DTHDTC, e8601da10.);
				rfp_num = input(RFPENDTC, e8601da10.);
			end;

				if not missing(death_num2) and not missing(rfp_num) and death_num2 < rfp_num then SEENDTC = DTHDTC;
				else SEENDTC = RFPENDTC;
/*			*/
/*				IF SESTDTC = SEENDTC THEN Seend_num =INPUT(SEENDTC, e8601da10.)+60;*/
/*				IF Seend_num NE . THEN SEENDTC = PUT(Seend_num, e8601da10.);*/
			IF RFPENDTC > RFXENDTC and RFXENDTC NE '' and DTHFL = '';

		output;
		end;
	end;

	keep STUDYID DOMAIN USUBJID SESEQ ETCD ELEMENT TAETORD EPOCH SESTDTC SEENDTC RFSTDTC RFENDTC dthdtc;
run;

data se_2;
	set se_1;
	SES_day = input (SESTDTC, E8601DA10.);
	RF_day = input (RFSTDTC, E8601DA10.);

	if not missing (SESTDTC) and not missing (RFSTDTC) then do;
		if SES_day >= RF_day then SESTDY = SES_day - RF_day + 1;
		else if SES_day < RF_day then SESTDY = SES_day - RF_day;
		else SESTDY = .;
	end;
	
	SEE_day = input (SEENDTC, E8601DA10.);
	*RFE_day = input (RFENDTC, E8601DA10.);

	if not missing (SEENDTC) and not missing (RFENDTC) then do;
		if SEE_day >= RF_day then SEENDY = SEE_day - RF_day + 1;
		else if SEE_day < RF_day then SEENDY = SEE_day - RF_day;
		else SEENDY = .;
	end;

	keep STUDYID DOMAIN USUBJID SESEQ ETCD ELEMENT TAETORD EPOCH SESTDTC SEENDTC SESTDY SEENDY ;
run;

data seout.SE_SM;
	retain STUDYID DOMAIN USUBJID SESEQ ETCD ELEMENT TAETORD EPOCH SESTDTC SEENDTC SESTDY SEENDY;

	set se_2;

	label 
		STUDYID = 'Study Identifier' 
		DOMAIN = 'Domain Abbreviation'
		USUBJID = 'Unique Subject Identifier'
		SESEQ = 'Sequence Number'
		ETCD = 'Element Code'
		ELEMENT = 'Description of Element'
		TAETORD = 'Planned Order of Element within Arm'
		EPOCH = 'Epoch'
		SESTDTC = 'Start Date/Time of Element'
		SEENDTC = 'End Date/Time of Element'
		SESTDY = 'Study Day of Start of Element'
		SEENDY = 'Study Day of End of Element';
run;

proc print data = seout.se_sm;
run;

proc printto;
run;

proc export data = seout.SE_SM
	outfile = 'D:\PROJECT_SDTM_20_09_2025\DATA\SDTM\SE\se_sm.xlsx'
	dbms = xlsx
	replace;
run;
