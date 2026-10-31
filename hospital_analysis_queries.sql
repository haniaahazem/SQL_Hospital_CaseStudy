#--Q1. FOR EACH doctor, COUNT how many DISTINCT patients they have treated.
SELECT count(DISTINCT pv.patientid) AS COUNT,
       d.DoctorID,
       concat(d.firstname, " ", d.lastname) AS fulldocname
FROM patientvisits pv
JOIN dim_doctor d ON pv.doctorid=d.doctorid
JOIN dim_patient_clean pc ON pc.patientid=pv.patientid
GROUP BY doctorid,
         fulldocname
ORDER BY COUNT DESC;

#--Q2. SHOW the revenue SPLIT BY EACH payment METHOD, along WITH total visits.
SELECT sum(pv.billamount) AS revenue,
       count(pv.VisitID) AS totalpatients,
       pm.paymentmethod AS paymentmethod
FROM patientvisits pv
JOIN dim_paymentmethod pm ON pm.paymentmethodid=pv.PaymentMethodID
GROUP BY paymentmethod;

#--Q3. Categorize patients INTO age groups AND calculate the average bill amount FOR EACH age band.(Assume age AT TIME OF visit based ON VisitDate.) 
WITH patientsage AS
  (SELECT pv.visitid,
          pc.patientid,
          pv.billamount AS revenue,
          CASE
              WHEN TIMESTAMPDIFF(YEAR, pc.dob, pv.visitdate) <5 THEN 'toddler'
              WHEN TIMESTAMPDIFF(YEAR, pc.dob, pv.visitdate) BETWEEN 5 AND 12 THEN 'kid'
              WHEN TIMESTAMPDIFF(YEAR, pc.dob, pv.visitdate) BETWEEN 13 AND 19 THEN 'teenager'
              WHEN TIMESTAMPDIFF(YEAR, pc.dob, pv.visitdate) BETWEEN 20 AND 55 THEN 'adult'
              ELSE 'elderly'
          END AS agecategory
   FROM dim_patient_clean pc
   JOIN patientvisits pv ON pc.patientid=pv.patientid)
SELECT cast(avg(revenue) AS decimal(18, 2)) AS averagerevenue,
       agecategory
FROM patientsage
GROUP BY agecategory;

#--Q4. Find total revenue AND number OF visits FOR EACH department.
SELECT sum(pv.billamount) AS revenue,
       count(pv.visitid) AS totalvisit,
       d.departmentname AS dname
FROM patientvisits pv
JOIN dim_department_clean d ON d.departmentid=pv.departmentid
GROUP BY dname;

#--Q5. Rank departments based ON their total revenue within EACH department category.
SELECT *,
       rank() OVER (PARTITION BY dcategory
                    ORDER BY revenue DESC)
FROM
  (SELECT cast(sum(billamount) AS decimal(18, 2)) AS revenue,
          d.departmentname AS dname,
          d.DepartmentCategory AS dcategory
   FROM patientvisits pv
   JOIN dim_department_clean d ON d.departmentid=pv.departmentid
   GROUP BY dname,
            dcategory) m;

#--Q6. FOR EACH department, find the average satisfaction score AND average wait time.
SELECT d.DepartmentName AS dname,
       cast(avg(pv.SatisfactionScore) AS decimal(10, 2)) AS avgscore,
       cast(avg(WaitTimeMinutes) AS decimal (10, 2)) AS avgwaittime
FROM patientvisits pv
JOIN dim_department_clean d ON d.departmentid=pv.departmentid
GROUP BY dname
ORDER BY avgscore DESC;

#--Q7. Compare the total number OF hospital visits ON weekdays vs weekends.
SELECT count(visitid) AS totalvisits,
       weekdays
FROM
  (SELECT visitid,
          CASE
              WHEN date_format(visitdate, '%W') IN ('Sunday',
                                                    'Saturday') THEN 'weekend'
              ELSE "weekday"
          END AS "weekdays"
   FROM patientvisits) m
GROUP BY weekdays;

#--Q8. FOR EACH MONTH, calculate total visits AND a running cumulative total OF vis
SELECT visitmonth,
       totalvisits,
       sum(totalvisits) OVER (
                              ORDER BY visitmonth) AS runningvisits
FROM
  (SELECT count(visitid) AS totalvisits,
          date_format(visitdate, '%Y-%m') AS visitmonth
   FROM patientvisits
   GROUP BY visitmonth) m;

#--Q9. Find the doctors WITH the highest average satisfaction score (minimum 100 visits).
SELECT count(pv.visitid) AS totaldocvisits,
       d.doctorid,
       avg(pv.satisfactionscore) AS avgg,
       concat(d.firstname, ' ', d.lastname) AS 'fullname'
FROM patientvisits pv
JOIN dim_doctor d ON d.doctorid=pv.DoctorID
GROUP BY doctorid
HAVING totaldocvisits>=100
ORDER BY avgg DESC;

#--Q10. Identify the most commonly prescribed treatment for each diagnosis.
with cte_rank as (
	select totaldiagnosis,
			treatment,
			diagnosis,
			rank() over (partition by diagnosis order by totaldiagnosis desc) as rankk
	from (
		select count(dd.DiagnosisID) as totaldiagnosis,
				dt.Treatmentname as treatment, 
				dd.Diagnosisname as diagnosis
		from patientvisits pv
		join dim_diagnosis dd on dd.diagnosisid=pv.diagnosisid
		join dim_treatment dt on dt.TreatmentID=pv.TreatmentID
		group by treatment, diagnosis
		)m)

