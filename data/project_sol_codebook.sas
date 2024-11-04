*DM "log; *";

*********************************************************************
*  Assignment:    BIOS 669: Final Project                                      
*                                                                    
*  Description:   Codebook
*
*  Name:          Joyce Choe
*
*  Date:          4/30/2024                                   
*------------------------------------------------------------------- 
*  Job name:      project_sol_codebook.sas   
*
*  Purpose:       Produce a codebook that summarizes the characteristics  
*                 of variables in lib.recalls data set
*                                         
*  Language:      SAS, VERSION 9.4  
*
*  Input:         lib.recalls data set
*                 
*  Output:        RTF file     
*                                                                    
********************************************************************;

%LET job=project_codebook_sol;
%LET onyen=jyc85;
%LET outdir=/home/u63543840/BIOS669;

OPTIONS NODATE MPRINT MERGENOBY=WARN VARINITCHK=WARN;


options orientation=portrait;

ODS RTF FILE="&outdir/Output/&job._&onyen..RTF" BODYTITLE STYLE=normal;

ods rtf startpage=no;
 ODS NOPTITLE;

%let descwidth=4.0;
%let Nwidth=.5;
%let valwidth=.5;

%macro mycodebook;

    /***Order variables alphabetically to present an ordered codebook***/
        proc sql noprint;
            select name into :alphalist separated by ' '
                from dictionary.columns
                where libname='LIB' and memname='RECALLS'
                order by name;
        quit;


    %let i=1;
 
    %do %until (%scan(&alphalist,&i)= );
        
        %let var=%scan(&alphalist,&i);


        /***Create a single title at the top of the codebook***/

        %if &var=%scan(&alphalist,1) %then %do;
            title "A codebook for variables in the lib.recalls dataset";
        %end;
        %else %do; title; %end;


        /***Get variable type and label***/
        data _null_;

            dsid = open("lib.recalls");
            vtyp = vartype(dsid,varnum(dsid,"&var"));
            vlab = varlabel(dsid,varnum(dsid,"&var"));
            rc = close(dsid);
            
            length fulltype $9;
            if vtyp='N' and (index(upcase(vlab),'DATE'))>0 then fulltype='Date';
            if vtyp='N' and (index(upcase(vlab),'DATE'))=0 then fulltype='Numeric';
            if vtyp='C' then fulltype='Character';
            
            call symput("fulltyp",strip(fulltype));
            call symput("vlabl",strip(vlab));
        
        run;

        /***Procedure for DATE variables***/
        %if &fulltyp = Date %then %do;
            proc sql noprint;
            select count(&var), nmiss(&var), min(&var) format=date9., max(&var) format=date9.
                    INTO :N, :Nmiss, :Minimum, :Maximum 
                from lib.recalls;
            quit;
        
            
            proc report data=lib.recalls nowd style(header)={just=left};
                columns ("&var." count Value) ("&vlabl." Description);
                define count/computed "N" style={cellwidth=&Nwidth.in};
                define Value/computed style={cellwidth=&valwidth.in};
                define Description/computed 'Summary' style={cellwidth=&descwidth.in just=left};

                compute count;
                count= &N.;
                endcomp;

                compute Value/character length=17;
                Value= "Range";
                endcomp;

                compute Description/character length=50;
                Description= "&minimum. to &maximum. (Missing = %sysfunc(strip(&nmiss.)))";
                endcomp;
            run;
        
        %end;


        /***Procedure for other numeric variables apart from date variables***/
        %if &fulltyp = Numeric %then %do;

            proc sql noprint;
            select count(&var), count(distinct &var), nmiss(&var), min(&var), max(&var),mean(&var) format = 6.2
                    INTO :N, :distinctN, :Nmiss, :Minimum, :Maximum ,:average
                from lib.recalls;
            quit;
        
        %if &distinctN >= 15 %then %do;
        proc report data=lib.recalls nowd style(header)={just=left};
            columns ("&var." count Value) ("&vlabl." Description);
            define count/computed "N" style={cellwidth=&Nwidth.in};
            define Value/computed style={cellwidth=&valwidth.in};
            define Description/computed 'Summary' style={cellwidth=&descwidth.in just=left};

            compute count;
            count= &N.;
            endcomp;

            compute Value/character length=17;
            Value= "Range";
            endcomp;

            compute Description/character length=55;
            Description= "%sysfunc(strip(&minimum.)) - %sysfunc(strip(&maximum.)) (Mean = %sysfunc(strip(&average.)), Missing = %sysfunc(strip(&nmiss.)))";
            endcomp;
        run;

        %end;

        %else %if &distinctN < 15 %then %do;

        proc freq data = lib.recalls noprint;
        table &var/
            out = freq_&i;
        run;

        proc report data=freq_&i nowd style(header)={just=left} split="*";
            columns ("&var." count &var.) ("&vlabl." percent);
            define count/display "N" style={cellwidth=&Nwidth.in};
            define &var./display "Value" style={cellwidth=&valwidth.in};
            define percent/display "Percent of Total" style={cellwidth=&descwidth.in just=left} format=6.1;

        run;

        %end;
    
        %end;

        
        /***Procedure for character variables***/
        %if &fulltyp = Character %then %do; 
    
            proc sql noprint;
                select count(&var), nmiss(&var), count(distinct &var)
                        INTO :N, :Nmiss, :unique_var 
                    from lib.recalls;
            quit;


        /***Character variables with less unique values***/
        %if &unique_var <=15 %then %do;

            proc freq data = lib.recalls noprint;
                table &var/
                    out = freqout_&i;
            run;

            proc report data=freqout_&i nowd style(header)={just=left} split="*";
                columns ("&var." count &var.) ("&vlabl." percent);
                define count/display "N" style={cellwidth=&Nwidth.in};
                define &var./display "Value" style={cellwidth=&valwidth.in};
                define percent/display "Percent of Total" style={cellwidth=&descwidth.in just=left} format=6.1;

            run;
        
        %end;

        /***Character variables with several unique values***/
        %else %if &unique_var > 15 %then %do;

            proc report data = lib.recalls nowd style(header)={just=left};
                columns ("&var." count value) ("&vlabl." Description);
                define count/computed "N" style={cellwidth=&Nwidth.in};
                define value/computed "Value" style={cellwidth=&valwidth.in};
                define Description/computed 'Summary' style={cellwidth=&descwidth.in just=left};

                compute count;
                count= &N.;
                endcomp;

                compute value/character length=10;
                value= "ID's";
                endcomp;

                compute Description/character length=50;
                Description= "Unique values = %sysfunc(strip(&unique_var.)), Missing = %sysfunc(strip(&nmiss.))";
                endcomp;
            run;    
        %end; 

        %end;

        %let i=%eval(&i+1);
    %end;
        
    quit;
     

%mend;
%mycodebook;


ODS RTF CLOSE;

*DM 'log; *file "&outdir\&job._&onyen..log" replace';














