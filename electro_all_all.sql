---------------------------------------- VITRINA -----------------------------------------------
declare @date date='2026-05-01' --'2023-01-31'  --getdate()-1  ------------@dat_cycle
declare @year int=year(@date)
declare @month int=month(@date)
declare @days int=DAY(EOMONTH(@date))

delete from [Business_Analytic].[prod].[holod_dovidnik]
where year=@year and month=@month


insert into [Business_Analytic].[prod].[holod_dovidnik]
select @year year, @month month, dep_group, format, equipment, cons_kwt_hour from [Business_Analytic].[prod].[holod_dovidnik]
where year=YEAR(dateadd(month, -1, @date)) and month=month(dateadd(month, -1, @date))
/*select year, month+1 month, dep_group, format, equipment, cons_kwt_hour from [Business_Analytic].[prod].[holod_dovidnik]
where year=YEAR(dateadd(month, -1, @date)) and month=month(dateadd(month, -1, @date))*/

delete from [Business_Analytic].[prod].[electro_all]
where year(date)=@year and month(date)=@month

DROP TABLE IF EXISTS #vitrina
DROP TABLE IF EXISTS #vitrina2
DROP TABLE IF EXISTS #vitrina3

SELECT DISTINCT
	  DATEFROMPARTS(a.year, a.month, 1) Date
      ,[Filid]
      ,CASE
		WHEN Depid IN (8, 106) THEN 106
		WHEN Depid IN (103, 11) THEN 11
		WHEN Depid = 117 THEN 117
		END [Depid]
	 ,c.tariff
INTO #vitrina
  FROM [Business_Analytic].[poteri].[all_oper] a
  LEFT JOIN [MasterData].[dbo].[dim_Filials] b on b.[fil.Filials.filialId]=a.filid
  LEFT JOIN [Business_Analytic].[prod].[electro_tariff] c on c.MVZ=b.[fil.Filials.filialExpenseCenter] and c.year=a.year and c.month=a.month
    WHERE Type_oper = 'sales' and depid in (106, 117, 11, 103, 8) and a.year=@year and a.month=@month


SELECT 
	Date
	,a.filid
	,a.depid
	,tariff
	,b.[Общее потребление за сутки, кВт]*@days [consumption, kW]
	,tariff*b.[Общее потребление за сутки, кВт]*@days [Consump_UAH]
INTO #vitrina2
FROM #vitrina a
LEFT JOIN (SELECT [Filid],SUM([Общее потребление за сутки, кВт]) [Общее потребление за сутки, кВт],[depid]
			FROM [Business_Analytic].[prod].[vitrina_dovidnik]
			GROUP BY Filid, [depid]) b on b.filid=a.filid and b.depid	=a.Depid
where b.[Общее потребление за сутки, кВт] is not null


