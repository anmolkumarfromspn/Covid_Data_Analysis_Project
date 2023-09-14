use project;
select * from ts_delta_clean ;
select * from ts_total_clean ;
select * from ts_delta7_clean ;

#removing data of states which are not in Inida-
delete from ts_delta_clean where state='TT' or state='UN';
delete from ts_total_clean where state='TT' or state='UN';
delete from ts_delta7_clean where state='TT' or state='UN';

# drop a extra column vaccinated which is blank:
ALTER TABLE ts_delta_clean
DROP COLUMN vaccinated;

ALTER TABLE ts_total_clean
DROP COLUMN vaccinated;

ALTER TABLE ts_delta7_clean
DROP COLUMN vaccinated;

# daily_data_count_of_country:
with cte1 as(select date,sum(confirmed) as daily_confirmed,sum(deceased) as daily_deceased,
sum(recovered) as daily_recovered,sum(tested) as daily_tested, 
sum(vaccinated1)daily_vaccinated1,sum(vaccinated2)daily_vaccinated2
from ts_delta_clean group by date order by date),

# total_data_count_of_country:
cte2 as(select date,sum(confirmed) as total_confirmed,sum(deceased) as total_deceased,
sum(recovered) as total_recovered,sum(tested) as total_tested, 
sum(vaccinated1)total_vaccinated1,sum(vaccinated2)total_vaccinated2
from ts_total_clean group by date order by date)

#joining these 2 table to on the basis of date(country_data_daily_basis):
select * from cte1 join cte2 on cte1.date=cte2.date ;

#Weekly evolution of number of confirmed cases, recovered cases, deaths, tests.
#your dashboard should be able to compare Week 3 of May with Week 2 of August 

with cte1 as(select date,year(date) as yr,monthname(date) as mnth,
case when day(date)<=7 then 1 when day(date) between 8 and 14 then 2 
when day(date) between 15 and 21 then 3 when day(date) between 22 and 28 then 4
else 5 end as weeknumber ,
sum(confirmed) as daily_confirmed,sum(deceased) as daily_deceased,
sum(recovered) as daily_recovered,sum(tested) as daily_tested
from ts_delta_clean group by yr,mnth,date order by date)

select yr,mnth,weeknumber,sum(daily_confirmed) as confirmed,sum(daily_deceased)deceased,sum(daily_recovered)recovered,
sum(daily_tested)tested  from cte1 group by yr,mnth,weeknumber ;


# state_wise_timeseries :
with cte1 as (select state,year(date) as yr,monthname(date) as mnth,
sum(confirmed) daily_confirmed ,sum(recovered) daily_recovered,
sum(tested) as daily_tested,sum(deceased) as daily_deceased,
sum(vaccinated1) as daily_vaccinated1,sum(vaccinated2) as daily_vaccinated2
from ts_delta_clean group by state,yr,mnth),
cte2 as(select state,year(date) as yr,monthname(date) as mnth,
max(confirmed) total_confirmed ,max(recovered) total_recovered,
max(tested) as total_tested,max(deceased) as total_deceased,
max(vaccinated1) as total_vaccinated1,max(vaccinated2) as total_vaccinated2
from ts_total_clean group by state,yr,mnth)

#joining these 2 data :
select * from cte1 join cte2 on cte1.state=cte2.state and cte1.yr=cte2.yr and
cte1.mnth=cte2.mnth;


#Categorise total number of confirmed cases in a state by Months and come 
#up with that one month which was worst for India in terms of number of cases

select state,year(date) as yr,monthname(date) as mnth,
sum(confirmed) total_confirmed
from ts_delta_clean 
group by 1,2,3;

#seven_day_moving_average_data_country:
select * from ts_delta7_clean ;

with cte1 as(select date,sum(confirmed) as daily_new_cases,sum(deceased) as daily_new_death,
sum(recovered) as daily_new_recovered
from ts_delta7_clean group by date order by date)

select date,avg(daily_new_cases) over (order by date rows between 6 preceding and current row) as seven_day_moving_average_confirmed,
avg(daily_new_death) over (order by date rows between 6 preceding and current row) as seven_day_moving_average_death,
avg(daily_new_recovered) over (order by date rows between 6 preceding and current row) as seven_day_moving_average_recovered
from cte1;

#state_level_analysis:
select * from df_delta_statewise_clean;
select * from df_delta7_statewise_clean;
select * from df_total_statewise_cleaned;
select * from df_meta_statewise_clean;

# dropping a unknown state 'TT' :
delete from df_delta_statewise_clean where MyUnknownColumn='TT';
delete from df_delta7_statewise_clean where MyUnknownColumn='TT';
delete from df_total_statewise_cleaned where state='TT';
delete from df_meta_statewise_clean where MyUnknownColumn='TT';

#changing column name:
ALTER TABLE df_delta_statewise_clean
RENAME COLUMN MyUnknownColumn to state;

ALTER TABLE df_delta7_statewise_clean
RENAME COLUMN MyUnknownColumn to state;

ALTER TABLE df_total_statewise_cleaned
RENAME COLUMN MyUnknownColumn to state;

ALTER TABLE df_meta_statewise_clean
RENAME COLUMN MyUnknownColumn to state;

# last_date= 31/10/2021 
# combining meta and total table to analyse vaccination drive:

select t.state,population,vaccinated1,vaccinated2,
((vaccinated1/population)*100) as percent_of_dose1,
((vaccinated2/population)*100) as percent_of_dose2
from df_total_statewise_cleaned t join 
df_meta_statewise_clean m on t.state=m.state;

#district_level_analysis:

#categorise every district on testing ratio:

DROP VIEW IF EXISTS district_category_tr_data;
CREATE VIEW district_category_tr_data AS
SELECT *,
  CASE
    WHEN Testing_Ratio <= 0.1 THEN 'CATEGORY A'
    WHEN Testing_Ratio > 0.1 AND Testing_Ratio <= 0.3 THEN 'CATEGORY B'
    WHEN Testing_Ratio > 0.3 AND Testing_Ratio <= 0.5 THEN 'CATEGORY C'
    WHEN Testing_Ratio > 0.5 AND Testing_Ratio <= 0.75 THEN 'CATEGORY D'
    WHEN Testing_Ratio > 0.75 THEN 'CATEGORY E'
  END AS Category_tr
FROM (
  SELECT state, district, tested, population, deceased,
  (tested / population) AS Testing_Ratio
  FROM districts_final
) AS X
Order by state;

#death analysis for each category:

WITH CTE AS(
SELECT district,population,Category_tr,SUM(deceased) AS deaths, 
SUM(population) AS popl
FROM district_category_tr_data
GROUP BY district,population,Category_tr
ORDER BY Category_tr)
SELECT Category_tr,COUNT(Category_tr) as Category_wise_count,
Sum(deaths) AS total_deaths,
ROUND((SUM(deaths) / SUM(popl)) * 100, 4) AS death_percentage
FROM CTE
Group by category_tr;

