import pandas as pd
import numpy as np
import src.prod.conn as conn
conect = conn.SQLServer()

file_path = "accounts_2604.xlsx"
year, month = conect.get_year_month(file_path)
engine = conect.connector_engine_BA
sql_list, hist_table, sql_schema = conect.accounts()

df = pd.read_excel(file_path)

# рядки-статті
mask840 = df["Стаття/МВЗ"].astype(str).str.startswith("840")

# запам'ятовуємо останній код і назву 840
# Стаття
df["article"] = np.where(mask840, df["Стаття/МВЗ"], np.nan)

# MVZ
df["MVZ"] = np.where(~mask840, df["Стаття/МВЗ"], np.nan)
df["article_name"] = np.where(mask840, df["Назва"], np.nan)

# поширюємо вниз
df["article"] = df["article"].ffill()
df["article_name"] = np.where(mask840, df["Назва"], np.nan)
df["article_name"] = df["article_name"].ffill()

# залишаємо тільки підлеглі рядки
result = df[~mask840].copy()

# додаємо рік і місяць
result["year"] = year
result["month"] = month

# залишаємо потрібні колонки
result = result[[
    "article",
    "article_name",
    "MVZ",
    "year",
    "month",
    "uah",
    "percent"
]]

print(result)

# Перетворюємо uah у число
result["uah"] = (
    result["uah"]
    .astype(str)
    .str.replace("UAH", "", regex=False)
    .str.replace(" ", "", regex=False)
    .replace("", None)
    .astype(float)
)
result["MVZ"] = result["MVZ"].astype(str).str.strip()

# Сума по статті
result_sum = (
    result
    .groupby(["article", "article_name", "year", "month"], as_index=False)["uah"]
    .sum()
)

print(result_sum)

df_filials = conect.accountant_number_of_filial(engine)
df_filials["MVZ"] = df_filials["MVZ"].astype(str).str.strip()

# join з довідником філіалів
result = result.merge(
    df_filials[["MVZ", "id"]],
    on="MVZ",
    how="left"
)

result = (
    result.rename(columns={"id": "filid"})
          .dropna(subset=["filid"])
)

result["filid"] = result["filid"].astype(int)
result = result.rename(columns={"article": "account"})
result = result.rename(columns={"uah": "sum"})
result = result.rename(columns={"article_name": "name"})
result = result.rename(columns={"percent": "share_TO"})
result = (
    result
    .groupby(
        ["filid", "account", "name", "year", "month"],
        as_index=False
    )
    .agg(
        sum=("sum", "sum"),
        share_TO=("share_TO", "first")
    )
)
result = result[list(sql_schema.keys())]
sum_sql_list = ["sum"]
result.to_excel("result.xlsx", index=False)
groupby_columns = ["filid", "account"]
anomalies_df = conect.find_anomalies(year, month, result, hist_table, sum_sql_list, groupby_columns=groupby_columns, THRESHOLD_PCT=1.0, avg_cols=["share_TO"], engine=engine)
conect.send_mail(anomalies_df, year, month, count_of_fema_unique_columns=[], missing_columns=[], duplicates=[], name_of_report="ACCOUNTS")

groupby_columns = ["filid"]
anomalies_df = conect.find_anomalies(year, month, result, hist_table, sum_sql_list, groupby_columns=groupby_columns, avg_cols=["share_TO"], THRESHOLD_PCT=1.0, engine=engine)
conect.send_mail(anomalies_df, year, month, count_of_fema_unique_columns=[], missing_columns=[], duplicates=[], name_of_report="ACCOUNTS")
conect.load_to_sql(result, year, month, table_name="account", table_schema="prod", sql_schema=sql_schema,engine=engine)
