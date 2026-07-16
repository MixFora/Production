from sqlalchemy import create_engine
import urllib
from datetime import datetime
from calendar import monthrange
from sqlalchemy import text
import pandas as pd
from IPython.display import display
import win32com.client as win32
from sqlalchemy.types import Integer, Float, NVARCHAR, Numeric
import src.prod.prod_tables_schemas as prod_schemas
import src.prod.prod_columns_archive as prod_columns_archive
import re
# GETDATE()
now = datetime.now()

# YEAR(GETDATE())
year = now.year

# MONTH(GETDATE())
month = now.month

# DATEFROMPARTS(year, month, 1)
first_day = datetime(year, month, 1).strftime("%Y-%m-%d")

# EOMONTH(GETDATE())
last_day = datetime(year, month, monthrange(year, month)[1]).strftime("%Y-%m-%d")

# номер дня тижня
# понеділок = 1, неділя = 7
weekday_num = now.isoweekday()

# назва дня
weekday_name = now.strftime("%A")

params_BA = urllib.parse.quote_plus(
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=sfpv-sqls063;"
    "DATABASE=Business_Analytic;"
    "Trusted_Connection=yes;"
)

engine_BA = create_engine("mssql+pyodbc:///?odbc_connect=" + params_BA)




class SQLServer:
    def __init__(self):
        self.year=year
        self.month=month
        self.first_day=first_day
        self.last_day=last_day
        self.getdate=now.strftime("%Y-%m-%d")
        self.weekday_name=weekday_name
        self.weekday_number=weekday_num
        self.ym=now.strftime("%Y%m")
        self.connector_engine_BA = engine_BA

    def fema(self):
        hist_table = "Business_Analytic.prod.temp"
        return prod_columns_archive.fema_sql_dict, prod_columns_archive.fema_column_names, hist_table, prod_schemas.fema_sql_schema

    def tariff(self):
        hist_table = "Business_Analytic.prod.electro_tariff"
        return prod_columns_archive.tariff_sql_list, prod_columns_archive.tariff_column_names, hist_table, prod_schemas.tariff_sql_schema

    def labor(self):
        hist_table = "Business_Analytic.prod.labor"

        return prod_columns_archive.sql_labor_columns, prod_columns_archive.labor_columns, labor_104_105_sql, hist_table, prod_schemas.labor_sql_schema

    def costsrc(self):
        hist_table = "Business_Analytic.prod.costsRC"
        return prod_columns_archive.costsrc_sql_list, hist_table, prod_schemas.costsrc_sql_schema

    def costsmc(self):
        hist_table = "Business_Analytic.prod.costsMC"
        return prod_columns_archive.costsmc_sql_list, hist_table, prod_schemas.costsmc_sql_schema

    def accounts(self):
        hist_table = "Business_Analytic.prod.account"
        return prod_columns_archive.account_sql_list, hist_table, prod_schemas.account_sql_schema


    def get_year_month(self, file_path):
        match = re.search(r'(\d{4})', file_path)

        if match:
            ym = match.group(1)

            year = 2000 + int(ym[:2])
            month = int(ym[2:])

            print("Year: ", year)
            print("Month: ", month)

        return year, month

    def accountant_number_of_filial(self, engine=None):
        with engine.connect() as conn:
            query = "SELECT  [id],[name],[AccountantNumber], MVZ FROM [FORAExperts].[dbo].[Filialparams]"

            df_filials = pd.read_sql(query, engine)

        df_filials["AccountantNumber"] = (
            pd.to_numeric(
                df_filials["AccountantNumber"],
                errors="coerce"
            )
            .astype("Int64")
        )

        return df_filials

    def load_to_sql(self, df_final, year, month, table_name, table_schema, sql_schema, engine=None, year_col="year", month_col="month"):
        # Завантаження в БД
        if engine is None:
            engine = self.connector_engine_BA

        with engine.connect() as conn:
            exists = conn.execute(text(f"""
                SELECT OBJECT_ID('{table_schema}.{table_name}', 'U')
            """)).scalar()

        if exists:
            with engine.begin() as conn:
                conn.execute(text(f"""
                    DELETE FROM {table_schema}.{table_name}
                    WHERE [{year_col}] = :year
                      AND [{month_col}] = :month
                """), {"year": year, "month": month})

        df_final.to_sql(
            table_name,
            engine,
            schema=table_schema,
            if_exists="append",
            index=False,
            dtype=sql_schema
        )

        return 0

    def find_anomalies(self, year, month, new_month_df, hist_table, hist_table_columns, groupby_columns, THRESHOLD_PCT=1.0, engine=None, year_col="year", month_col="month", avg_cols=[" "]):
        # Визначаємо попередні 3 місяці (з урахуванням переходу через рік)
        prev_periods = []
        y, m = year, month
        for _ in range(3):
            m -= 1
            if m == 0:
                m = 12
                y -= 1
            prev_periods.append((y, m))

        RESULT_TABLE = hist_table  # "Business_Analytic.prod.temp"
        categories = hist_table_columns  # list(sql_dict.keys())

        periods_filter = " OR ".join(f"({year_col}={y} AND {month_col}={m})" for y, m in prev_periods)
        groupby_cols_sql = ", ".join(groupby_columns)
        if avg_cols and avg_cols[0] != " ":
            avg_cols_sql = ", " + ", ".join(f"AVG([{c}]) AS [{c}]" for c in avg_cols)
        else:
            avg_cols_sql = ""
        sql_cols = ", ".join(f"sum([{c}]) as [{c}]" for c in categories)

        hist_query = f"""
            SELECT {groupby_cols_sql}, {year_col}, {month_col},
                {sql_cols}{avg_cols_sql}
            FROM {RESULT_TABLE}
            WHERE {periods_filter}
            GROUP BY {groupby_cols_sql}, {year_col}, {month_col}
        """

        if engine is None:
            engine = self.connector_engine_BA

        with engine.connect() as conn:
            df_hist = pd.read_sql(hist_query, engine)

        #THRESHOLD_PCT = 1.0  # допустиме відхилення 100%

        anomalies = []
        anomalies_list = []
        missing_filids = []

        # середнє по кожній категорії по всіх магазинах за попередні 3 місяці
        global_avg = df_hist[categories].mean()
        # Формуємо ключ для пошуку групи
        if len(groupby_columns) == 1:
            hist_grouped = df_hist.groupby(groupby_columns[0])  # not the list!
        else:
            hist_grouped = df_hist.groupby(groupby_columns)

        for _, row in new_month_df.iterrows():
                # fid = row[groupby_columns]
                # group_key потрібно рахувати для кожного рядка окремо
                if len(groupby_columns) == 1:
                    group_key = row[groupby_columns[0]]
                else:
                    group_key = tuple(row[col] for col in groupby_columns)

                try:
                    hist_id = hist_grouped.get_group(group_key)
                except KeyError:
                    missing_filids.append(group_key)
                    continue

                for cat in categories:
                    cur_val = row[cat]
                    reasons = []

                    if hist_id is not None:
                        hist_vals = hist_id[cat].values
                        # ---- умова 1: вище за середнє по всіх магазинах за попередні місяці ----
                        avg_all = global_avg[cat]
                        if avg_all != 0 and abs(cur_val) > abs(avg_all) * (1 + THRESHOLD_PCT):
                            reasons.append("вище середнього по всіх магазинах більше ніж вдвічі")
                            # ---- умова 2: зростання відносно власної історії магазину,
                            #                якщо всі 3 попередні місяці не нульові ----
                            if len(hist_vals) == 3 and all(v != 0 for v in hist_vals):
                                hist_mean = hist_vals.mean()
                                if hist_mean != 0 and abs(cur_val) > abs(hist_mean) * (1 + THRESHOLD_PCT):
                                    reasons.append("вище власної історії більше ніж вдвічі")

                    if reasons:

                        anomalies = {}

                        # Додаємо всі колонки групування
                        for col in groupby_columns:
                            anomalies[col] = row[col]

                        anomalies.update({
                            "категорія": cat,
                            "поточне": cur_val,
                            "сер._3міс_магазин": round(hist_id[cat].mean(), 2) if hist_id is not None else None,
                            "сер._по_всіх_магазинах": round(avg_all, 2),
                            "причина": ", ".join(reasons),
                        })

                        anomalies_list.append(anomalies)  # <-- append, don't overwrite
        #if missing_filids:
            #print(f"Пропущено {len(missing_filids)} записів без історії: {missing_filids[:20]}...")
        if anomalies_list:
            anomalies_df = pd.DataFrame(anomalies_list)
            anomalies_df = anomalies_df[
                anomalies_df[
                    "причина"] == "вище середнього по всіх магазинах більше ніж вдвічі, вище власної історії більше ніж вдвічі"
                ]
            if not anomalies_df.empty:
                print("\n⚠️ Знайдено аномалії:")
                display(anomalies_df)


        else:
            anomalies_df = pd.DataFrame()
            print("\nАномалій не знайдено, можна заливати дані.")

        return anomalies_df

    def send_mail(self, anomalies_df, year, month, count_of_fema_unique_columns, missing_columns, duplicates, name_of_report):
        #mail_To = "i.sukhovii@fora.ua"
        outlook = win32.Dispatch('Outlook.Application')
        mail = outlook.CreateItem(0)

        mail.To = "m.papanov@fora.ua"
        mail.Subject = f"Звіт по {name_of_report} {month}.{year}"

        # таблиця аномалій
        if len(anomalies_df) > 0:
            anomalies_html = anomalies_df.to_html(index=False)
            anomaly_text = "⚠️ Знайдено аномалії:"
        else:
            anomalies_html = ""
            anomaly_text = "✅ Аномалій не знайдено, можна заливати дані."

        duplicate_columns=[]
        if name_of_report == "ФЕМА":
            # дублікати колонок
            duplicate_columns = count_of_fema_unique_columns[count_of_fema_unique_columns > 1]

        if len(duplicate_columns) > 0:
            duplicate_columns_html = duplicate_columns.to_frame("Кількість").to_html()
        else:
            duplicate_columns_html = "Немає"

        # відсутні колонки
        if missing_columns:
            missing_html = "<br>".join(missing_columns)
        else:
            missing_html = "Немає"

        # дублікати після групування
        if len(duplicates) > 0:
            duplicates_html = duplicates.to_frame("Кількість").to_html()
        else:
            duplicates_html = "Немає"

        mail.HTMLBody = f"""
        <html>
        <body>

        <h3>{anomaly_text}</h3>

        {anomalies_html}

        <hr>

        <h3>Перевірка файлу {name_of_report}</h3>

        <b>Колонки, які зустрічаються декілька разів:</b><br>
        {duplicate_columns_html}

        <br><br>

        <b>Відсутні колонки:</b><br>
        {missing_html}

        <br><br>

        <b>Дублі після групування (їх не має бути):</b><br>
        {duplicates_html}

        <br><br>
        <p>Автоматичний звіт.</p>

        </body>
        </html>
        """

        mail.Send()

        return 0


