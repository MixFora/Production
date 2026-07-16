/****** Script for SelectTopNRows command from SSMS  ******/
DECLARE @year INT = 2025
DECLARE @month INT = 5

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




