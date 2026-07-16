
from sqlalchemy import create_engine, text
from sqlalchemy.types import Numeric, NVARCHAR, FLOAT
import urllib
import re
import pandas as pd
import src.prod.conn as conn
from IPython.display import display
import win32com.client as win32

conect = conn.SQLServer()

file_path = "fema_2604.xlsx"
engine = conect.connector_engine_BA

year, month = conect.get_year_month(file_path)


pd.set_option('display.max_rows', None)
pd.set_option('display.max_columns', None)


sql_dict, column_names, hist_table, sql_schema = conect.fema()

column_names = [''.join(x.lower().split()) for x in column_names]

sql_dict = {
    key: [''.join(col.lower().split()) for col in cols]
    for key, cols in sql_dict.items()
}
df = pd.read_excel(
    file_path,
    sheet_name=0
)
df["Дата"] = pd.to_datetime(df["Дата"])

df = df[
    (df["Дата"].dt.year == year) &
    (df["Дата"].dt.month == month)
]
df.columns = [''.join(x.lower().split()) for x in df.columns]

all_sql_columns = [
    col
    for cols in sql_dict.values()
    for col in cols
]

count_of_fema_unique_columns = (
    pd.Series([col for col in df.columns if col in all_sql_columns])
    .value_counts()
)

print("\nКолонки, які зустрічаються декілька разів у файлі Феми: \n")
print(count_of_fema_unique_columns[count_of_fema_unique_columns > 1])
missing_columns = [col for col in column_names if col not in df.columns]

print("\nВідсутні колонки:")
print(missing_columns)

# залишаємо тільки потрібні колонки
df = df[[col for col in column_names if col in df.columns]]

# групуємо дублікати колонок і сумуємо їх
df = df.T.groupby(level=0).sum().T
#display(df[df['магазин'] == '002, Київ, пр. Ак.Вернадського 16 (Рефіт)'])
duplicates = df.columns[df.columns.duplicated()]


print("\nДублі після групування (їх не має бути): \n")
print(list(duplicates))

# видалити рядки у яких всі числові колонки - нульові (потенційні дублі) і в назві є "(Оренда)"
cols = [col for col in column_names if col in df.columns]

tmp = (
    df[cols]
    .replace(r'^\s*$', None, regex=True)
    .apply(pd.to_numeric, errors='coerce')
    .fillna(0)
)

mask = (
    tmp.eq(0).all(axis=1)
    & df['магазин'].str.contains(r'\(Оренда\)', na=False)
)

df = df.loc[~mask]



df_filials = conect.accountant_number_of_filial(engine)
# беремо код магазину до першої коми та прибираємо пробіли
df["AccountantNumber"] = (
    pd.to_numeric(
        df["магазин"]
        .str.split(",").str[0]
        .str.replace(" ", "", regex=False),
        errors="coerce"
    )
    .astype("Int64")
)

# join з довідником філіалів
df = df.merge(
    df_filials[["AccountantNumber", "id"]],
    on="AccountantNumber",
    how="left"
)


missing_shops = df.loc[df["id"].isna(), "магазин"]

print(f"\nНе знайдено {len(missing_shops)} магазинів: \n")
print(*missing_shops.tolist(), sep="\n")


result = {}

for key, cols in sql_dict.items():
    existing_cols = [col for col in cols if col in df.columns]

    if existing_cols:
        result[key] = df[existing_cols].sum(axis=1)
    else:
        result[key] = 0

df_final = pd.DataFrame(result)

df_final.insert(0, "filid", df["id"])
df_final.insert(0, "month", month)
df_final.insert(0, "year", year)

df_final = df_final.dropna(subset=["filid"])
df_final["filid"] = df_final["filid"].astype(int)

print("\n")
print("Пиццерия:", df_final['Пиццерия'].sum())
print("Стрит - Фуд:", df_final['Стрит-Фуд'].sum())
print("Пекарня:", df_final['Пекарня'].sum())
print("Допёк:", df_final['Допёк'].sum())
print("Гриль:", df_final['Гриль'].sum())


fema_sql_cols = list(sql_dict.keys())
groupby_columns = ["filid"]
# ===== Перевірка на аномалії перед заливанням =====
anomalies_df = conect.find_anomalies(year, month, df_final, hist_table, fema_sql_cols, groupby_columns=groupby_columns, THRESHOLD_PCT=1.0, engine=engine)
conect.send_mail(anomalies_df, year, month, count_of_fema_unique_columns, missing_columns, duplicates, "ФЕМА")
# При завантаженні результатів в БД групувємо по місяцю-року-філіду(id)
sum_cols = [
    "Пиццерия",
    "Стрит-Фуд",
    "Пекарня",
    "Допёк",
    "Гриль"
]

for col in sum_cols:
    df_final[col] = pd.to_numeric(
        df_final[col].astype(str).str.replace(",", ".", regex=False),
        errors="coerce"
    ).fillna(0)

df_final = (
    df_final
    .groupby(["year", "month", "filid"], as_index=False)[sum_cols]
    .sum()
)

# hist_query_fema = f"""
#             SELECT
#                 filid as id,
#                 year,
#                 month,
#                 {sum_cols}
#             FROM {RESULT_TABLE}
#             WHERE {periods_filter}
#             GROUP BY filid, year, month
#         """

# Завантаження в БД
conect.load_to_sql(df_final, year, month, table_name="temp", table_schema="prod", sql_schema=sql_schema,engine=engine)

