fema_sql_dict = {
    "Пиццерия": ['пічпіца', 'пічпіца1', 'пічпіца2', 'тепловавітрина1', 'щспіца'],

    "Допёк": ['ПКВ допік'],

    "Гриль": ['Витяжка ПКВ', 'ПКВ', 'ПКВ гриль', 'ПКВ копчення', 'ПКВ піч', 'Теплова вітрина2'],

    "Стрит-Фуд": ['Гриль шаурма'],

    "Пекарня": ['ЩС пекарня']
}

fema_column_names = [
"Дата",	"Час",	"Магазин",	"Витяжка ПКВ",	"Гриль шаурма",	"Ел. плита",
"Модульна піч",	"ПКВ",	"ПКВ гриль",	"ПКВ допік",	"ПКВ копчення",	"ПКВ піч",
"Піч піца",	"Піч піца1",	"Піч піца2",	"Розстоєчна шафа",	"Ротаційна піч",	"Тензометрія ПКВ",
"Тензометрія ПКВ гриль",	"Тензометрія ПКВ допік",	"Тензометрія ПКВ копчення",	"Тензометрія Теплова вітрина",
"Тензометрія Теплова вітрина1",	"Тензометрія Теплова вітрина2",	"Теплова вітрина",
"Теплова вітрина1",	"Теплова вітрина2",	"ЩС Піца",	"ЩС пекарня"
]

costsrc_sql_list = [
    "year", "month", "ym", "rcid", "postid", "lagerid", "costsLogistics", "costsOther", "costs"
]

costsmc_sql_list = [
    "year", "month", "ym", "rcid", "filid", "lagerid", "proekt", "costs"
]

tariff_sql_list = [
   "MVZ", "year", "month", "Consump_kwt", "Consump_UAH", "Tariff"
]

tariff_column_names = [
    "МВЗ (Код)", "Место возникновения затрат", "kwt", "uah"
]


labor_columns = [
    "filid", "mm", "h",	"region", "filialname"
]

sql_labor_columns = [
    "y", "m", "filid", "hours", "cost_hour", "cost_labor"
]

class ColumnsArchive:
    def __init__(self):
        self.fema_sql_dict = fema_sql_dict
        self.fema_column_names = fema_column_names
        self.costsrc_sql_list = costsrc_sql_list
        self.costsmc_sql_list = costsmc_sql_list
        self.tariff_sql_list = tariff_sql_list
        self.tariff_column_names = tariff_column_names
        self.labor_columns = labor_columns
        self.sql_labor_columns = sql_labor_columns