SELECT
	Date
	,filid
	,depid
	,IIF(#vitrina2.tariff IS NULL, a.Tariff, #vitrina2.tariff) Tariff
	,[consumption, kW]
INTO #vitrina3
FROM #vitrina2

CROSS JOIN (
	SELECT distinct SUM([Consump_UAH]) OVER (PARTITION BY Date)/SUM([consumption, kW]) OVER (PARTITION BY Date) Tariff
	FROM #vitrina2
	where Tariff IS NOT NULL) a



delete from [Business_Analytic].[prod].[electro_all] where [Group]='vitrina' and [Date]=DATEFROMPARTS(@year,@month,'01')
insert into [Business_Analytic].[prod].[electro_all]
SELECT
	filid
	,depid
	,DATEFROMPARTS(@year,@month,'01') [Date]
	,[consumption, kW]
	,Tariff
	,[consumption, kW]*Tariff [Consump_UAH]
	,'vitrina' [Group] 
FROM #vitrina3


----------------------------------------------------HOLOD -----------------------------------------------------
--для циклу перебору дат ------------
------------declare @dat_cycle date='2023-01-01'

------------while @dat_cycle<'2025-01-01'
------------begin
drop table if exists #meat_grill
drop table if exists #fish
drop table if exists #dovid
drop table if exists #result0
drop table if exists #result


declare @day int=DAY(EOMONTH(@date))		--	day(@date)

--беремо продажі по м'ясному/грилю, де продаж більше 5000грн і вираховуємо долю м'яса/гриля у сумі м'яса та гриля 
SELECT	c.[year],c.[month],c.[Filid]
		,case when (ISNULL(meat.sumout,0)+ISNULL(grill.sumout,0))=0 then 0 else ISNULL(meat.sumout,0)/(ISNULL(meat.sumout,0)+ISNULL(grill.sumout,0)) end meat_share
		,case when (ISNULL(meat.sumout,0)+ISNULL(grill.sumout,0))=0 then 0 else ISNULL(grill.sumout,0)/(ISNULL(meat.sumout,0)+ISNULL(grill.sumout,0)) end grill_share
		into #meat_grill
FROM [Business_Analytic].[poteri].[all_oper] c
left join MasterData.dbo.dim_Filials f on f.[fil.Filials.filialId]=c.Filid

left join (select [year],[month],[Filid],SUM(sumout) sumout from [Business_Analytic].[poteri].[all_oper] 
			WHERE Type_oper='sales' and year=@year and month=@month and Depid IN (8,106) 
			group by [year],[month],[Filid] having  SUM(sumout)>5000) meat on meat.Filid=c.Filid and meat.year=c.year and meat.month=c.month

left join (select [year],[month],[Filid],SUM(sumout) sumout from [Business_Analytic].[poteri].[all_oper] 
			WHERE Type_oper='sales' and year=@year and month=@month and Depid IN (104) 
			group by [year],[month],[Filid] having  SUM(sumout)>5000) grill on grill.Filid=c.Filid and grill.year=c.year and grill.month=c.month
		
WHERE Type_oper='sales' and c.year=@year and c.month=@month and Depid IN (8,106,104) and f.[fil.Filials.filialName] like 'Д %'
group by c.[year],c.[month],c.[Filid]
		,case when (ISNULL(meat.sumout,0)+ISNULL(grill.sumout,0))=0 then 0 else ISNULL(meat.sumout,0)/(ISNULL(meat.sumout,0)+ISNULL(grill.sumout,0)) end 
		,case when (ISNULL(meat.sumout,0)+ISNULL(grill.sumout,0))=0 then 0 else ISNULL(grill.sumout,0)/(ISNULL(meat.sumout,0)+ISNULL(grill.sumout,0)) end 
having  SUM(c.sumout)>5000

--беремо продажі по рибі, де продаж більше 5000грн (по рибі долі не потрібно, =1)
SELECT	c.[year],c.[month],c.[Filid]
		,1 as fish_share
		into #fish
FROM [Business_Analytic].[poteri].[all_oper] c
left join MasterData.dbo.dim_Filials f on f.[fil.Filials.filialId]=c.Filid		
WHERE Type_oper='sales' and c.year=@year and c.month=@month and Depid IN (11,103) and f.[fil.Filials.filialName] like 'Д %'
group by c.[year],c.[month],c.[Filid]
having  SUM(c.sumout)>5000

--створюємо довідник магазинів, де були продажі риба/м'ясо/гриль
select distinct YEAR, MONTH, filid into #dovid from
(select YEAR, MONTH, filid from #meat_grill
	union all
select YEAR, MONTH, filid from #fish) r

--додаємо формат магазину у вигляді, як вони у табл [holod_dovidnik]
select	c.year, c.month, c.Filid 
		, sf.FilialName, sf.Format format1
		, case	when sf.Format='Fora' and isnull(sf.[Площа ТЗ, м2],0)<350 then 'Конвиниенс 250-350'
				when sf.Format='Fora' and isnull(sf.[Площа ТЗ, м2],0)>=350 then 'Конвиниенс 350-450'
				when sf.Format='Express' or sf.Format is null then 'Експресс'
				else 'інше' end format
		,isnull(#fish.fish_share,0) fish_share, isnull(#meat_grill.meat_share,0) meat_share, isnull(#meat_grill.grill_share,0) grill_share
		into #result0
from #dovid c
left join [Business_Analytic].[dbo].[Stores_Format] sf on sf.Filid=c.Filid
left join #fish on #fish.year=c.year and #fish.month=c.month and #fish.Filid=c.Filid
left join #meat_grill on #meat_grill.year=c.year and #meat_grill.month=c.month and #meat_grill.Filid=c.Filid

--вираховуємо окремо споживання риби, м'яса,гриля
select	c.year, c.month, c.Filid	--		, c.FilialName, c.format1, c.format, c.fish_share, c.meat_share, c.grill_share 
--		,isnull(hd1.cons_kwt_hour,0) kwt_hour_fish
		,isnull(hd1.cons_kwt_hour,0)*24*@day kwt_month_fish
--		,isnull(hd2.cons_kwt_hour,0)*c.meat_share+isnull(hd3.cons_kwt_hour,0)*IIF(c.meat_share>0,1,0) kwt_hour_meat
		,(isnull(hd2.cons_kwt_hour,0)*c.meat_share+isnull(hd3.cons_kwt_hour,0)*IIF(c.meat_share>0,1,0))*24*@day kwt_month_meat
--		,isnull(hd2.cons_kwt_hour,0)*c.grill_share kwt_hour_grill
		,isnull(hd2.cons_kwt_hour,0)*c.grill_share*24*@day kwt_month_grill
		into #result
from #result0 c
left join (	SELECT [year],[month],[dep_group],[format],sum([cons_kwt_hour]) cons_kwt_hour
			FROM [Business_Analytic].[prod].[holod_dovidnik]
			where year=@year and month=@month and dep_group='риба' group by [year],[month],[dep_group],[format]) hd1 on hd1.[year]=c.year and hd1.month=c.month and hd1.format=c.format

left join (	SELECT [year],[month],[dep_group],[format],sum([cons_kwt_hour]) cons_kwt_hour
			FROM [Business_Analytic].[prod].[holod_dovidnik]
			where year=@year and month=@month and dep_group='мясо+гриль' group by [year],[month],[dep_group],[format]) hd2 on hd2.[year]=c.year and hd2.month=c.month and hd2.format=c.format

left join (	SELECT [year],[month],[dep_group],[format],sum([cons_kwt_hour]) cons_kwt_hour
			FROM [Business_Analytic].[prod].[holod_dovidnik]
			where year=@year and month=@month and dep_group='мясо' group by [year],[month],[dep_group],[format]) hd3 on hd3.[year]=c.year and hd3.month=c.month and hd3.format=c.format


--додаємо тариф на е.е. і витрати на е.е. по рибі/м'ясу/грилю у вигляді, як вони у таблиці [Business_Analytic].[prod].[electro_all] (група "holod")
-- вставляємо дані у [Business_Analytic].[prod].[electro_all]

delete from [Business_Analytic].[prod].[electro_all] where [Group]='holod' and [Date]=DATEFROMPARTS(@year,@month,'01')
insert into [Business_Analytic].[prod].[electro_all]

select c.filid [Filid], 11 as [Depid], DATEFROMPARTS(@year,@month,'01') [Date], kwt_month_fish [Consump_kwt]
		,case	when t.Tariff is not null then t.Tariff 
				else t_avg.[Tariff] end [Tariff]
		,case	when t.Tariff is not null then t.Tariff*kwt_month_fish 
				else t_avg.Tariff*kwt_month_fish end [Consump_UAH]

		,'holod' [Group]
from #result c
left join (	SELECT f.[fil.Filials.filialId] filid,[year],[month],[Tariff]
			FROM [Business_Analytic].[prod].[electro_tariff] t
			left join MasterData.dbo.dim_Filials f on f.[fil.Filials.filialExpenseCenter]=t.MVZ) t on t.filid=c.Filid and t.month=@month and t.year=@year

left join (	SELECT [year],[month], sum([Consump_UAH])/sum([Consump_kwt]) [Tariff]
			FROM [Business_Analytic].[prod].[electro_tariff] t
			group by [year],[month]) t_avg on t_avg.month=@month and t_avg.year=@year

union all

select c.filid [Filid], 106 as [Depid], DATEFROMPARTS(@year,@month,'01') [Date], kwt_month_meat [Consump_kwt]
		,case	when t.Tariff is not null then t.Tariff 
				else t_avg.[Tariff] end [Tariff]
		,case	when t.Tariff is not null then t.Tariff*kwt_month_meat
				else t_avg.Tariff*kwt_month_meat end [Consump_UAH]

		,'holod' [Group]
from #result c
left join (	SELECT f.[fil.Filials.filialId] filid,[year],[month],[Tariff]
			FROM [Business_Analytic].[prod].[electro_tariff] t
			left join MasterData.dbo.dim_Filials f on f.[fil.Filials.filialExpenseCenter]=t.MVZ) t on t.filid=c.Filid and t.month=@month and t.year=@year

left join (	SELECT [year],[month], sum([Consump_UAH])/sum([Consump_kwt]) [Tariff]
			FROM [Business_Analytic].[prod].[electro_tariff] t
			group by [year],[month]) t_avg on t_avg.month=@month and t_avg.year=@year

union all

select c.filid [Filid], 104 as [Depid], DATEFROMPARTS(@year,@month,'01') [Date], kwt_month_grill [Consump_kwt]
		,case	when t.Tariff is not null then t.Tariff 
				else t_avg.[Tariff] end [Tariff]
		,case	when t.Tariff is not null then t.Tariff*kwt_month_grill 
				else t_avg.Tariff*kwt_month_grill end [Consump_UAH]

		,'holod' [Group]
from #result c
left join (	SELECT f.[fil.Filials.filialId] filid,[year],[month],[Tariff]
			FROM [Business_Analytic].[prod].[electro_tariff] t
			left join MasterData.dbo.dim_Filials f on f.[fil.Filials.filialExpenseCenter]=t.MVZ) t on t.filid=c.Filid and t.month=@month and t.year=@year

left join (	SELECT [year],[month], sum([Consump_UAH])/sum([Consump_kwt]) [Tariff]
			FROM [Business_Analytic].[prod].[electro_tariff] t
			group by [year],[month]) t_avg on t_avg.month=@month and t_avg.year=@year


---------------------------------------------------- ELECTRO EQUIPMENT -----------------------------------------------------
------------	set @dat_cycle=dateadd(month,1,@dat_cycle)
------------	end

/****** Script for SelectTopNRows command from SSMS  ******/
IF OBJECT_ID('tempdb..#t1') IS NOT NULL DROP TABLE #t1

IF OBJECT_ID('tempdb..#t2') IS NOT NULL DROP TABLE #t2

IF OBJECT_ID('tempdb..#t3') IS NOT NULL DROP TABLE #t3

IF OBJECT_ID('tempdb..#t4') IS NOT NULL DROP TABLE #t4

IF OBJECT_ID('tempdb..#t5') IS NOT NULL DROP TABLE #t5

IF OBJECT_ID('tempdb..#median') IS NOT NULL DROP TABLE #median

IF OBJECT_ID('tempdb..#t6') IS NOT NULL DROP TABLE #t6

IF OBJECT_ID('tempdb..#t7') IS NOT NULL DROP TABLE #t7

IF OBJECT_ID('tempdb..#electro_dep') IS NOT NULL DROP TABLE #electro_dep

/****** Script for SelectTopNRows command from SSMS  ******/
SELECT [Filid]
      ,[year]
      ,[month]
	  ,[Пиццерия] [consumption, kW]
	  ,116 depid
	  ,'original' Feature1
INTO #electro_dep
  FROM [Business_Analytic].[prod].[temp]
  where year=@year and month=@month

  union all

  SELECT [Filid]

      ,[year]
      ,[month]
	        ,[Гриль] [consumption, kW]
	  ,104 depid
	  ,'original' Feature1
  FROM [Business_Analytic].[prod].[temp]
  where year=@year and month=@month

    union all

  SELECT [Filid]

      ,[year]
      ,[month]
	        ,[Стрит-Фуд] [consumption, kW]
	  ,117 depid
	  ,'original' Feature1
  FROM [Business_Analytic].[prod].[temp]
  where year=@year and month=@month

    union all

  SELECT [Filid]
      ,[year]
      ,[month]
      ,[Допёк] [consumption, kW]
	  ,102 depid
	  ,'original' Feature1
  FROM [Business_Analytic].[prod].[temp]
  where year=@year and month=@month

    union all

  SELECT [Filid]
      ,[year]
      ,[month]
      ,[Пекарня] [consumption, kW]
	  ,107 depid
	  ,'original' Feature1
  FROM [Business_Analytic].[prod].[temp]
  where year=@year and month=@month


SELECT
 a.id,
	Case
		WHEN Ed_izm_Type=1 THEN CAST(REPLACE(Ed_izm_Kol, ',', '.') as float)/1000
		WHEN Ed_izm_Type=2 THEN Ed_izm_Kol
	END kg
INTO #t1
FROM [CB].[dbo].[Lager] a
where Ed_izm_Type IN (1,2)

IF OBJECT_ID('tempdb..#t2') IS NOT NULL DROP TABLE #t2
SELECT [year]
      ,[month]
      ,[Filid]
      ,[Depid]
	  ,[lagerid]
	  ,CASE
		WHEN Type_oper='sales' THEN kolvo
		WHEN Type_oper='spisaniya' THEN -kolvo
	  END kolvo
	  ,Type_oper
  INTO #t2
  FROM [Business_Analytic].[poteri].[all_oper]

  where  year=@year and month = @month and type_oper='sales' and depid IN (102, 104, 107, 116, 117)


SELECT year
		,month
		,filid
		,depid
		,lagerid
		,SUM(kolvo) kolvo
INTO #t3
FROM #t2

GROUP BY year, month, filid, depid, lagerid

SELECT
		year
		,month
		,filid
		,depid
		,SUM(kolvo*#t1.kg) kolvo_kg
INTO #t4
FROM #t3
INNER JOIN #t1 ON #t1.id=#t3.lagerid
GROUP BY year, month, filid, depid

SELECT
		#t4.year
		,#t4.month
		,#t4.filid
		,#t4.depid
		,kolvo_kg
		,e.Feature1
		,IIF(e.[consumption, kW]>0, e.[consumption, kW], 0) [consumption, kW]
		,(IIF(e.[consumption, kW]>0, e.[consumption, kW], 0))/NULLIF(kolvo_kg, 0) kw_sumout
INTO #t5
FROM #t4
LEFT JOIN #electro_dep e ON e.year=#t4.year AND e.month=#t4.month AND e.Filid=#t4.Filid AND e.Depid=#t4.Depid


SELECT distinct year, month, depid, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY kw_sumout) OVER (PARTITION BY depid) AS Median_kw_sumout 
INTO #median
FROM (SELECT * FROM #t5 WHERE kw_sumout>0) a

select 
		#t5.year
		,#t5.month
		,#t5.filid
		,#t5.depid
		,kolvo_kg
		,[consumption, kW]
		,Feature1
		,IIF(kw_sumout=0, Median_kw_sumout, kw_sumout) kw_sumout
INTO #t6
from #t5
left join #median ON #median.year=#t5.year AND #median.month=#t5.month AND #median.Depid=#t5.Depid

SELECT
		filid
		,depid
		,year
		,month
		--,kolvo_kg
		,IIF([consumption, kW]=0, kolvo_kg*kw_sumout, [consumption, kW]) [consumption, kW]
		--,kw_sumout
		,IIF(Feature1 IS NULL, 'avg', Feature1) Feature1
INTO #t7
FROM #t6

--delete from [Business_Analytic].[prod].[electro_dep]
--where year=2024 and month =10 and Depid IN (102, 104, 107, 116, 117)
delete from [Business_Analytic].[prod].[electro_equipment] where year=@year and month=@month
insert into [Business_Analytic].[prod].[electro_equipment]
select * from #t7


---------------------------------------------------- ELECTRO ALL -----------------------------------------------------

DROP TABLE IF EXISTS #hot

DROP TABLE IF EXISTS #hot2

SELECT [Filid]
      ,[Depid]
	  ,DATEFROMPARTS(a.year, a.month, 1) Date
      ,[consumption, kW]
	  ,c.Tariff
	  ,c.Tariff*[consumption, kW] [Consump_UAH]
	  ,'hot' [Group]
INTO #hot
  FROM [Business_Analytic].[prod].[electro_equipment] a
  left join [MasterData].[dbo].[dim_Filials] b on b.[fil.Filials.filialId]=a.Filid
  left join [Business_Analytic].[prod].[electro_tariff] c on c.MVZ=b.[fil.Filials.filialExpenseCenter] and c.year=a.year and c.month=a.month
  where a.year=@year and a.month=@month

SELECT
	filid
	,depid
	,date
	,[consumption, kW]
	,IIF(#hot.Tariff IS NULL, a.Tariff, #hot.Tariff) Tariff
	,[Group]
INTO #hot2
FROM #hot
CROSS JOIN (
SELECT distinct SUM([Consump_UAH]) OVER (PARTITION BY Date)/SUM([consumption, kW]) OVER (PARTITION BY Date) Tariff
FROM #hot
where Tariff IS NOT NULL) a

delete from [Business_Analytic].[prod].[electro_all] where date=DATEFROMPARTS(@year, @month, 1) and [Group]='hot'

INSERT INTO [Business_Analytic].[prod].[electro_all]
SELECT
	filid
	,depid
	,date
	,[consumption, kW]
	,Tariff
	,Tariff*[consumption, kW] [Consump_UAH]
	,[Group]
FROM #hot2


DROP TABLE IF EXISTS #tt1

SELECT [year]
      ,[month]
      ,[Filid]
      ,[Depid]
      ,[lagerid]
      ,[kolvo]
  INTO #tt1
  FROM [Business_Analytic].[poteri].[all_oper]
  where year=@year and month=@month and type_oper='sales' and depid=114 and kolvo > 0
  drop table if exists #tt3
select distinct year, month, filid, depid into #tt3 from
(SELECT
[year]
,[month]
,Filid
,[Depid]
,SUM([kolvo]) [kolvo]
FROM #tt1
GROUP BY year, month, filid, depid) a
where kolvo > 0

INSERT INTO [Business_Analytic].[prod].[electro_equipment]
select
Filid
,depid
,year
,month
,3.6*@days [consumption, kW]
,'avg' Feature1
FROM #tt3


drop table if exists #tt78
SELECT equip.Filid, equip.Depid, equip.year, equip.month, equip.[consumption, kW], equip.Feature1,
IIF(Tariff IS NULL,  SUM(tariff.Consump_UAH) OVER (PARTITION BY equip.year, equip.month, depid)/SUM(tariff.Consump_kwt) OVER (PARTITION BY equip.year, equip.month, depid), Tariff) Tariff
into #tt78
FROM [Business_Analytic].[prod].[electro_equipment] equip
LEFT JOIN (SELECT distinct [fil.Filials.filialId], [fil.Filials.filialExpenseCenter] FROM [MasterData].[dbo].[dim_Filials]) dim on dim.[fil.Filials.filialId]=equip.filid
LEFT JOIN [Business_Analytic].[prod].[electro_tariff] tariff on tariff.MVZ=dim.[fil.Filials.filialExpenseCenter] and equip.year=tariff.year and equip.month=tariff.month
WHERE depid=114 and equip.year=@year and equip.month=@month

insert into [Business_Analytic].[prod].[electro_all]
SELECT Filid, depid, DATEFROMPARTS(year, month, 1) date, [consumption, kW], Tariff, Tariff*[consumption, kW] [Consump_UAH], 'hot' [Group]
FROM #tt78


/*
select * from [Business_Analytic].[prod].[electro_all]
where Date='2026-03-01'
*/