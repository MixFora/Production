from sqlalchemy import create_engine, text
from sqlalchemy.types import Numeric, NVARCHAR
import urllib
import re
import pandas as pd
import src.prod.conn as conn
conect = conn.SQLServer()

file_path = "MC_2605.csv"
engine = conect.connector_engine_BA

year, month = conect.get_year_month(file_path)

sql_list, hist_table, sql_schema = conect.costsmc()



pd.set_option('display.max_rows', None)
pd.set_option('display.max_columns', None)


df = pd.read_csv(
    file_path,
    sep=";",
    header=None,   # важливо! бо в файлі нема заголовків
    names=sql_list,
    encoding="utf-8-sig" #кодування кириличних символів
)


groupby_columns = ["year", "month", "ym", "rcid", "filid", "lagerid", "proekt"]
sql_list_sumable = ["costs"]
df = df.groupby(
    groupby_columns,
    as_index=False
)[sql_list_sumable].sum()

groupby_columns.remove("year")
groupby_columns.remove("month")

anomalies_df = conect.find_anomalies(year, month, df, hist_table, sql_list_sumable, groupby_columns=groupby_columns, THRESHOLD_PCT=1.0, engine=engine)
conect.send_mail(anomalies_df, year, month, count_of_fema_unique_columns=[], missing_columns=[], duplicates=[], name_of_report="COSTS MC")

conect.load_to_sql(df, year, month, table_name="costsmc_python_test", table_schema="prod", sql_schema=sql_schema, engine=engine)


# # delete old data
# # 1. перевірити чи таблиця є
# with engine.connect() as conn:
#     exists = conn.execute(text("""
#         SELECT OBJECT_ID('prod.costsmc_python_test', 'U')
#     """)).scalar()
#
# # 2. тільки якщо є — delete
# if exists:
#     with engine.begin() as conn:
#         conn.execute(text("""
#             DELETE FROM prod.costsmc_python_test
#             WHERE [year] = :year
#               AND [month] = :month
#         """), {"year": year, "month": month})
#
# df.to_sql(
#     "costsmc_python_test",
#     engine,
#     schema="prod",
#     if_exists="append",
#     index=False,
#     dtype={
#         "costs": Numeric(12, 2),
#         "proekt": NVARCHAR(8)
#     }
# )