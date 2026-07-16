from sqlalchemy import create_engine, text
import urllib
import src.prod.conn as conn
import pandas as pd

pd.set_option('display.max_rows', None)
pd.set_option('display.max_columns', None)

conect = conn.SQLServer()

file_path = "RC_2605.csv"
engine = conect.connector_engine_BA

year, month = conect.get_year_month(file_path)

sql_list, hist_table, sql_schema = conect.costsrc()


df = pd.read_csv(
    file_path,
    sep=";",
    header=None,   # важливо! бо в файлі нема заголовків
    names=sql_list
)


groupby_columns = ["year", "month", "ym", "rcid", "postid", "lagerid"]
sql_list_sumable = ["costsLogistics", "costsOther"]
df = df.groupby(
    groupby_columns,
    as_index=False
)[sql_list_sumable].sum()

df["costs"] = df["costsLogistics"].fillna(0) + df["costsOther"].fillna(0)
sql_list_sumable.append("costs")
groupby_columns.remove("year")
groupby_columns.remove("month")


anomalies_df = conect.find_anomalies(year, month, df, hist_table, sql_list_sumable, groupby_columns=groupby_columns, THRESHOLD_PCT=1.0, engine=engine)
conect.send_mail(anomalies_df, year, month, count_of_fema_unique_columns=[], missing_columns=[], duplicates=[], name_of_report="COSTS RC")

conect.load_to_sql(df, year, month, table_name="costsrc", table_schema="prod", sql_schema=sql_schema, engine=engine)