labor_104_105_sql = text("""
WITH t1 AS
(
SELECT DISTINCT
        a.filid,
        b.depid,
        c.year,
        c.month
    FROM [Business_Analytic].[poteri].[all_oper] a
    CROSS JOIN
    (
        SELECT DISTINCT depid
        FROM [Business_Analytic].[poteri].[all_oper]
        WHERE depid IN (104,105)
          AND year = :year
    ) b
    CROSS JOIN
    (
        SELECT DISTINCT year, month
        FROM [Business_Analytic].[dbo].[calendar]
        WHERE year = :year
    ) c
),
sales AS
(
    SELECT
        year,
        month,
        filid,
        depid,
        SUM(sumout) AS sumout_dep
    FROM [Business_Analytic].[poteri].[all_oper]
    WHERE depid IN (104,105)
      AND type_oper = 'sales'
      AND year = :year
    GROUP BY
        year,
        month,
        filid,
        depid
),
tt AS
(
    SELECT
        t1.filid,
        t1.depid,
        t1.year,
        t1.month,
        ISNULL(s.sumout_dep,0) AS sumout_dep
    FROM t1
    LEFT JOIN sales s
        ON s.year = t1.year
       AND s.month = t1.month
       AND s.filid = t1.filid
       AND s.depid = t1.depid
)

SELECT
    year,
    month,
    filid,
    depid,
    sumout_dep,
    SUM(sumout_dep) OVER
    (
        PARTITION BY year, month, filid
    ) AS sumout_filial
FROM tt
WHERE month = :month
ORDER BY filid, depid;

""")

