from sqlalchemy.types import Integer, Float, NVARCHAR, Numeric

fema_sql_schema = {
    "year": Integer(),
    "month": Integer(),
    "id": Integer(),
    "Пиццерия": Float(),
    "Стрит-Фуд": Float(),
    "Пекарня": Float(),
    "Допёк": Float(),
    "Гриль": Float(),
}

tariff_sql_schema = {
    "MVZ": NVARCHAR(50),
    "year": Integer(),
    "month": Integer(),
    "Consump_kwt": Float(),
    "Consump_UAH": Float(),
    "Tariff": Float(),
}

account_sql_schema = {
    "filid": Integer(),
    "account": Integer(),
    "name": NVARCHAR(200),
    "year": Integer(),
    "month": Integer(),
    "sum": Float(),
    "share_TO": Float(),
}


labor_sql_schema = {
    "y": Integer(),
    "m": Integer(),
    "filid": Integer(),
    "Depid": Integer(),
    "hours": Float(),
    "cost_hour": Float(),
    "cost_labor": Float()
}

costsrc_sql_schema = {
    "year" : Integer(),
    "month" : Integer(),
    "ym" : Integer(),
    "rcid" : Integer(),
    "postid" : Integer(),
    "lagerid" : Integer(),
    "costs_logistics" : Float(),
    "costsOther" : Float(),
    "costs" : Float(),

}

costsmc_sql_schema = {
    "year" : Integer(),
    "month" : Integer(),
    "ym" : Integer(),
    "rcid" : Integer(),
    "filid" : Integer(),
    "lagerid" : Integer(),
    "Proekt" : NVARCHAR(8),
    "costs" : Numeric(12, 2),

}

class Schema:
    def __init__(self):
        self.costsrc=costsrc_sql_schema
        self.costsmc=costsmc_sql_schema
        self.tariff=tariff_sql_schema
        self.fema=fema_sql_schema
        self.labor=labor_sql_schema