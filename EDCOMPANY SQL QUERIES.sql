use edcompany
select * from leads_basic_details
select * from leads_demo_watched_details
select * from leads_interaction_details
select * from leads_reasons_for_no_interest
select * from sales_managers_assigned_leads_details
-------------------------------------------------BUSSINESS TEAM QUERIES------------------------------------------
select distinct call_reason from leads_interaction_details

select count(distinct lead_id) as conversion_count from leads_interaction_details where call_status='successful' and call_reason='successful_conversion'


-----------------total correct conversion count-------------
select lead_stage, count(distinct lead_id) as lead_count from(
select lead_id,lead_stage, call_reason,
row_number() over (partition by lead_id order by call_done_date desc,
case when call_reason='successful_conversion' then 1
     when call_reason='interested_for_conversion' then 2
	 when call_reason='followup_for_conversion' then 3
	 when call_reason='followup_for_consideration' then 4
	 when call_reason='post_demo_followup'then 5
	 when call_reason='demo_not_attended' then 6 
	 when call_reason='demo_schedule' then 7
	 when call_reason='lead_introduction' then 8  else 0 end )as new , call_done_date from leads_interaction_details
where call_status='successful') as a
where new=1 and call_reason='successful_conversion'
group by lead_stage

-------------- Average call success rate by stage--

select lead_stage, count(distinct case when call_status='successful' then lead_id end)*100/count(distinct lead_id) as success_rate from
leads_interaction_details
group by lead_stage

----- Demo watched vs. not watched-------

select(
select count(lead_id)  from leads_basic_details
where lead_id not in(select lead_id from leads_demo_watched_details)) as demo_watched,

(select count(lead_id) as demo_watched from leads_basic_details
where lead_id in(select lead_id from leads_demo_watched_details)) as demo_not_watched

-------lead Drop-off rates at each stage------


select lead_stage, count(case when call_status='unsuccessful' then lead_id end)*100/count(distinct lead_id) as drop_off_rate
from leads_interaction_details
group by lead_stage
order by drop_off_rate desc


--language preference distribution----

select language,avg(watched_percentage) as avg_demo_watched_percentage from leads_demo_watched_details
group by language

----- lead volume by  sources channel ------

select count(distinct lead_id) as lead_count,lead_gen_source from leads_basic_details 
group by lead_gen_source
order by count(distinct lead_id) desc

--------conversion % by city--------

select a.current_city,coalesce(city_wise_cnt,0)*100/nullif(total_city_wise_cnt,0) as conversion_rate_in_Percentage from
(select current_city, count(distinct leads_basic_details.lead_id) as total_city_wise_cnt from leads_basic_details
group by current_city) a

left join 

(select current_city, count(distinct leads_basic_details.lead_id) as city_wise_cnt from leads_basic_details
join leads_interaction_details
on leads_basic_details.lead_id=leads_interaction_details.lead_id
where call_status='successful' and call_reason='successful_conversion'
group by current_city) b

on a.current_city=b.current_city
order by conversion_rate_in_Percentage desc

---Overall Common reasons for no interest

select count(*) as cnt, common_reasons  
from
(select reasons_for_not_interested_in_demo  as common_reasons  from leads_reasons_for_no_interest
union all
select reasons_for_not_interested_to_consider as common_reasons from leads_reasons_for_no_interest
union all 
select reasons_for_not_interested_to_convert as common_reasons from leads_reasons_for_no_interest) as a 
group by common_reasons

-----successful lead count of funnel stage-----
select lead_stage , count(distinct lead_id) as lead_count 
from(select lead_id,lead_stage, 
row_number() over (partition by lead_id order by call_done_date desc) as new , call_done_date from leads_interaction_details
where call_status='successful') as a 
where new=1
group by lead_stage

---------------------------------------------------BUSINESS LEADS---------------------------------------------------

-------senior manager team performance-----

