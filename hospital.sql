#--Q1. For each doctor, count how many distinct patients they have treated.
select count(distinct pv.patientid) as count, 
        d.DoctorID,
	   concat(d.firstname," ",d.lastname) as fulldocname
from patientvisits pv
join dim_doctor d on pv.doctorid=d.doctorid
join dim_patient_clean pc on pc.patientid=pv.patientid 
group by doctorid, fulldocname
order by count desc;

#--Q2. Show the revenue split by each payment method, along with total visits.
select sum(pv.billamount) as revenue,
	   count(pv.VisitID) as totalpatients,
	   pm.paymentmethod as paymentmethod
from patientvisits pv 
join dim_paymentmethod pm on pm.paymentmethodid=pv.PaymentMethodID
group by paymentmethod;


#--Q3. Categorize patients into age groups and calculate the average bill amount for each age band.(Assume age at time of visit based on VisitDate.)
with patientsage as (
	select pv.visitid,
    pc.patientid,
    pv.billamount as revenue,
	case 
		WHEN TIMESTAMPDIFF(YEAR, pc.dob, pv.visitdate) <5 then 'toddler'
        WHEN TIMESTAMPDIFF(YEAR, pc.dob, pv.visitdate) BETWEEN 5 AND 12 THEN 'kid'
        WHEN TIMESTAMPDIFF(YEAR, pc.dob, pv.visitdate) BETWEEN 13 AND 19 THEN 'teenager'
        WHEN TIMESTAMPDIFF(YEAR, pc.dob, pv.visitdate) BETWEEN 20 AND 55 THEN 'adult'
        else 'elderly'
        end as agecategory
	from dim_patient_clean pc
    join patientvisits pv on pc.patientid=pv.patientid)
    
    select cast(avg(revenue) as decimal(18,2)) as averagerevenue,
			agecategory
			from patientsage 
	group by agecategory;
    
#--Q4. Find total revenue and number of visits for each department.
select sum(pv.billamount) as revenue,
		count(pv.visitid) as totalvisit,
        d.departmentname as dname
        from patientvisits pv 
        join dim_department_clean d on d.departmentid=pv.departmentid
        group by dname;
        
#--Q5. Rank departments based on their total revenue within each department category.

select *,
		rank() over (partition by dcategory  order by revenue desc)
from (
	select cast(sum(billamount) as decimal(18,2)) as revenue,
			d.departmentname as dname,
			d.DepartmentCategory as dcategory
	from patientvisits pv 
	join dim_department_clean d on d.departmentid=pv.departmentid
	group by dname,dcategory
    ) m;
    
#--Q6. For each department, find the average satisfaction score and average wait time.
select d.DepartmentName as dname,
	   cast(avg(pv.SatisfactionScore) as decimal(10,2)) as avgscore,
       cast(avg(WaitTimeMinutes) as decimal (10,2)) as avgwaittime
from patientvisits pv 
join dim_department_clean d on d.departmentid=pv.departmentid
group by dname
ORDER BY avgscore desc;

#--Q7. Compare the total number of hospital visits on weekdays vs weekends.
select count(visitid) as totalvisits, 
		weekdays
from (select visitid, 
			case 
				when date_format(visitdate, '%W') in ('Sunday', 'Saturday') then 'weekend'
				else "weekday"
                end as "weekdays"
			from patientvisits
		) m
group by weekdays;                


#--Q8. For each month, calculate total visits and a running cumulative total of vis
select visitmonth,
	totalvisits, 
	sum(totalvisits) over (order by visitmonth) as runningvisits
from (
	select 
			count(visitid) as totalvisits, 
		    date_format(visitdate, '%Y-%m') as visitmonth
	from patientvisits
	group by visitmonth) m;
    
#--Q9. Find the doctors with the highest average satisfaction score (minimum 100 visits).
select count(pv.visitid) as totaldocvisits, 
		d.doctorid,
        avg(pv.satisfactionscore) as avgg ,
        concat(d.firstname, ' ', d.lastname) as 'fullname'
from patientvisits pv
join dim_doctor d on d.doctorid=pv.DoctorID
group by doctorid
having totaldocvisits>=100
order by avgg desc;

#-Q10. Identify the most commonly prescribed treatment for each diagnosis.
with cte_rank as (
	select totaldio,
			treat,
			dia,
			rank() over (partition by dia order by totaldio desc) as rankk
	from (
		select count(dd.DiagnosisID) as totaldio,
				dt.Treatmentname as treat, 
				dd.Diagnosisname as dia
		from patientvisits pv
		join dim_diagnosis dd on dd.diagnosisid=pv.diagnosisid
		join dim_treatment dt on dt.TreatmentID=pv.TreatmentID
		group by treat, dia
		)m)

select totaldio,
		treat,
		dia
from cte_rank
where rankk=1;
        



