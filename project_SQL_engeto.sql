-- Krok 1 - vytvoření tabulky s countries a iso a economies

CREATE or REPLACE TABLE t_jan_tauber_projekt_SQL_countries_data AS 
SELECT lt.country as lookup_country, lt.iso3, lt.population ,
		c.country as countries_country, c.capital_city,c.population_density, c.median_age_2018,
		e.GDP, e.gini, e.u5 as mortality_under5
FROM lookup_table lt 
LEFT JOIN (
	SELECT country, iso3, capital_city , round(population_density,2) as population_density , median_age_2018 
	FROM countries c2 
	) c on lt.iso3 = c.iso3 
LEFT JOIN (
	select e.country,  e2.GDP, e3.gini, e4.u5
	FROM economies e 
 	left join ( select country, year, GDP 
 		from economies
 		where GDP is not NULL group by country ) e2 on e.country = e2.country
 	left join ( select country, year, gini
 		from economies
 		where gini is not NULL group by country ) e3 on e.country = e3.country
 	left join ( select country, year,mortaliy_under5 as u5
 		from economies
		where mortaliy_under5 is not NULL group by country ) e4 on e.country = e4.country
	where e.year > "2015" 
	group by country 
	order by e.country) e on e.country = c.country or e.country = lt.country
where lt.province is NULL 
order by lt.country 
	;


-- Krok 2 - vytvoření tabulky weather

CREATE or REPLACE TABLE t_jan_tauber_projekt_SQL_weather AS 
SELECT date, city  , sum(r1.rain_hours) as rain_hours , max(wind) as max_wind , round(avg_day_temp,3) as avg_day_temp
	FROM 
		(SELECT date, city , hour, rain , wind , temp , 
			avg(case when hour not in (0,3) then temp end) over (PARTITION by date, city ) as avg_day_temp,
			CASE when rain > 0 then 3 else 0 end as rain_hours
		FROM weather w 
		) r1
	where date >= "2020-01-01"
	group by date, city
	order by city, `date`
;

-- alternativa s JOIN - asi o trochu pomalejší 	
	SELECT r2.*, t.avg_day_temp
	FROM 
	(SELECT date, city  , sum(r1.rain_hours) as rain_hours , max(wind) as Max_wind 
	FROM 
		(SELECT date, city , hour, rain , wind ,
		CASE when rain > 0 then 3 else 0 end as rain_hours
		FROM weather w 
		where date >= "2020-01-01"
		) r1
	GROUP BY date, city
	) r2
JOIN 
	(
	SELECT date, city, avg(temp) as avg_day_temp
	FROM weather w 
	WHERE hour not in (0, 3)
	GROUP BY date, city
		) t
on t.date = r2.date and t.city = r2.city
ORDER BY r2.city, r2.date
;

-- Krok 3 - religions - join kvůli vynechání zemí s nulovými hodnotami

CREATE or REPLACE table t_jan_tauber_projekt_SQL_religions AS 
select r.* 
FROM (
SELECT r.country , year, sum(r.population) as sum_pop,
	round(SUM(CASE when religion = "Christianity" then population end) *100/sum(r.population),2) as christianity,
	round(SUM(CASE when religion = "Islam" then population end) *100/sum(r.population),2) as islam,
	round(SUM(CASE when religion = "Hinduism" then population end) *100/sum(r.population),2) as hinduism,
	round(SUM(CASE when religion = "Buddhism" then population end) *100/sum(r.population),2) as buddhism,
	round(SUM(CASE when religion = "Judaism" then population end) *100/sum(r.population),2) as judaism,
	round(SUM(CASE when religion = "Folk Religions" then population end) *100/sum(r.population),2) as folk_religions,
	round(SUM(CASE when religion = "Other Religions" then population end) *100/sum(r.population),2) as other_Religions,
	round(SUM(CASE when religion = "Unaffiliated Religions" then population end) *100/sum(r.population),2) as unaffiliated
FROM religions r 
WHERE year = 2020 and country != "All countries"
GROUP BY country
) r
JOIN religions r2 on r.country = r2.country and r.year = r2.year and r.sum_pop > 0
GROUP BY r.country 
;