select snr_sm_id,total_calls_made_by_juniors, final_converted_calls ,(final_converted_calls*100/total_calls_made_by_juniors) as Conversion_Percent_by_snr_managers from(
select a.snr_sm_id as snr_sm_id, sum(a.total_calls_made) as total_calls_made_by_juniors,sum(b.conv_call) as final_converted_calls from 
(select snr_sm_id,leads_interaction_details.jnr_sm_id,count(distinct leads_interaction_details.lead_id) as total_calls_made from leads_interaction_details
join sales_managers_assigned_leads_details
on leads_interaction_details.lead_id=sales_managers_assigned_leads_details.lead_id
group by leads_interaction_details.jnr_sm_id, snr_sm_id) a
 
left join 

(select snr_sm_id,leads_interaction_details.jnr_sm_id, count(distinct leads_interaction_details.lead_id) as conv_call 
from leads_interaction_details
join sales_managers_assigned_leads_details
on leads_interaction_details.lead_id=sales_managers_assigned_leads_details.lead_id
where call_status='successful' and call_reason='successful_conversion' group by leads_interaction_details.jnr_sm_id, snr_sm_id) b

on a.jnr_sm_id= b.jnr_sm_id
group by a.snr_sm_id) as new

-- Leads assigned vs converted (per cycle)

select lead_assign.cycle , lead_assigned,lead_converted from(
select cycle, count(distinct lead_id) as lead_assigned from sales_managers_assigned_leads_details
group by cycle) as lead_assign

left join


(select cycle,count(distinct leads_interaction_details .lead_id) as lead_converted from leads_interaction_details 
join sales_managers_assigned_leads_details
on leads_interaction_details.lead_id=sales_managers_assigned_leads_details.lead_id
where call_status='successful' and call_reason='successful_conversion'
group by cycle) as total_assign

on
lead_assign.cycle=total_assign.cycle

---- age group wise conversion count--


SELECT 
    age_data.age,
    ROUND(age_data.agewise_conversion_count * 100.0 / total_data.total_conversion_count, 2) AS Conversion_Percentage
FROM 
    (
        SELECT 
            lbd.age, 
            COUNT(DISTINCT lbd.lead_id) AS agewise_conversion_count
        FROM leads_basic_details lbd
        INNER JOIN leads_interaction_details lid 
            ON lbd.lead_id = lid.lead_id
        WHERE 
            lid.call_status = 'successful' AND 
            lid.call_reason = 'successful_conversion'
        GROUP BY lbd.age
    ) AS age_data
