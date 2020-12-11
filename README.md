# engeto_data_SQL_project
First project of the Engeto Data Analysis online course

Postup tvorby tabulky

Seznámení s daty:

1. Jaké testy (entity) se kde počítají a které nejčastěji? Jaké údaje jsou k dispozici?
	- většina "tests performed" 
	- hodně zemí "people tested" a "samples tested"¨

		SELECT country, entity , count(*) as Entity_count, SUM(tests_performed) 
		FROM covid19_tests ct 
		GROUP by entity 
		ORDER BY Entity_count DESC

	- u 7 států více entit:
	
		SELECT DISTINCT ct.country, ct.entity, sum(ct.tests_performed ), max(cumulative)
		FROM covid19_tests ct 
		JOIN (
		SELECT DISTINCT date, country, count (1) 
		FROM covid19_tests ct 
		GROUP BY country, date 
		HAVING count(1) > 1
		) ct2 on ct.country = ct2.country and ct.date = ct2.date
		group by ct.country , ct.entity 

	- není vždy jisté zda dvě entity u daného státu se doplňují nebo překrývají (např. USA)
	a z jakých entit testů pak čerpá tabulka covid19_basic_differences údaje o "confirmed"
	U obou entit jsou podobné počty, kromě Japonska, Itálie a Singapuru, kde je jeden údaj výrazně vyšší. V Jap. zřejmě v 	mnohem větší míře používají a evidují non-PCR testy.
	Vybral jsem u dané země jen jednu možnost "people" nebo "samples" nebo "tests", bez údaje zahrnující non-PCR testy(kromě JPN)

	France: people tested
	India: samples tested  
	Italy: tests performed
	Japan: tests performed jen po týdnu, pak až od listopadu / people tested (incl. non-PCR) - od února skoro kompletní
	Poland: samples tested
	Singapore: NULL	*nejsou vyplněná žádná data o performed tests
	United States: tests performed

	- ostatní poznámky:
	Singapur, Netherlands, Germany, Spain, Brazil a Japan(test performed) udává jen kumulativní data, jednou za týden.
	Sweden data až od července, Lithuania chybí hodně dat, Belarus - chybí hodně dat, Mauritania taky chybí většina dat.
	Kumulativní data skoro všech zemí nesouhlasí přesně se součtem denních testů, zřejmě u všech zemí některé denní NULL. Rozdíly ale minimální.
	Tabulka obsahuje jen 110 zemí s počty testů, tedy pro cca 90 zemí z tabulky covid_basic_differences nejsou dotupné údaje. Naopak je zde navíc uveden Hong Kong.
	
	Také jsou někde záporné hodnoty provedených testů, tyto řádky nebyly joinovány
	
		select DISTINCT * -- , entity, count(DISTINCT entity) as count_entity , country 
		from covid19_tests ct 
		where tests_performed <= 0
		order by country,date
	
	V covid19_basic_differences jsou kromě zemí i testy na lodích Diamond Princess a MS Zaandam, data z ostatních tabulek k nim tedy chybí.


2. Údaje o jednotlivých zemích:
	Údaje o počtu obyvatel jsou ve více tabulkách, nějaktuálnějsí v tabulce lookup_table (pololetí 2020?).

	- Economies:

		Pro různé země jsou nejnovější údaje GINI, GDP, mortalityU5 dostupné v různý rok, pro výběr všech ekonomických dat je tedy brána nejnovější dostupná hodnota, která zároveň není starší než 5 let.
			Zkoušel jsem varianty - pouze s group country a join na country anebo "first_value(gini) over (partition by country order by year desc)"
			Oboje dává stejné výsledky, GROUP asi řadí země automaticky podle datumu?
			Použitý left join, protože někdy je uvedeno jen GDP a není Gini.

	- Tabulky Economies a Religions nemají ISO kody
		Oproti covid tabulce v Economies chybí Taiwan, Vatican, Brunei a několik dalších ministátů.
		V tabulce Religions chybí asi jen 3 ministáty (Saint Lucia...)
		Pod jinými názvy je v Economies Kosovo, v Religions Kosovo, Taiwan a Vatican je nutné zohlednit v JOINu.
		Ačkoliv je Vatikán v Religions, všechny jeho hodnoty jsou hodnoty 0 (i křesťantství :)


3. Počasí:
	- Průměrná teplota:
		standard prům.t. = (7 + 14 + 2*21)/4  ale udaje jsou 0,3,6,9,12,15,18,21 - ale vzorec se liší v různých částech světa
		nebo aritm. prům. v 0, 6, 12, 18 UTC
		pro Covid účel - vynechány teploty v době, kdy se venku pohybuje minimum lidí - tj. 0,3 a zanedbána změna na letní čas
	
	- Počet hodin, kdy byly srážky nenulové:
		úseky po 3 hodinách, nelze zjistit jak dlouho pršelo, pro daný úsek započteny 3 hodiny deště

	- Tabulka weather obsahuje pouze 35 měst, vyfiltrovány ty, které jsou hlavní města států - u většiny států tedy nebudou data o počasí uvedeny
	- Data o počasí jen do 31.10.2020

Tvoření tabulek:

1. Pomocná tabulka propojující countries s iso kody a economies
2. Pomocná tabulka weather - zhrnuty data od 1.1.2020, použita varianta bez JOINování
3. Pomocná tabulka Religions:
	- pro počítání procentuálního zatoupení náboženství v populaci, byl jako celkový počet obyvatel použit celkový součet ze všech náboženství
	- čísla o počtu stoupenců náboženství jsou jen odhadem, a proto pro výpočet procent údaje z jiné tabulky o přesném počtu obyvatel států nelze použít, u některých zemí by pak vycházela zastoupení náboženství více než 100%
	- odstraněny záznamy sdružující čísla pro "all countries" a řádky s nulovými hodnotami
4. Life expectancies - 2 varianty řešení, zvolena bez JOIN - cca 10x rychlejší
5. Propojení všech tabulek a vytvoření nových sloupců finální tabulky

Final Table:
55670 row(s) updated - 10m 43s




