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

#--Q3. Categorize patients INTO age groups AND calculate the average bill amount FOR EACH age band.(Assume age AT TIME OF visit based ON VisitDate.) WITH patientsage AS
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

#Q10 Identify the most commonly prescribed treatment for each diagnosis. 
WITH cte_rank AS
  (SELECT totaldio,
          TREAT,
          dia,
          rank() OVER (PARTITION BY dia
                       ORDER BY totaldio DESC) AS rankk
   FROM
     (SELECT count(dd.DiagnosisID) AS totaldio,
             dt.Treatmentname AS TREAT,
             dd.Diagnosisname AS dia
      FROM patientvisits pv
      JOIN dim_diagnosis dd ON dd.diagnosisid=pv.diagnosisid
      JOIN dim_treatment dt ON dt.TreatmentID=pv.TreatmentID
      GROUP BY TREAT,
               dia)m)
SELECT totaldio,
       TREAT,
       dia
FROM cte_rank
WHERE rankk=1;