CROSS JOIN
    (
        SELECT 
            COUNT(DISTINCT lead_id) AS total_conversion_count
        FROM 
        (
            SELECT 
                lid.lead_id,
                ROW_NUMBER() OVER (
                    PARTITION BY lid.lead_id 
                    ORDER BY lid.call_done_date DESC,
                        CASE 
                            WHEN lid.call_reason = 'successful_conversion' THEN 1
                            WHEN lid.call_reason = 'interested_for_conversion' THEN 2
                            WHEN lid.call_reason = 'followup_for_conversion' THEN 3
                            WHEN lid.call_reason = 'followup_for_consideration' THEN 4
                            WHEN lid.call_reason = 'post_demo_followup' THEN 5
                            WHEN lid.call_reason = 'demo_not_attended' THEN 6
                            WHEN lid.call_reason = 'demo_schedule' THEN 7
                            WHEN lid.call_reason = 'lead_introduction' THEN 8
                            ELSE 9 
                        END
                ) AS new,
                lid.call_reason,
                lid.call_status
            FROM leads_interaction_details lid
            WHERE lid.call_status = 'successful'
        ) AS latest_calls
        WHERE latest_calls.new = 1 AND latest_calls.call_reason = 'successful_conversion'
    ) AS total_data;


	-------------------lead-aging analysis by each seniors----------------------
	
	select snr_sm_id , avg(junior_avg_aging_days) as Avg_Aging_Days from(
	select senior.snr_sm_id as snr_sm_id,junior.jnr_sm_id,junior.avg_aging_days as junior_avg_aging_days from
	(select snr_sm_id, jnr_sm_id from sales_managers_assigned_leads_details) senior
	
	join
	
	
	(select a.jnr_sm_id,avg(aging_days) as avg_aging_days from(
	select a.jnr_sm_id,a.lead_id, start_date, end_date, datediff(day, start_date, end_date) as aging_days from
	(select jnr_sm_id, lead_id, min(call_done_date) as start_date from leads_interaction_details
	where call_status='successful' and call_reason='lead_introduction'
	group by jnr_sm_id, lead_id) a
	
	inner join
	 
	(select jnr_sm_id, lead_id, max(call_done_date) as end_date from leads_interaction_details
	where call_status='successful' and call_reason='successful_conversion'
	group by jnr_sm_id, lead_id) b

	on a.lead_id=b.lead_id and a.jnr_sm_id = b.jnr_sm_id
	where start_date is not null and end_date is not null) as a
	where aging_days>0
	group by jnr_sm_id) junior
	
	on
	senior.jnr_sm_id = junior.jnr_sm_id) as final
	group by snr_sm_id


	-----------------------avg aging of each juniors--------------------------
	select a.jnr_sm_id,avg(aging_days) as avg_aging_days, dense_rank() over (order by avg(aging_days) asc) as rnk from(
	select a.jnr_sm_id,a.lead_id, start_date, end_date, datediff(day, start_date, end_date) as aging_days from
	(select jnr_sm_id, lead_id, min(call_done_date) as start_date from leads_interaction_details
	where call_status='successful' and call_reason='lead_introduction'
	group by jnr_sm_id, lead_id) a
	
	inner join
	 
	(select jnr_sm_id, lead_id, max(call_done_date) as end_date from leads_interaction_details
	where call_status='successful' and call_reason='successful_conversion'
	group by jnr_sm_id, lead_id) b

	on a.lead_id=b.lead_id and a.jnr_sm_id = b.jnr_sm_id
	where start_date is not null and end_date is not null) as a
	where aging_days>0
	group by jnr_sm_id

	-----best junior performer----

	select jnr_sm_id from(
	select a.jnr_sm_id,avg(aging_days) as avg_aging_days, dense_rank() over (order by avg(aging_days) asc) as rnk from(
	select a.jnr_sm_id,a.lead_id, start_date, end_date, datediff(day, start_date, end_date) as aging_days from
	(select jnr_sm_id, lead_id, min(call_done_date) as start_date from leads_interaction_details
	where call_status='successful' and call_reason='lead_introduction'
	group by jnr_sm_id, lead_id) a
	
	inner join
	 
	(select jnr_sm_id, lead_id, max(call_done_date) as end_date from leads_interaction_details
	where call_status='successful' and call_reason='successful_conversion'
	group by jnr_sm_id, lead_id) b

	on a.lead_id=b.lead_id and a.jnr_sm_id = b.jnr_sm_id
	where start_date is not null and end_date is not null) as a
	where aging_days>0
	group by jnr_sm_id) as final
	where rnk=1

	----------------------------------------------MANAGER'S-------------------------------------------

	--Team Score = (Conversion Rate %) / (Avg Aging Days)---

	select conversion_per.snr_sm_id,(Conversion_Percent_by_snr_managers/nullif(snr_aging.Avg_Aging_Days,0)) as Team_Score from

(select snr_sm_id,Conversion_Percent_by_snr_managers from(
select snr_sm_id,total_calls_made_by_juniors, final_converted_calls ,(final_converted_calls*100/total_calls_made_by_juniors) as Conversion_Percent_by_snr_managers from(
select a.snr_sm_id as snr_sm_id, sum(a.total_calls_made) as total_calls_made_by_juniors,sum(b.conv_call) as final_converted_calls from 
(select snr_sm_id,leads_interaction_details.jnr_sm_id,count(distinct leads_interaction_details.lead_id) as total_calls_made from leads_interaction_details
join sales_managers_assigned_leads_details
on leads_interaction_details.lead_id=sales_managers_assigned_leads_details.lead_id
group by leads_interaction_details.jnr_sm_id, snr_sm_id) a
 
left join 

(select snr_sm_id,leads_interaction_details.jnr_sm_id, count(distinct leads_interaction_details.lead_id) as conv_call 
from leads_interaction_details
join sales_managers_assigned_leads_details
on leads_interaction_details.lead_id=sales_managers_assigned_leads_details.lead_id
where call_status='successful' and call_reason='successful_conversion' group by leads_interaction_details.jnr_sm_id, snr_sm_id) b

on a.jnr_sm_id= b.jnr_sm_id
group by a.snr_sm_id) as new) as c) Conversion_per


join



