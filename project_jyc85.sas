%LET job=project;
%LET onyen=jyc85;
%LET outdir=/home/u63543840/BIOS669;

*proc printto log="&outdir/Logs/&job._&onyen..log" new;* run; 

*********************************************************************
*  Assignment:    BIOS 669: Final Project                 
*                                                                    
*  Description:   Recalled food products (June 2012 - April 2024) 
*				  with terminated status from open FDA report
*
*  Name:          Joyce Choe
*
*  Date:          4/30/2024                                
*------------------------------------------------------------------- 
*  Job name:      project_jyc85.sas   
*
*  Purpose:       Exploratory Data Analysis
*				       
*  Language:      SAS, VERSION 9.4  
*
*  Input:         API, look-up info.
*
*  Output:        PDF file, data sets
*                                                                    
********************************************************************;
OPTIONS nodate mergenoby=warn varinitchk=warn nofullstimer mprint;
FOOTNOTE "Job &job._&onyen run on &sysdate at &systime";
LIBNAME lib "&outdir/Data";

ODS PDF FILE="&outdir/Output/&job._&onyen..PDF" startpage=no;

* API data by yearly intervals (6/2012 to 4/2024);
%MACRO recall(n=, dates=);

filename recall&n temp;

/*https://api.fda.gov/food/enforcement.json?&search=status:%22Terminated%22+AND+distribution_pattern:(*nc*+OR+*North*Carolina*+OR+*nation*+OR+*domestic)*
+AND+recall_initiation_date:[20120601+TO+20130601]&sort=recall_initiation_date:asc&limit=1000*/
proc http
	url="%nrstr(https://api.fda.gov/food/enforcement.json?&search=status:%22Terminated%22
	+AND+distribution_pattern:(*nc*+OR+*North*Carolina*+OR+*nation*+OR+*domestic*)+AND+recall_initiation_date:[)&dates%nrstr(]&sort=recall_initiation_date:asc&limit=1000)"
	method="GET"
	out=recall&n;
run;

/*save in Libraries > My Libraries > food&n */
libname food&n JSON fileref=recall&n; 

* Add a column for data set name;
proc sql; 
	create table food&n(drop=ordinal_root ordinal_results address_1 address_2 postal_code city code_info more_code_info report_date) as
	select *, "food&n" as ds
	from food&n..results;
quit;

%MEND;

/*include all observations after June 2012 without gap between dates that are not past limit=1000 */
%recall(n=1, dates=20120601+TO+20130601); 
%recall(n=2, dates=20130601+TO+20131231);
%recall(n=3, dates=20140101+TO+20140601);
%recall(n=4, dates=20140601+TO+20141231);
%recall(n=5, dates=20150101+TO+20150601);
%recall(n=6, dates=20150601+TO+20151231);
%recall(n=7, dates=20160101+TO+20160601);
%recall(n=8, dates=20160601+TO+20161231);
%recall(n=9, dates=20170101+TO+20170601);
%recall(n=10, dates=20170601+TO+20171231);
%recall(n=11, dates=20180101+TO+20181231);
%recall(n=12, dates=20190101+TO+20191231);
%recall(n=13, dates=20200101+TO+20201231);
%recall(n=14, dates=20210101+TO+20211231);
%recall(n=15, dates=20220101+TO+20221231);
%recall(n=16, dates=20230101+TO+20241231);

* Combine all data sets and adjust length of var so that none have truncated warning;
data combineall(drop=ds) missing;
	length ds $20 reason_for_recall $2000 product_quantity $500 distribution_pattern $2000 
	state $100  country $100 product_description $5000 recalling_firm $300;
	
	set food: ;
	
	* edits: new variable for year;
	date1year=substr(recall_initiation_date,1,4);
	
	*change to numeric SAS date type;
	date1=input(recall_initiation_date, yymmdd8.);
	date4=input(termination_date, yymmdd8.);
	
	*format to readable dates;
	format date1 date4 date9.;
	
	*correct variable so that Voluntary: Firm initiated = Voluntary: Firm Initiated;
	if voluntary_mandated NE propcase(voluntary_mandated) then 
	voluntary_mandated = propcase(voluntary_mandated);
	
	/* no missing values (and);
	where ^missing(reason_for_recall) and ^missing(distribution_pattern) and ^missing(state)
	and ^missing(country) and ^missing(classification) and ^missing(event_id) 
	and ^missing(voluntary_mandated) and ^missing(status) and ^missing(recall_initiation_date)
	and ^missing(termination_date) and ^missing(initial_firm_notification);*/
	
	* count number of missing rows;
	count_missing = cmiss(reason_for_recall, distribution_pattern, state,
	country, classification, event_id, voluntary_mandated, status, recall_initiation_date, 
	termination_date, initial_firm_notification);
 
 	* keep only non-missing dataset;
 	if count_missing>0 then output missing;
 	else output combineall;
 	
 	* drop count_missing;
 	drop count_missing;
run;

