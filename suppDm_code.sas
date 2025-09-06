/* SUPPDM PREPARATION */

/*
	1. Take values from rawdata.demog (STUDY, PT, RACE1, 2,3, 4, ...)
	2. Use array to track the non missing values count.
	3. If that value is more than 1. then it goes to SUPPDM.
	4. STUDYID
*/

libname SDTM 'D:\Clinical_Projects\Domains_Learn\Classes\SDTM DOMAINS';
libname rawdata 'D:\Clinical_Projects\Domains_Learn\Classes\RAW';
libname supD'D:\Clinical_Projects\Domains_Learn\Classes\SUPP DOMAINS';

data supD.sup1;
	set rawdata.Demog (keep = STUDY PT RACE RACE2 RACE3 RACE4 RACESP);
	
	STUDYID = strip(STUDY);
	USUBJID = catx('-', STUDY, PT);
	
	count = 0;
	value = 0;
	array rc[*] RACE RACE2 RACE3 RACE4 RACESP;
		
		do i = 1 to dim(rc);
			if not missing(rc[i]) then do;
				count = count + 1;
				value = count;
			end;
		end;
	

		if value > 1 then do;
			RDOMAIN = 'DM';

			IDVAR = '';
			IDVARVAL = '';

			do j = 1 to dim(rc);
            	if not missing(rc[j]) then do;
					QNAM = catx('', 'RACE',put(j, best.));
					QLABEL = 'Reported Race (' || strip(put(j,best.)) || ')';
					QVAL = strip(rc[j]);
				output;
				end;
			end;
		end;

	drop count value i j;
proc print;
run;

data SDTM.suppDM;
	set supD.sup1 (drop = STUDY PT RACE RACE2 RACE3 RACE4 RACESP);
run;
proc print;


 
