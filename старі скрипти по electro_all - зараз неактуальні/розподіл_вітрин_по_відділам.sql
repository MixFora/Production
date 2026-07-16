/****** Script for SelectTopNRows command from SSMS  ******/

declare @date date='2025-05-01' --'2023-01-31'  --getdate()-1  ------------@dat_cycle
declare @year int=year(@date)
declare @month int=month(@date)
declare @days int=DAY(EOMONTH(@date))

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
	,b.[ќбщее потребление за сутки, к¬т]*@days [consumption, kW]
	,tariff*b.[ќбщее потребление за сутки, к¬т]*@days [Consump_UAH]
INTO #vitrina2
FROM #vitrina a
LEFT JOIN (SELECT [Filid],SUM([ќбщее потребление за сутки, к¬т]) [ќбщее потребление за сутки, к¬т],[depid]
			FROM [Business_Analytic].[prod].[vitrina_dovidnik]
			GROUP BY Filid, [depid]) b on b.filid=a.filid and b.depid	=a.Depid
where b.[ќбщее потребление за сутки, к¬т] is not null

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