-- Krok 4 - Life expectancies 2 varianty

-- doba doziti varianta 1
SELECT country, iso3,
	sum(CASE WHEN year = "2015" then life_expectancy else 0 end) as le_2015,
	sum(CASE WHEN year = "1965" then life_expectancy else 0 end) as le_1965
FROM life_expectancy le 
WHERE (year = "2015" or year = "1965") and iso3 is not NULL 
GROUP BY country, iso3
;

-- doba doziti varianta 2, pomalá
SELECT le.country, le.iso3 , le.life_expectancy as le_2015 , le2.life_expectancy as le_1965 
FROM (
		SELECT *
		FROM life_expectancy le 
		WHERE year = "2015" and iso3 is not NULL 
		) le
JOIN (
	SELECT life_expectancy 
	from life_expectancy le2 
	where year = "1965"
)	le2	
;

-- Krok 5 - napojení covidu na countries_data a tests data a life_expectancy a religions a weather
CREATE OR REPLACE TABLE t_jan_tauber_projekt_SQL_final AS
SELECT cbd.date, cbd.country , cbd.confirmed , ct.tests_performed, c_data.population as population_2020,
	round(ct.tests_performed * 100000/c_data.population,1) as total_tests_per100000,
	round(cbd.confirmed * 100/ct.tests_performed ,1) as confirmed_tests_percent,
	c_data.population_density , c_data.GDP , c_data.gini , c_data.median_age_2018 , c_data.mortality_under5, 
	le.life_exp_2015 - le.life_exp_1965 as life_exp_diff,
	r.christianity, r.buddhism, r.islam, r.hinduism, r.judaism, r.folk_religions, r.other_religions,r.unaffiliated,
	w.avg_day_temp , w.rain_hours , w.max_wind ,
	CASE WHEN weekday(cbd.`date`) in (5,6) then 1 else 0 end as is_weekend,
	CASE WHEN month(cbd.date) in (12,1,2) then 3
		when month(cbd.date) in (3,4,5) then 0 
		when month(cbd.date) in (6,7,8) then 1
		when month(cbd.date) in (9,10,11) then 2 end AS year_season
FROM covid19_basic_differences cbd 
JOIN t_jan_tauber_projekt_SQL_countries_data c_data
	on cbd.country = c_data.lookup_country 
LEFT JOIN ( 
		SELECT date, ISO, tests_performed 
		FROM covid19_tests ct 
		WHERE ISO not in ("FRA", "IND", "ITA", "JPN", "POL", "SGP", "USA") 
			or (ISO = "FRA" AND entity = "people tested")
			or (ISO = "IND" AND entity = "samples tested")
			or (ISO = "ITA" AND entity = "test performed")
			or (ISO = "JPN" AND entity = "people tested (incl. non-PCR)")
			or (ISO = "POL" AND entity = "samples tested")
			or (ISO = "SGP" AND entity = "samples tested")
			or (ISO = "USA" AND entity = "test performed")
			) ct on cbd.date = ct.date and ct.ISO = c_data.iso3 and ct.tests_performed >= 0
LEFT JOIN (
			SELECT country,iso3,
				sum(CASE when year = "2015" then life_expectancy else 0 end) as life_exp_2015,
				sum(CASE when year = "1965" then life_expectancy else 0 end) as life_exp_1965
			FROM life_expectancy le
		 	WHERE (year = "2015" or year = "1965") and iso3 is not NULL 
			GROUP BY country, iso3 ) le on le.iso3 = c_data.iso3
LEFT JOIN t_jan_tauber_projekt_SQL_religions r
	on r.country = c_data.lookup_country or r.country = c_data.countries_country or (r.country="Taiwan" AND c_data.lookup_country = "Taiwan*") or (r.country="Vatican City" AND c_data.lookup_country ="Holy See")
LEFT JOIN t_jan_tauber_projekt_SQL_weather w
	on w.date = cbd.date and w.city = c_data.capital_city 
ORDER BY cbd.country   ;

