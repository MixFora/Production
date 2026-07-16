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
DECLARE @year int = 2025
DECLARE @month int = 5

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

