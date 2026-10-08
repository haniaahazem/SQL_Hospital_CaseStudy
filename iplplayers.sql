SELECT * FROM  iplplayers;
SELECT 
    SUM(Price_in_cr), team AS totalprice
FROM
    iplplayers
GROUP BY Team
ORDER BY totalprice DESC;

select player, team, price_in_cr from iplplayers 
group by team, player
order by price_in_cr desc
LIMIT 3;

select player,  team, price_in_cr from iplplayers
where (team, price_in_cr) in (
				select team, max(price_in_cr)
				from iplplayers 
				group by team
				)
;
select player, team, price_in_cr,rankedd from (
				 select player, price_in_cr, team, 
				 row_number() over (partition by team order by price_in_cr desc) as rankedd from iplplayers) j
 where rankedd<=2;
 

with rankedd as(select player, team, price_in_cr,
				row_number() over (partition by team order by price_in_cr desc) as rankkk
				from iplplayers)
select player, team, price_in_cr, rankkk 
from rankedd
where rankkk<=2 ;


with total_spending_again as (
	select team, 
	player, 
    price_in_cr,
    sum(price_in_cr) over (partition by team) *100  as total_spending
    from iplplayers 
    group by team, player, price_in_cr)

select team, player, (price_in_cr/total_spending) *100 as percentage 
from total_spending_again
group by player, team, percentage;

with ranged as (select player, price_in_cr, team ,
	case when price_in_cr>15 then "high"  
		when price_in_cr between 5 and 15 then "medium" 
		when price_in_cr<5 then "low" end as "price_range"
from iplplayers)
		
select count(price_range) as rangedcount, price_range, team
from ranged
group by team, price_range
order by team, price_range;

select "indian" as type, (
	select avg(price_in_cr)from iplplayers where Type like "Indian%") as avgprice
union all
select "overseas" as type, (
select avg(price_in_cr) from iplplayers where Type like "Overseas%") as avgprice;


select price_in_cr, team, player from iplplayers p where price_in_cr > 
	(select avg(price_in_cr) from iplplayers where team =p.Team);

select team, player, price_in_cr, avgprice from (
	select team, 
    price_in_cr, player,
	avg(price_in_cr) over(partition by team) as avgprice 
    from iplplayers) m
where price_in_cr > avgprice;



select player, role, maxx from (
	select player, role, price_in_cr,
	max(price_in_cr) over (partition by team, role) as maxx from iplplayers) m
    where price_in_cr=maxx
;

select player, team,role, price_in_cr from iplplayers p where price_in_cr = (select max(price_in_cr) from iplplayers where role=p.role) 


