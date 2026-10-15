/*Q1 Find the busiest airport by the number of flights take off
*/
select count(f.flightid) as busy, a.name
from flights f
join airports a on 
f.origin=a.airportid
group by a.name
order by busy desc;

#Q2 Total number of tickets sold per airline
 
 select count(*) as sold, a.name
 from tickets t 
 join flights f on t.flightid=f.flightid
 join airports a on f.airlineid=a.airportid
 group by a.name;

#Q3 List all flights operated by IndiGo with airport names (origin and destination)

select f.flightid,
	a.name as airlinename, 
    ap.name as originairportname, 
    ap1.name as destinitaionname,
    f.origin,
    f.destination
from flights f
join airlines a on a.airlineid=f.airlineid
join airports ap on f.destination=ap.airportid
join airports ap1 on f.origin=ap1.airportid
where a.name="indigo";

#Q4 For each airport, show the top airline by number of flights departing from there
with joined as (
	select f.flightid as ids,
          f.origin as origin,
          ap.name as airportname,
          al.name as airlinename
	from flights f
	join airports ap on ap.airportid=f.origin
    join airlines al on al.airlineid=f.airlineid
    ),
    
    ranked as (
				select airportname, airlinename,
                count(ids) as countlfights,
                rank () over (partition by origin order by count(ids)desc ) as rankedby 
                from joined
                group by airportname, airlinename, origin)
                
		select * from ranked;
                
                
#OR joins last


with cteranked as (
	select *, rank () over (partition by origin order by countflights) as rankedby 
		from (
				select airlineid, origin,
				count(flightid) as countflights 
				from flights
				group by origin, airlineid
			) m)
		
    select 
		  f.countflights,
          al.name as airlname,
          ap.name as airportnamee
	from cteranked f
	join airports ap on ap.airportid=f.origin
    join airlines al on al.airlineid=f.airlineid;


#--Q5 For each flight, show time taken in hours and categorize it as Short (<2h), Medium (25h), or Long (>5h)
with ctetime as (select*, (hour(ArrivalTime)+(minute(arrivaltime)/60))- 
						(hour(DepartureTime) +(minute(DepartureTime)/60)) as timetaken 
from flights)

select *, case when timetaken <2 then "short"
					when timetaken between 2 and 5 then "medium"
                    when timetaken >5 then  "long"
                    end as "durationrange"
                    from ctetime;
                    

#--Q6 Show each passenger's first and last flight dates and number of flights
with joined as (
	select f.departuretime as dates, 
	p.name as name, f.flightid as flightid, p.passengerid as passengerid
	from tickets t
	join passengers p on t.PassengerID=p.passengerid 
	join flights f on f.flightid=t.flightid
), 
	queryy as (
		select max(date(dates)) as lastdeparturedate,
		min(date(dates)) as firstdeparturedate,
		name, passengerid,
		count(flightid) as countflights
		from joined
	   GROUP BY passengerid, name)
select * from  queryy;
                    
#--Q7 Find flights with the highest price ticket sold for each route (origin -> destination)

with ctejoined as
	(select t.price as price,
			f.origin as origin, 
            f.Destination as destination,
            ap1.name as destname,
            ap.name as ogname
    from tickets t 
    join flights f on f.FlightID=t.FlightID
    join airports ap on ap.AirportID=f.origin
    join airports ap1 on ap1.AirportID=f.destination),
 
 
				  query as (select
						destname, 
                        ogname,
                        price,
						rank() over (partition by origin, destination order by price desc) as ranked
				from ctejoined)

	select * from query
	where ranked=1;

#Q8 Find the highest spending passenger in each Frequent Flyer Status group
with joined as
	( SELECT 
       t.price as price,
       p.passengerid as id,
       p.name as name,
       p.FrequentFlyerStatus,
       rank() over (partition by FrequentFlyerStatus order by price desc) as rnak
       from tickets t 
       join passengers p on p.passengerid=t.passengerid)
       
       select * from joined where rnak=1;
       
       
with summ as 
	(select 
       p.passengerid as id,
       p.name as name,
       p.FrequentFlyerStatus as status,
       sum(price) as sum
from tickets t  
join passengers p on p.passengerid=t.passengerid
group by id, name
),

rnak as 
	(select * ,
			rank () over (partition by status order by sum desc) as rankk
	from summ 
)

select * 
from rnak
where rankk=1
;




select count(flightid), passengerid from tickets
group by passengerid;
;
select * from passengers;
select * from flights;
select *from  airports;
