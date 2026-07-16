from sqlalchemy import create_engine, text
from sqlalchemy.types import Numeric, NVARCHAR, FLOAT
import urllib
import re
import pandas as pd
import src.prod.conn as conn
from IPython.display import display
import win32com.client as win32
import numpy as np

conect = conn.SQLServer()

file_path = "tariff_2604.xlsx"
engine = conect.connector_engine_BA

year, month = conect.get_year_month(file_path)


pd.set_option('display.max_rows', None)
pd.set_option('display.max_columns', None)

sql_list, column_names, hist_table, sql_schema = conect.tariff()

column_names = [''.join(x.lower().split()) for x in column_names]
sql_list = [''.join(x.lower().split()) for x in sql_list]


df = pd.read_excel(
    file_path,
    sheet_name=0
)

df.columns = [''.join(x.strip(" '").lower().split()) for x in df.columns]


df = df.groupby(
    ["мвз(код)"],
    as_index=False
)[["kwt", "uah"]].sum()

# print(df["kwt"].sum())
#
# print(df["uah"].sum())

df["uah"]=df["uah"]*1.2

df["tariff"] = np.where(
    df["kwt"] != 0,
    df["uah"] / df["kwt"],
    0
)
# print(df.loc[df["tariff"] != 0, "tariff"].mean())


df["year"]=year
df["month"]=month

df = df[
    ["мвз(код)", "year", "month", "kwt", "uah", "tariff"]
]

df = df[
    df["мвз(код)"].notna() &
    (df["мвз(код)"].astype(str).str.strip().ne("")) &
    (df["мвз(код)"].astype(str).str.strip() != "-")
]


df = df.rename(columns={"мвз(код)": "MVZ"})
df = df.rename(columns={"kwt": "Consump_kwt"})
df = df.rename(columns={"uah": "Consump_UAH"})

df.columns = df.columns.str.lower()

groupby_columns = ["mvz"]
sql_list_sumable = [x for x in sql_list if x not in ["mvz", "year", "month"]]

anomalies_df = conect.find_anomalies(year, month, df, hist_table, sql_list_sumable, groupby_columns=groupby_columns, THRESHOLD_PCT=1.0, engine=engine)
conect.send_mail(anomalies_df, year, month, count_of_fema_unique_columns=[], missing_columns=[], duplicates=[], name_of_report="ЕЛЕКТРО ТАРИФ")

conect.load_to_sql(df, year, month, table_name="electro_tariff", table_schema="prod", sql_schema=sql_schema, engine=engine)
