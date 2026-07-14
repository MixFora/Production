from sqlalchemy import create_engine, text
from sqlalchemy.types import Numeric, NVARCHAR, FLOAT
import urllib
import re
import pandas as pd
import src.prod.conn as conn
from IPython.display import display
import win32com.client as win32
import numpy as np

pd.set_option('display.max_rows', None)
pd.set_option('display.max_columns', None)

file_path = "labor_2604.xlsx"

labor_role_columns = [
    "посада з годин", "Посада з зп", "depid", "Відділ"
]

actual_labor_tariff_columns = [
    "№ магазина", "адреса",	"посада	вартість години без податків з 04_26", "вартість години з податками з 04_26"
]

conect = conn.SQLServer()


file_path_roles = "Посади.xlsx"
file_path_tariff = "actual_labor_tariff.xlsx"
engine = conect.connector_engine_BA

year, month = conect.get_year_month(file_path)


sql_list, column_names, all_oper_104_105, hist_table, sql_schema = conect.labor()

column_names = [''.join(x.lower().split()) for x in column_names]
sql_list = [''.join(x.lower().split()) for x in sql_list]


main_df = pd.read_excel(
    file_path,
    sheet_name=0
)


if "category" in main_df.columns:
    main_df = main_df.rename(columns={"category": "region"})

main_df.columns = [''.join(x.lower().split()) for x in main_df.columns]
main_df = (
    main_df
    .groupby(
        ["filid", "mm", "region", "filialname"],
        as_index=False
    )
    .agg({
        "h": "sum"
    })
)
display(main_df.head(10))

roles_df = pd.read_excel(
    file_path_roles,
    sheet_name=0
)

roles_df = roles_df.rename(columns={"посада з годин": "region"})


tariff_df = pd.read_excel(
    file_path_tariff,
    sheet_name=0
)

tariff_df = tariff_df.rename(columns={"№ магазина": "AccountantNumber"})


df_filials = conect.accountant_number_of_filial(engine)


df_filials["AccountantNumber"] = (
    pd.to_numeric(
        df_filials["AccountantNumber"],
        errors="coerce"
    )
    .astype("Int64")
)

df_filials = df_filials.rename(columns={"id": "filid"})


tariff_df = tariff_df.merge(
    df_filials[["AccountantNumber", "filid"]],
    on="AccountantNumber",
    how="left"
)

role_average_df=tariff_df.groupby("посада")["вартість години з податками з 04_26"].mean()

print(role_average_df)

tariff_df = tariff_df.rename(columns={"посада": "Посада з зп"})

main_df = main_df.merge(
    roles_df[["region", "Посада з зп", "depid", "Відділ"]],
    on=["region"],
    how="left"
)

main_df = main_df.merge(
    tariff_df[["filid", "Посада з зп", "вартість години з податками з 04_26"]],
    on=["Посада з зп", "filid"],
    how="left"
)


# display(
#     main_df[main_df["вартість години з податками з 04_26"].isna()]
# )
# print(main_df["вартість години з податками з 04_26"].mean())
main_df["вартість години з податками з 04_26"] = (
    main_df["вартість години з податками з 04_26"]
    .fillna(main_df["Посада з зп"].map(role_average_df))
)
main_df["cost_labor"]=main_df["вартість години з податками з 04_26"]*main_df["h"]
print(main_df.loc[main_df["region"] == "Кулінарія/Гриль", "вартість години з податками з 04_26"].mean())#194.00272031925505
print(main_df.loc[main_df["region"] == "Кулінарія/Гриль", "cost_labor"].sum())#101433019.035
print(main_df.loc[main_df["region"] == "Кулінарія/Гриль", "h"].sum())#517615.6

print(main_df.loc[
        main_df["region"] != "Кулінарія/Гриль",
        "вартість години з податками з 04_26"
    ].describe())