(select snr_sm_id , avg(junior_avg_aging_days) as Avg_Aging_Days from(
	select senior.snr_sm_id as snr_sm_id,junior.jnr_sm_id,junior.avg_aging_days as junior_avg_aging_days from
	(select snr_sm_id, jnr_sm_id from sales_managers_assigned_leads_details) senior
	
	join
	
	
	(select a.jnr_sm_id,avg(aging_days) as avg_aging_days from(
	select a.jnr_sm_id,a.lead_id, start_date, end_date, datediff(day, start_date, end_date) as aging_days from
	(select jnr_sm_id, lead_id, min(call_done_date) as start_date from leads_interaction_details
	where call_status='successful' and call_reason='lead_introduction'
	group by jnr_sm_id, lead_id) a
	
	inner join
	 
	(select jnr_sm_id, lead_id, max(call_done_date) as end_date from leads_interaction_details
	where call_status='successful' and call_reason='successful_conversion'
	group by jnr_sm_id, lead_id) b

	on a.lead_id=b.lead_id and a.jnr_sm_id = b.jnr_sm_id
	where start_date is not null and end_date is not null) as a
	where aging_days>0
	group by jnr_sm_id) junior
	
	on
	senior.jnr_sm_id = junior.jnr_sm_id) as final
	group by snr_sm_id) snr_aging

	on
	conversion_per.snr_sm_id=snr_aging.snr_sm_id

	----------Team contribution breakdown---------

select snr_sm_id,round((a.team_wise_conv_count*100.0/nullif(b.conversion_count,0)),2) as conversion_percent_breakdown from
(select snr_sm_id, sum(conv_call) as team_wise_conv_count from( 
select snr_sm_id,leads_interaction_details.jnr_sm_id, count(distinct leads_interaction_details.lead_id) as conv_call 
from leads_interaction_details
join sales_managers_assigned_leads_details
on leads_interaction_details.lead_id=sales_managers_assigned_leads_details.lead_id
where call_status='successful' and call_reason='successful_conversion' group by leads_interaction_details.jnr_sm_id, snr_sm_id)as snr
group by snr_sm_id) a

cross join
(select count(distinct lead_id) as conversion_count 
from leads_interaction_details where call_status='successful' and call_reason='successful_conversion') b


----------lead distribution heatmap------------

select a. current_city,b.total_lead_cnt,a.conv_cnt,(a. conv_cnt*100/b.total_lead_cnt) as conv_percent from
(select current_city, count(distinct leads_basic_details.lead_id) as conv_cnt from leads_basic_details
join leads_interaction_details
on leads_basic_details.lead_id = leads_interaction_details.lead_id
where call_status='successful' and call_reason='successful_conversion'
group by current_city) a
 
 left join

(select current_city,count(distinct leads_basic_details.lead_id) as total_lead_cnt from leads_basic_details
group by current_city) b

on a.current_city=b.current_city

--------------Followup Effieciency------------------
--Avg. Follow-up Attempts before Conversion per Manager--


select snr_sm_id, sum(a.jnr_followup_calls) as follow_up_attempts_for_conversion from
(select jnr_sm_id, count(*) as jnr_followup_calls from leads_interaction_details
where call_status='successful' and lead_stage in('lead','awareness','consideration')
group by jnr_sm_id) a

join
(select distinct snr_sm_id,jnr_sm_id from sales_managers_assigned_leads_details) b

on a.jnr_sm_id = b. jnr_sm_id
group by snr_sm_id

----------------top 2 juniors for each senior of conversion----------------
select snr_sm_id,jnr_sm_id,conv_call,rnk from(
select snr_sm_id, jnr_sm_id, conv_call,
dense_rank() over (partition by snr_sm_id order by conv_call desc) as rnk from(
select snr_sm_id,leads_interaction_details.jnr_sm_id as jnr_sm_id, count(distinct leads_interaction_details.lead_id) as conv_call 
from leads_interaction_details
join sales_managers_assigned_leads_details
on leads_interaction_details.lead_id=sales_managers_assigned_leads_details.lead_id
where call_status='successful' and call_reason='successful_conversion' group by leads_interaction_details.jnr_sm_id, snr_sm_id) as a) as b
where rnk<=2