* Subset to unique recall events data set(n=1961 as of 8/20/2024);
proc sort data=combineall nodupkey out=recallevents;
	by event_id;
run;

*** Check intermediate date1 variable- rechecked in codebook;
ods startpage=now;
title 'Check intermediate date1 variable';
proc tabulate data=recallevents;
	var date1;
	table date1,
	n nmiss (min max median)*f=date9. range;
run;
title;

*** Check intermediate date4 variable;
ods startpage=now;
title 'Check intermediate date4 variable';
proc tabulate data=recallevents;
	var date4;
	table date4,
	n nmiss (min max median)*f=date9. range;
run;
title;

*** Check intermediate voluntary_mandated variable;
ods startpage=now;
title 'Check intermediate voluntary_mandated unique';
proc freq data=recallevents;
	table voluntary_mandated / missing;
run;
title;


* Categorize firm location to regional USDA food center;
proc sql;
create table rfbc_states as
	select *,
	case 
		when state in ('NM','TX') then 'Rio Grande Colonias'
		when state in ('AK','HI','PR') then 'Islands & Remote Areas'
		when state in ('ND','SD','MN') then 'North Central'
		when state in ('CA','NV','AZ','UT') then 'Southwest'
		when state in ('WI','IL','IN','MI') then 'Great Lakes Midwest'
		when state in ('AR','LA','MS','AL') then 'Delta'
		when state in ('TN','KY','WV','OH') then 'Appalachia'
		when state in ('NE','KS','OK','MO','IA') then 'Heartland'
		when state in ('VA','NC','SC','GA','FL') then 'Southeast'
		when state in ('WA','OR','ID','MT','WY','CO') then 'Northwest & Rocky Mountain'
		when state in ('MD','DE','PA','NJ','NY','CT','RI','MA','NH','VT','ME') then 'Northeast'
		else 'International'
	end as usda_region
	from recallevents
	where ^missing(state)
	order by usda_region;
quit;

*** Check intermediate usda_region variable;
ods startpage=now;
title 'Check intermediate usda_region variable';
proc freq data=rfbc_states order=freq;
	table usda_region / missing list nocum nopercent;
	table usda_region*state / missing list nocum nopercent;
run;
title;


* Calculate number of days between non-missing recall initiation and termination dates; 
data datdiff;
	set rfbc_states;
	if ^missing(date1) and ^missing(date4) then do;
	days = intck('day', date1, date4);
	end;
run;

*** Check intermediate days variable;
ods startpage=now;
ods exclude Moments;
title 'Check intermediate days variable';
proc univariate data=datdiff;
	var days;
run; 
title;

* Categorize reason_for_recall;
data reasons;
	set datdiff;
	length general_reason $30;
	if ^missing(reason_for_recall) then do;
	if prxmatch("/may|potential|...caution|risk|possible/i", reason_for_recall) > 0 then general_reason = "Precaution";
	else if prxmatch("/sanita|wash|uncook|raw|gmp|pasteur|process|prepared/i", reason_for_recall) > 0 then general_reason = "Unprepared";
	else if prxmatch("/lister|mon(ella|o)|hep\s|bacter|coli|spora|mold|yeast|bacillu|staph|pseudom|botu|pathog/i", reason_for_recall) > 0 then general_reason = "Microbe";
	else if prxmatch("/declare|allerg|gluten|label|content|statement|list(ed|s|ing)/i", reason_for_recall) > 0 then general_reason = "Mislabelled";
	else if prxmatch("/foreign|material|rock|object|metal|glass|plastic|fragment|icide|lead|arsenic|nsect/i", reason_for_recall) > 0 then general_reason = "Contaminant";
	else general_reason = "Other";
	end;
run;

*** Check intermediate general_reason variable;
ods startpage=now;
title 'Check intermediate general_reason variable';
proc freq data=reasons order=freq;
	table general_reason / missing list;
run;
title;

* Final analysis data set= lib.recalls (n=1886);
data lib.recalls;
	set reasons;
	
	* labels for each variable;
	label reason_for_recall	= 'original reason' 
	 	  product_quantity = 'amount of food product'
	 	  distribution_pattern = 'places in the U.S. where distributed'
	 	  state = 'state of firm location'
	 	  country = 'country of firm location'
	 	  product_description = 'description of food product'
	 	  recalling_firm = 'name of food firm'
	 	  center_classification_date = 'date when recalled food product was classified'
	 	  classification = 'relative degree of health hazard assigned by FDA: I (adverse), II (less adverse), III (unlikely adverse)'
	 	  date1year = 'year of recall initation date'
	 	  days = 'number of days between initiation to termination dates'
	 	  recall_number = 'alphanumeric tracking number assigned by FDA  to a specific recalled product'
	 	  initial_firm_notification = 'method by which public were initially notified of recall'
	 	  product_type = 'type of recalled product'
	 	  event_id = 'numerical tracking number assigned by FDA to a specific recall event'
	 	  termination_date = 'date when recalled food product is terminated'
	 	  recall_initiation_date= 'date when recalled food product is first notified to public or consignees of a recall'
	 	  voluntary_mandated = 'status of whether recall was initated voluntarily by a firm or after being mandated by statutory recall authority, court order, or FDA'
		  status = 'progress of recall'
		  date1 = 'recall_initiation_date' /*SAS numeric*/
		  date4 = 'recall_termination_date' /*SAS numeric*/
		  usda_region = 'food business center region of firm'
		  general_reason = 'general reason for recall';	 
		  
	* shorthand variable levels;
	if initial_firm_notification = 'Two or more of the following: Email, Fax, Letter, Press Release, Telephone, Visit'
	then initial_firm_notification = 'Two or more';
	else initial_firm_notification = initial_firm_notification;