main_df_104_105 = main_df[main_df["region"] == "Кулінарія/Гриль"]
display(main_df_104_105.head(10))


df_104_105 = pd.read_sql(
    all_oper_104_105,
    engine,
    params={
        "year": year,
        "month": month
    }
)

main_df_104_105 = main_df_104_105.merge(
    df_104_105[["filid", "depid", "sumout_dep", "sumout_filial"]],
    on=["filid"],
    how="left"
)


main_df_104_105["hours_dep"] = np.where(
    main_df_104_105["sumout_filial"] == 0,
    0,
    main_df_104_105["h"] * main_df_104_105["sumout_dep"] / main_df_104_105["sumout_filial"]
)
main_df_104_105["cost_labor_dep"]=main_df_104_105["вартість години з податками з 04_26"]*main_df_104_105["hours_dep"]


main_df_104_105["h"] = main_df_104_105["hours_dep"]
main_df_104_105["depid_x"] = main_df_104_105["depid_y"]
main_df_104_105["cost_labor"] = main_df_104_105["cost_labor_dep"]

main_df_104_105=main_df_104_105.drop(columns=["depid_y", "sumout_dep", "sumout_filial", "hours_dep", "cost_labor_dep"])
main_df_104_105=main_df_104_105.rename(columns={"depid_x": "depid"})

main_df_104_105=main_df_104_105.rename(columns={
    "вартість години з податками з 04_26": "cost_hour",
    "h" : "hours"
})
display(main_df_104_105.head(6))
main_df = main_df[main_df["depid"] != "104_105"]
main_df=main_df.rename(columns={
    "вартість години з податками з 04_26": "cost_hour",
    "h" : "hours"
})
display(main_df.head(6))
main_df = pd.concat([main_df, main_df_104_105], ignore_index=True)
main_df = main_df.drop(columns=["region", "filialname", "Посада з зп", "Відділ"])
main_df.insert(0, "y", year)
cols = list(main_df.columns)
cols.remove("filid")      # прибрати зі старого місця
cols.insert(2, "filid")   # вставити на 5-те місце
cols.remove("depid")
cols.insert(3, "depid")
cols.remove("cost_hour")
cols.insert(5, "cost_hour")
cols.remove("cost_labor")
cols.insert(6, "cost_labor")
main_df = main_df[cols]

main_df.columns = main_df.columns.str.lower()
main_df = main_df.rename(columns={"mm": "m"})

groupby_columns = ["filid", "depid"]
avg_cols = ["cost_hour"]
sql_list_sumable = [x for x in sql_list if x not in ["filid", "depid", "y", "m", "cost_hour"]]


anomalies_df = conect.find_anomalies(year, month, main_df, hist_table, sql_list_sumable, groupby_columns=groupby_columns, THRESHOLD_PCT=1.0, engine=engine, year_col="y", month_col="m", avg_cols=avg_cols)
conect.send_mail(anomalies_df, year, month, count_of_fema_unique_columns=[], missing_columns=[], duplicates=[], name_of_report="LABOR")

conect.load_to_sql(main_df, year, month, table_name="labor_python_test", table_schema="prod", sql_schema=sql_schema, engine=engine, year_col="y", month_col="m")

# # 1. перевірити чи таблиця є
# with engine.connect() as conn:
#     exists = conn.execute(text("""
#         SELECT OBJECT_ID('prod.labor_python_test', 'U')
#     """)).scalar()
#
# # 2. тільки якщо є — delete
# if exists:
#     with engine.begin() as conn:
#         conn.execute(text("""
#             DELETE FROM prod.labor_python_test
#             WHERE [mm] = :month
#         """), {"month": month})
#
# main_df.to_sql(
#     "labor_python_test",
#     engine,
#     schema="prod",
#     if_exists="append",
#     index=False
# )

# main_df_104_105.to_sql(
#     "labor_python_test",
#     engine,
#     schema="prod",
#     if_exists="append",
#     index=False
# )