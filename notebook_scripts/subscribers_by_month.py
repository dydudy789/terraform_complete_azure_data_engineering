from pyspark.sql import functions as F

# ---------- paths ----------
account = "stphsdsdevdlcufvc" 
silver_path   = f"abfss://silver@{account}.dfs.core.windows.net/customers-100-silver"
gold_path   = f"abfss://gold@{account}.dfs.core.windows.net/subscriber_counts_by_month"

# ---------- read silver ----------
df = spark.read.format("delta").load(silver_path)


# ---------- aggregate by month (Jan 2020 .. Dec 2022) ----------
monthly_counts = (
    df
    .withColumn("month", F.date_trunc("month", F.col("subscription_date"))) #floor date to earliest date of month
    .groupBy("month")
    .agg(F.count(F.lit(1)).alias("subscribers"))
)

# Build a complete month series so missing months show as 0
months = (
    spark.range(1)
    .select(F.explode(F.sequence(
        F.to_date(F.lit("2020-01-01")),
        F.to_date(F.lit("2022-12-01")),
        F.expr("interval 1 month")
    )).alias("month"))
)

result = (
    months.join(monthly_counts, "month", "left")
          .na.fill({"subscribers": 0})
          .orderBy("month")
)

display(result)

# ---------- write gold as Delta ----------
(
    result.write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .save(gold_path)
)

print("✅ Monthly subscriber counts written to:", gold_path)