# Визначаємо попередні 3 місяці (з урахуванням переходу через рік)
# prev_periods = []
# y, m = year, month
# for _ in range(3):
#     m -= 1
#     if m == 0:
#         m = 12
#         y -= 1
#     prev_periods.append((y, m))
#
#
# RESULT_TABLE = "Business_Analytic.prod.temp"
# categories = list(sql_dict.keys())
#
# periods_filter = " OR ".join(f"(year={y} AND month={m})" for y, m in prev_periods)
#
# sum_cols = ", ".join(f"sum([{c}]) as [{c}]" for c in categories)
#
# hist_query = f"""
#     SELECT
#         filid as id,
#         year,
#         month,
#         {sum_cols}
#     FROM {RESULT_TABLE}
#     WHERE {periods_filter}
#     GROUP BY filid, year, month
# """
#
# with engine.connect() as conn:
#     df_hist = pd.read_sql(hist_query, engine)
#
# THRESHOLD_PCT = 1.0  # допустиме відхилення 100%
#
# anomalies = []
#
# # середнє по кожній категорії по всіх магазинах за попередні 3 місяці
# global_avg = df_hist[categories].mean()
# hist_grouped = df_hist.groupby("id")
#
# for _, row in df_final.iterrows():
#     fid = row["id"]
#     hist_id = hist_grouped.get_group(fid) if fid in hist_grouped.groups else None
#
#     for cat in categories:
#         cur_val = row[cat]
#         reasons = []
#
#         if hist_id is not None:
#             hist_vals = hist_id[cat].values
#             # ---- умова 1: вище за середнє по всіх магазинах за попередні місяці ----
#             avg_all = global_avg[cat]
#             if avg_all != 0 and cur_val > avg_all * (1 + THRESHOLD_PCT):
#                 reasons.append("вище середнього по всіх магазинах більше ніж вдвічі")
#                 # ---- умова 2: зростання відносно власної історії магазину,
#                 #                якщо всі 3 попередні місяці не нульові ----
#                 if len(hist_vals) == 3 and all(v != 0 for v in hist_vals):
#                     hist_mean = hist_vals.mean()
#                     if hist_mean != 0 and (cur_val - hist_mean) / hist_mean > THRESHOLD_PCT:
#                         reasons.append("вище власної історії більше ніж вдвічі")
#
#         if reasons:
#             anomalies.append({
#                 "id": fid,
#                 "категорія": cat,
#                 "поточне": cur_val,
#                 "сер._3міс_магазин": round(hist_id[cat].mean(), 2) if hist_id is not None else None,
#                 "сер._по_всіх_магазинах": round(avg_all, 2),
#                 "причина": ", ".join(reasons),
#             })
#
# if anomalies:
#     anomalies_df = pd.DataFrame(anomalies)
#     anomalies_df = anomalies_df[anomalies_df["причина"] == "вище середнього по всіх магазинах більше ніж вдвічі, вище власної історії більше ніж вдвічі"]
#     print("\n⚠️ Знайдено аномалії:")
#     display(anomalies_df)
#
# else:
#     print("\nАномалій не знайдено, можна заливати дані.")



#
# mail_To = "i.sukhovii@fora.ua"
# outlook = win32.Dispatch('Outlook.Application')
# mail = outlook.CreateItem(0)
#
# mail.To = "i.sukhovii@fora.ua"
# mail.Subject = f"Звіт по ФЕМА {month}.{year}"
#
# # таблиця аномалій
# if len(anomalies_df) > 0:
#     anomalies_html = anomalies_df.to_html(index=False)
#     anomaly_text = "⚠️ Знайдено аномалії:"
# else:
#     anomalies_html = ""
#     anomaly_text = "✅ Аномалій не знайдено, можна заливати дані."
#
#
# # дублікати колонок
# duplicate_columns = counts[counts > 1]
#
# if len(duplicate_columns) > 0:
#     duplicate_columns_html = duplicate_columns.to_frame("Кількість").to_html()
# else:
#     duplicate_columns_html = "Немає"
#
#
# # відсутні колонки
# if missing_columns:
#     missing_html = "<br>".join(missing_columns)
# else:
#     missing_html = "Немає"
#
#
# # дублікати після групування
# if len(duplicates) > 0:
#     duplicates_html = duplicates.to_frame("Кількість").to_html()
# else:
#     duplicates_html = "Немає"
#
# mail.HTMLBody = f"""
# <html>
# <body>
#
# <h3>{anomaly_text}</h3>
#
# {anomalies_html}
#
# <hr>
#
# <h3>Перевірка файлу Феми</h3>
#
# <b>Колонки, які зустрічаються декілька разів:</b><br>
# {duplicate_columns_html}
#
# <br><br>
#
# <b>Відсутні колонки:</b><br>
# {missing_html}
#
# <br><br>
#
# <b>Дублі після групування (їх не має бути):</b><br>
# {duplicates_html}
#
# <br><br>
# <p>Автоматичний звіт.</p>
#
# </body>
# </html>
# """
# mail.Send()


# with engine.connect() as conn:
#     exists = conn.execute(text("""
#         SELECT OBJECT_ID('prod.temp_python_test', 'U')
#     """)).scalar()
#
# if exists:
#     with engine.begin() as conn:
#         conn.execute(text("""
#             DELETE FROM prod.temp_python_test
#             WHERE [year] = :year
#               AND [month] = :month
#         """), {"year": year, "month": month})
#
# df_final.to_sql(
#     "temp_python_test",
#     engine,
#     schema="prod",
#     if_exists="append",
#     index=False,
#     dtype=sql_schema
# )