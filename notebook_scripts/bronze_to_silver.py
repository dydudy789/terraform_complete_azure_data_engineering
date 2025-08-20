from pyspark.sql.functions import concat_ws, col
import re

account = "stphsdsdevdlcufvc"

bronze_path = f"abfss://bronze@{account}.dfs.core.windows.net/customers-100.csv"
silver_path = f"abfss://silver@{account}.dfs.core.windows.net/customers-100-silver"

# Read CSV
df = (
    spark.read.format("csv")
        .option("header", "true")
        .option("inferSchema", "true")
        .load(bronze_path)
)

# Sanitize column names: replace spaces and other invalid chars with underscores
def clean(name: str) -> str:
    return re.sub(r"[ ,;{}()\n\t=]", "_", name).strip("_")

df = df.toDF(*[clean(c) for c in df.columns])

# Now columns are e.g. First_Name, Last_Name
df_silver = df.withColumn("FullName", concat_ws("-", col("First_Name"), col("Last_Name")))

# Write to Delta
(df_silver.write
    .format("delta")
    .mode("overwrite")
    .save(silver_path)
)

print("✅ Transformation complete. Data written to silver container.")