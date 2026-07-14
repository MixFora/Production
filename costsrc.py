from sqlalchemy import create_engine, text
import urllib


params = urllib.parse.quote_plus(
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=sfpv-sqls063;"
    "DATABASE=Business_Analytic;"
    "Trusted_Connection=yes;"
)

engine = create_engine("mssql+pyodbc:///?odbc_connect=" + params)

with engine.connect() as conn:
    result = conn.execute(text("SELECT TOP (5) * FROM Business_Analytic.prod.costsRC"))

    for row in result:
        print(row)

import pandas as pd

file_path = "RC_2603.csv"

df = pd.read_csv(file_path)

print(df.head())