run;

ods startpage=now;
ods exclude EngineHost;
title 'Contents of analysis data set: lib:recalls';
proc contents data=lib.recalls;
run;

*******************************************************;
*display plots;

* number of recalls per year;
proc freq data=lib.recalls noprint;
	table date1year/ out=freqcountdate;
run;
proc sort data=freqcountdate;
	by date1year;
run;

ods startpage=now;
title 'Summary statistics of number of recalls per year';
proc means data=freqcountdate;
	*by date1year;
	var count;
run;
title;
	
* output freqcount data set;
proc freq data=lib.recalls noprint;
	table date1year*usda_region/ out=freqcount;
run;

* series plot, recalls by firm region per year;
ods startpage=now;
title 'Number of recalls each year by region';
proc sgplot data=freqcount;
	series x=date1year y=count / group=usda_region markers markerattrs=(size=5pt);
	label count='Number of recalls';
	label date1year = 'Year';
	label usda_region = 'Region';
	yaxis grid values=(0 to 55 by 5);
footnote1;
footnote2 justify=left 'The year 2012 begins from June 1, 2012 so does not represent a full year.';
footnote3 justify=left 'The year 2024 includes up to present day April 30, 2024.';
run;

* stacked plot, recalls by firm region per year;
proc sgplot data=freqcount;
	vbar date1year / response=count group=usda_region;
	label count='Number of recalls';
	label date1year = 'Year';
	label usda_region = 'Region';
run;
title;
footnote;

* sort by decreasing median then plot boxplots;
%macro sortboxplot(var=, topic=, label=);

* sort &topic by decreasing median;
proc sql;
create table sort_&topic as 
select *, median(days) as med_&topic
	from lib.recalls
    group by &var
    order by med_&topic descending;
quit;

* boxplot of days by &var;
title "Number of days to process recall by &topic";
proc sgplot data=sort_&topic;
	vbox days / category=&var displaystats=(n median);
	yaxis grid;
	xaxis discreteorder=data;
	label days='Number of days';
	label &var ="&label";
run;
title;

%mend sortboxplot;

%sortboxplot(var=voluntary_mandated, topic=status, label=Voluntary status);
%sortboxplot(var=usda_region, topic=region, label=Firm Region);
%sortboxplot(var=general_reason, topic=reason, label=Reason for recall);
%sortboxplot(var=initial_firm_notification, topic=notification, label=Firm notification method);
%sortboxplot(var=classification, topic=classification, label=Health Hazard class);
%sortboxplot(var=date1year, topic=year, label=year);


****************************************************;
* statistical test - Kruskal Wallis;

ods startpage=now;
%macro kwallis (cat=, label=);

ods output KruskalWallisTest=test&cat;
ods select KruskalWallisTest;

ods pdf text = "Non-parametric test of days processed to completion by &label";
proc npar1way data = lib.recalls;
  class &cat;
  var days;
run;
ods output close;

data _null_;
	set test&cat;
	putlog "&cat p-value:";
	put prob;
run;

%mend;

%kwallis(cat=voluntary_mandated, label=status);
%kwallis(cat=usda_region, label=region);
%kwallis(cat=general_reason, label=general reason);
%kwallis(cat=initial_firm_notification, label=notification method);
%kwallis(cat=classification, label=health hazard class);
%kwallis(cat=date1year, label=year);

* Hypothesis tests: 

* H0: voluntary_mandated status (2 levels) medians are equal;
* Ha: at least one median is different;
* conclusion: fail to reject H0;

* H0: usda_region (12 levels) medians are equal;
* Ha: at least one median is different;
* conclusion: reject H0;

* H0: general_reason (6 levels) medians are equal;
* Ha: at least one median is different;
* conclusion: fail to reject H0;

* H0: initial_firm_notification (8 levels) medians are equal;
* Ha: at least one median is different;
* conclusion: fail to reject H0;

* H0: classification (3 levels) medians are equal;
* Ha: at least one median is different;
* conclusion: fail to reject H0;

* H0: year (13 levels) medians are equal;
* Ha: at least one median is different;
* conclusion: reject H0;


**********************************************;

ods pdf close;

*proc printto; *run; 