select totaldiagnosis,
		treatment,
		diagnosis
from cte_rank
where rankk=1;

#--Q11: For each doctor, show their monthly revenue and a 3-month moving average
SELECT *,
       avg(revenuebydoc) OVER (PARTITION BY docid
                               ORDER BY MONTH ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS 3monthmovingavg
FROM
  (SELECT d.doctorid AS docid,
          concat(d.firstname, " ", d.lastname) AS fulldocname,
          DATE_FORMAT(pv.visitdate, '%Y-%m') AS MONTH,
          sum(billamount-InsuranceAmount) AS revenuebydoc
   FROM patientvisits pv
   JOIN dim_doctor d ON d.doctorid=pv.DoctorID
   GROUP BY docid,
            fulldocname,
            MONTH
   ORDER BY MONTH) m;

#--Q12: Rank patients by total spending, show top 5 spenders per city
WITH cte_cityrank AS
  (SELECT *,
          rank() OVER (PARTITION BY city
                       ORDER BY spending DESC) AS cityrank
   FROM
     (SELECT sum(pv.billamount-pv.insuranceamount) AS spending,
             pv.PatientID AS patientid,
             p.city AS city
      FROM patientvisits pv
      JOIN dim_patient_clean p ON p.PatientID=pv.PatientID
      GROUP BY PatientID,
               city)m)
SELECT *
FROM cte_cityrank
WHERE cityrank<=5;

#--Q13: For each department, show each month’s visits and the difference from the previous month
SELECT *,
       sum(totalvisits) OVER (PARTITION BY departmentid
                              ORDER BY MONTH) AS runningsum,
       totalvisits - lag (totalvisits) over(PARTITION BY departmentid
                                            ORDER BY MONTH) AS diff
FROM
  (SELECT DATE_FORMAT(visitdate, '%Y-%m') AS MONTH,
          count(visitid) AS totalvisits,
          departmentid
   FROM patientvisits
   GROUP BY MONTH,
            departmentid
   ORDER BY MONTH,
            departmentid)m;

#--Q14: Show each doctor’s contribution to total revenue as a percentage of overall revenue
SELECT CAST((SUM(pv.billamount - pv.insuranceamount) /
               (SELECT SUM(billamount - insuranceamount)
                FROM patientvisits)) * 100 AS DECIMAL (10, 2)) AS revenuepercentage,
       d.doctorid AS id,
       concat(d.firstname, " ", d.lastname) AS fulldocname
FROM patientvisits pv
JOIN dim_doctor d ON d.DoctorID=pv.DoctorID
GROUP BY id,
         fulldocname;

#Q--15: Find patients who visited more than one department
SELECT COUNT(DISTINCT pv.DepartmentID) AS countdep,
       pv.patientid,
       p.fullname
FROM patientvisits pv
JOIN dim_patient_clean p ON p.PatientID=pv.PatientID
GROUP BY PatientID,
         p.fullname
HAVING countdep > 1
ORDER BY countdep DESC;

#--Q16: List patients who were treated by the same doctor more than 2 times
SELECT count(d.doctorid) AS countdoc,
       d.doctorid,
       p.patientid,
       concat(d.firstname, " ", d.lastname) AS fulldocname,
       p.fullname
FROM patientvisits pv
JOIN dim_patient_clean p ON p.PatientID=pv.PatientID
JOIN dim_doctor d ON d.DoctorID=pv.DoctorID
GROUP BY patientid,
         doctorid
HAVING countdoc>2
ORDER BY countdoc DESC;

#--Q17: Find departments whose average satisfaction score IS above the overall average
SELECT AVG (satisfactionscore) AS avgscore,
           departmentid
FROM patientvisits
GROUP BY departmentid
HAVING avg(SatisfactionScore) >
  (SELECT avg(satisfactionscore)
   FROM patientvisits) ;

#--Q18: Find The 10 least common combinations that appear IN LESS THAN 1% OF ALL visits
SELECT count(*)AS combination,
       count(*)*100/
  (SELECT COUNT(*)
   FROM patientvisits) AS percentage,
       treatmentid,
       diagnosisid
FROM patientvisits
GROUP BY treatmentid,
         diagnosisid
HAVING percentage<1
ORDER BY combination ASC
LIMIT 10;

#--Q19: SHOW MONTH OVER MONTH revenue growth rate AS a percentage
SELECT *,
       cast((revenue-lag(revenue)over(
                                      ORDER BY MONTH))*100/ lag(revenue) OVER (
                                      ORDER BY MONTH) AS decimal(10, 2))
									  AS growthratepercentage
FROM
  (SELECT sum(billamount-insuranceamount) AS revenue,
          date_format(visitdate, '%Y-%m') AS MONTH
   FROM patientvisits
   GROUP BY MONTH)m ;

#--Q20: Which three cities generate the most net revenue after insurance deductions break down by payment method
WITH cte_rank AS
  (SELECT *,
          rank() OVER (PARTITION BY PayMethod
                       ORDER BY netrevenue DESC) AS cityrank
   FROM
     (SELECT sum(pv.billamount-pv.InsuranceAmount) AS netrevenue,
             p.city AS city,
             pm.PaymentMethod AS paymethod
      FROM patientvisits pv
      JOIN dim_patient_clean p ON p.PatientID=pv.PatientID
      JOIN dim_paymentmethod pm ON pm.PaymentMethodID=pv.PaymentMethodID
      GROUP BY city,
               paymethod) m)
SELECT *
FROM cte_rank
WHERE cityrank<=3;
