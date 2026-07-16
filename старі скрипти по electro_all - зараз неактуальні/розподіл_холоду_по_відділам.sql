--для циклу перебору дат ------------
------------declare @dat_cycle date='2023-01-01'

------------while @dat_cycle<'2025-01-01'
------------begin
drop table if exists #meat_grill
drop table if exists #fish
drop table if exists #dovid
drop table if exists #result0
drop table if exists #result

declare @date date='2025-05-01' --'2023-01-31'  --getdate()-1  ------------@dat_cycle
declare @year int=year(@date)
declare @month int=month(@date)
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


------------	set @dat_cycle=dateadd(month,1,@dat_cycle)
------------	end