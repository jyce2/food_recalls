%LET job=project_draft_codebook;
%LET onyen=jyc85;
%LET outdir=/home/u63543840/BIOS669;

*proc printto log="&outdir/Logs/&job._&onyen..log" new;* run; 

*********************************************************************
*  Assignment:    BIOS 669: Final Project                 
*                                                                    
*  Description:   draft codebook
*
*  Name:          Joyce Choe
*
*  Date:          4/30/2024                                
*------------------------------------------------------------------- 
*  Job name:      project_jyc85.sas   
*
*  Purpose:       Codebook for variables
*				       
*  Language:      SAS, VERSION 9.4  
*
*  Input:         lib.recalls dataset
*
*  Output:        PDF file
*                                                                    
********************************************************************;
OPTIONS nodate mergenoby=warn varinitchk=warn nofullstimer mprint;
FOOTNOTE "Job &job._&onyen run on &sysdate at &systime";
LIBNAME lib "&outdir/Data";

ODS PDF FILE="&outdir/Output/&job._&onyen..PDF" STYLE=JOURNAL startpage=on;

* variable/codebook loop;
%macro codebookloop(lib=, ds=);

	*macro varlist variable;
	proc sql noprint;
	    select name into :var separated by ' '
	        from dictionary.columns
	        where upcase(libname)="&lib" and upcase(memname)="&ds"
			order by name;
		%let totalvar= &sqlobs;
		%put &var;
	    reset noprint;
	    
	* macro date variable;
		select name into :datevar separated by ' '
			from dictionary.columns
        	where upcase(libname)="&lib" and upcase(memname)="&ds"
        	and index(format,'DATE')>0;
		%let totaldate= &sqlobs;
      quit;
   	
	%put &var are &totalvar total variables;
	%put &datevar are &totaldate total date variables;
	* begin loop here to separate vars for using in functions;
	%do i=1 %to &totalvar;
		
		* scan through total var;
		%let each= %scan(%bquote(&var), &i, %str( ));
		%put &each;
			
        %if &each=%scan(&var,1) %then %do;
            title "Codebook for lib.recalls data set" bold;
        %end;
        %else %do; 
        	title; *turn off title;
        %end;
     
     * loop through date vars;
     %do j=1 %to &totaldate;
     
     	%let eachdate= %scan(%bquote(&datevar), &j, %str( ));
		%put &eachdate;
     %end;
	
	* macro variable count N;
	proc sql noprint; 
	select count(distinct &each) into :noobs separated by ' '
		from &lib..&ds;
	quit;
	
	%put &each has &noobs unique values; 
	
	
	* macro variable type (note: vtype is numeric);
	data _null_;
		set lib.recalls;
		type = vtype(%nrbquote(&each));
        vlab = vlabel(%nrbquote(&each));
		
		call symputx("vartype", type);
		call symputx("vlabel",vlab);
		stop;
	run;
	
	%if &each = &eachdate %then %do;
		
	title1 "&eachdate (&vartype) &noobs unique values" bold;
	*title2 "&vlabel";
		proc tabulate data=&lib..&ds;
		var &eachdate;
		table &eachdate,
		n nmiss (min max median)*f=date9. range;
		format &eachdate date9.;
		run;
	title;
	%end;
	
	%else %if (&vartype=N) and (&noobs > 15) and (&each ^= &eachdate) %then %do; 
		
		title1 "&each (&vartype) &noobs unique values" bold;
		*title2 "&vlabel";
		ods noproctitle;
		proc means data=&lib..&ds n nmiss median mean stddev range maxdec=2;
			var &each;
		run;
		title;
	%end;
	
	%else %if (&vartype=N) and (&noobs <= 15) and (&each ^= &eachdate) %then %do; 
		
		title1 "&each (&vartype) &noobs unique values" bold;
		*title2 "&vlabel";
		ods noproctitle;
		proc freq data=&lib..&ds;
			table &each / missing nocum nopercent;
		run;
		title;
	%end;
	
	%else %if (&vartype=C) and (&noobs <= 15) %then %do; 
		
		title1 "&each (&vartype) &noobs unique values" bold;
		*title2 "&vlabel";
		ods noproctitle;
		proc freq data=&lib..&ds;
			table &each / missing nocum nopercent;
		run;
		title;
	%end;

	%else %if (&vartype=C) and (&noobs > 15) %then %do; 
	
    proc odstext; 
        p "&each (&vartype) not tabulated; &noobs unique values" / style=[fontsize=11pt fontfamily=Arial]; 
    run;
    %end;
    
    %else %put flag variable &each;

	%end;
	

%mend codebookloop;

%codebookloop(lib=LIB, ds=RECALLS);

ods pdf close;
