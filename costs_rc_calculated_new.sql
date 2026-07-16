--DECLARE @YearAgo DATE = DATEADD(year, -1, cast(getdate() as date))
drop table if exists #ttt
  IF OBJECT_ID('tempdb.dbo.#t2') IS NOT NULL DROP TABLE #t2

DECLARE @startdate date = '2026-05-01'--DATEFROMPARTS(year(@YearAgo), month(@YearAgo), 1)
DECLARE @finishdate date = '2026-05-31'
declare @year int=2026
declare @month int=5

-----таблиц€ приход≥в
SELECT 
	year(OperationDate) as year,
	month(OperationDate) as month,
	[filid],
	c.LagerID,
	sum(c.[OperationKolvo]) [kolvo]
	into #ttt
FROM [DataWareHouse].[dbo].[Cache_FMF_Oper] c (nolock)
	right JOIN [DataWareHouse].[dbo].[dim_operations] qqq (nolock) on c.[OperationID]=qqq.[OPERATIONID] and qqq.OperationID in (5,24,148,149) --(4,5,13,15,17,23,24,30,148,149) -- +1 или -1 дл€ разных типов движений
	right join [MasterData].[dbo].[dim_Filials] aaa (nolock) on c.[FilID]=aaa.[fil.Filials.filialId] and aaa.[fil.LegalUnits.legalUnitSapId] in ('5001','5014')
  where OperationDate between @startdate and @finishdate 
group by [filid],c.LagerID ,year(OperationDate),month(OperationDate)

----- з таблиц≥ приход≥в рахуЇмо долю кожного магазина
  SELECT filid, lagerid, month, year 
  ,ISNULL([kolvo] / NULLIF(SUM([kolvo]) OVER (PARTITION BY month, year, lagerid), 0), 0) AS share_filid
  INTO #t2
  FROM #ttt

 ---видал€Їмо стар≥ дан≥ та вставл€Їмо нов≥
 delete from [Business_Analytic].[prod].[costsRC_calculated] where date between @startdate and @finishdate 
 
 insert into [Business_Analytic].[prod].[costsRC_calculated]
  SELECT 
		datefromparts(c.year,c.month,'01') date
		--,RCId,postId
		,filid
		,c.lagerid
		,costsLogistics*share_filid costsLogistics
		,costsOther*share_filid costsOther
		,costs*share_filid costs
		,case when sp.[sprav] is not null then sp.[sprav] else '≥нше' end sprav
,concat(d.DepId_,'_',c.lagerid) lagerid2

FROM [Business_Analytic].[prod].[costsRC] c
  left join #t2 ON #t2.lagerid=c.lagerId AND #t2.year=c.year AND #t2.month=c.month
  left join [Business_Analytic].[prod].[sprav] sp on sp.lagerid=c.[lagerid]
  left join [Business_Analytic].[dbo].[Lager_cex] d on d.id=c.lagerid
  WHERE c.year=@year and c.month=@month

 -- where costsLogistics*share_filid is not null

 /*select sum(costs) from [Business_Analytic].[prod].[costsRC]
 where year=2025 and month=4 and filid=2506*/
