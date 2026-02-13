# PySpark Rules

## Conventions

### Code Style
- Use PySpark DataFrame API over RDD API for all new development
- snake_case for all column names, variables, and function names
- PascalCase for class names and custom transformers
- Type hints on all function signatures that accept or return DataFrames
- Chain DataFrame transformations with method chaining for readability
- One transformation per line when chaining for easier debugging

### Schema Management
- Use StructType/StructField for explicit schema definitions
- Define schemas at the top of transformation functions or modules
- Never rely on schema inference in production code
- Document complex nested schemas with inline comments
- Validate incoming schema matches expected structure before processing

### Column Operations
- Prefer `.select()` and `.withColumn()` over SQL strings
- Use Column expressions (`F.col()`, `F.lit()`, `F.when()`) over UDFs
- Import pyspark.sql.functions as F for clarity
- Use `.alias()` to name derived columns clearly
- Qualify column names with dataframe alias in joins

### Naming
```python
# Good
user_orders_df = orders.join(users, "user_id")
total_amount = F.sum("order_amount").alias("total_amount")

# Bad
df1 = orders.join(users, "user_id")  # unclear
sum("order_amount")  # no alias
```

## Patterns

### Read → Validate → Transform → Validate → Write
```python
def process_orders(spark: SparkSession, input_path: str, output_path: str) -> None:
    # Read
    df = spark.read.parquet(input_path)

    # Validate input
    assert df.count() > 0, "Empty input data"
    assert "order_id" in df.columns, "Missing order_id column"

    # Transform
    result = (
        df
        .filter(F.col("status") == "completed")
        .withColumn("order_date", F.to_date("timestamp"))
        .groupBy("order_date")
        .agg(F.sum("amount").alias("daily_total"))
    )

    # Validate output
    output_count = result.count()
    assert output_count > 0, f"No records after transformation"

    # Write
    result.write.mode("overwrite").parquet(output_path)
```

### Window Functions Over Self-Joins
```python
# Good - Use window functions
from pyspark.sql.window import Window

window_spec = Window.partitionBy("user_id").orderBy("timestamp")
df = df.withColumn("prev_amount", F.lag("amount", 1).over(window_spec))

# Bad - Self-join is slower and more complex
df_prev = df.withColumnRenamed("amount", "prev_amount")
df_joined = df.alias("a").join(df_prev.alias("b"), ...)
```

### Conditional Logic with when/otherwise
```python
# Good - Native Spark functions
df = df.withColumn(
    "category",
    F.when(F.col("amount") < 100, "small")
     .when(F.col("amount") < 1000, "medium")
     .otherwise("large")
)

# Bad - UDF kills optimization
@udf(StringType())
def categorize(amount):
    if amount < 100:
        return "small"
    # ...
```

### Struct for Related Columns
```python
# Good - Group related fields
df = df.withColumn(
    "address",
    F.struct(
        F.col("street"),
        F.col("city"),
        F.col("postal_code")
    )
)

# Easier to pass around and maintain
```

### Schema Definition
```python
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, TimestampType

ORDER_SCHEMA = StructType([
    StructField("order_id", StringType(), nullable=False),
    StructField("user_id", StringType(), nullable=False),
    StructField("amount", DoubleType(), nullable=False),
    StructField("timestamp", TimestampType(), nullable=False),
    StructField("status", StringType(), nullable=True)
])

df = spark.read.schema(ORDER_SCHEMA).parquet(path)
```

## Performance

### Partitioning Strategy
- Partition large datasets by frequently filtered columns (date, region, category)
- Use date hierarchy partitioning: `partitionBy("year", "month", "day")`
- Avoid over-partitioning: aim for partition size of 128MB-1GB
- Consider cardinality: don't partition by high-cardinality columns
- Repartition before writing to control output file count

### Join Optimization
- Use `broadcast()` for dimension tables under 10MB
- Set broadcast threshold: `spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 10485760)`
- Prefer sort-merge join for large-to-large joins
- Use salting technique for skewed joins
- Filter data before joins to reduce shuffle size

```python
# Broadcast small dimension table
from pyspark.sql.functions import broadcast

large_df.join(broadcast(small_df), "key")

# Skewed join with salting
def salt_join(left_df, right_df, key, salt_factor=10):
    left_salted = left_df.withColumn("salt", (F.rand() * salt_factor).cast("int"))
    right_salted = right_df.withColumn("salt", F.explode(F.array([F.lit(i) for i in range(salt_factor)])))
    return left_salted.join(right_salted, [key, "salt"]).drop("salt")
```

### Caching Strategy
- Cache/persist only when DataFrame is reused 2+ times
- Unpersist after use to free memory: `df.unpersist()`
- Choose storage level appropriately: `MEMORY_AND_DISK` for large data
- Cache after expensive transformations, before multiple branches

```python
# Good - Reused multiple times
expensive_df = raw_df.join(other_df).filter(...).cache()
result1 = expensive_df.groupBy("a").count()
result2 = expensive_df.groupBy("b").sum()
expensive_df.unpersist()

# Bad - Only used once
df.cache().write.parquet(path)  # Wasteful
```

### Shuffle Optimization
- Minimize shuffles: avoid unnecessary `groupBy`, `join`, `repartition`
- Use `reduceByKey` over `groupByKey` (aggregates before shuffle)
- Set `spark.sql.shuffle.partitions` based on data size (default 200 often wrong)
- Rule of thumb: shuffle partitions = total_data_gb / 0.2 (aim for 200MB per partition)
- Use `coalesce()` instead of `repartition()` to reduce partitions (no shuffle)

```python
# Set shuffle partitions appropriately
spark.conf.set("spark.sql.shuffle.partitions", "800")  # For ~160GB shuffle

# Reduce partitions efficiently
df.coalesce(10)  # Better than repartition(10) when reducing
```

### Column Expressions Over UDFs
- Use built-in functions whenever possible (Catalyst optimizes them)
- UDFs prevent predicate pushdown and Catalyst optimization
- Use Pandas UDFs if you must use UDFs (vectorized, faster)
- Check pyspark.sql.functions before writing UDFs

```python
# Good - Built-in functions
df.withColumn("upper_name", F.upper("name"))

# Bad - Unnecessary UDF
@udf(StringType())
def upper_name(name):
    return name.upper()
```

### Data Collection
- Never use `collect()` on unbounded or large datasets in production
- Use `.take(n)` or `.show(n)` for debugging
- Use `.head(1)` to check if DataFrame is empty (don't use `.count()`)
- Use `.limit()` before collect if you need a sample

```python
# Good
if df.head(1):  # Fast check for non-empty
    print("Data exists")

# Bad
if df.count() > 0:  # Forces computation of entire dataset
    print("Data exists")
```

## File Management

### Storage Format
- Write in Parquet format with Snappy compression (default)
- Use Delta Lake for ACID guarantees and time travel
- Avoid CSV/JSON for large datasets (slow to parse, no predicate pushdown)
- Use ORC for Hive compatibility

```python
# Parquet with partitioning
df.write \
  .mode("overwrite") \
  .partitionBy("year", "month", "day") \
  .parquet(output_path)

# Delta for ACID
df.write \
  .format("delta") \
  .mode("overwrite") \
  .save(output_path)
```

### Small Files Problem
- Repartition/coalesce before writing to avoid many small files
- Aim for 128MB-1GB per output file
- Use `.repartition(n)` or `.coalesce(n)` before write
- Enable adaptive query execution: `spark.sql.adaptive.enabled=true`

```python
# Calculate appropriate partition count
# target_size_mb = 256
# total_size_mb = estimated data size
# partitions = total_size_mb / target_size_mb

df.repartition(10).write.parquet(path)  # Produces ~10 files
```

### Partition Pruning
- Partition by columns frequently used in WHERE clauses
- Partition values should be low-to-medium cardinality
- Avoid partitioning by high-cardinality columns (user_id, transaction_id)
- Test query performance with EXPLAIN to verify partition pruning

## Data Quality

### Validation Checks
- Validate row counts before and after transformations
- Check for nulls in critical columns
- Assert schema matches expected structure
- Log key metrics at each stage

```python
def validate_orders(df: DataFrame) -> None:
    """Validate orders DataFrame meets requirements."""
    row_count = df.count()
    null_count = df.filter(F.col("order_id").isNull()).count()

    assert row_count > 0, "Orders DataFrame is empty"
    assert null_count == 0, f"Found {null_count} null order_ids"
    assert "order_id" in df.columns, "Missing order_id column"
    assert "amount" in df.columns, "Missing amount column"

    # Log metrics
    print(f"Orders validated: {row_count} rows, 0 null order_ids")
```

### Null Handling
- Be explicit about null handling: use `.na.drop()`, `.na.fill()`, or `F.coalesce()`
- Document assumptions about nullable columns
- Use schema nullability to enforce constraints

```python
# Explicit null handling
df = df.na.fill({"amount": 0.0, "status": "unknown"})

# Coalesce for fallback values
df = df.withColumn("amount", F.coalesce("amount", F.lit(0.0)))
```

## Anti-patterns

### Never Do These

#### 1. collect() on Large Data
```python
# NEVER - Brings entire dataset to driver
all_rows = df.collect()  # OOM risk

# DO - Use actions that stay distributed
df.write.parquet(path)
df.groupBy("key").count().show()
```

#### 2. UDFs When Native Functions Exist
```python
# NEVER - UDF kills Catalyst optimization
@udf(StringType())
def concat_fields(a, b):
    return f"{a}_{b}"

# DO - Use built-in functions
F.concat(F.col("a"), F.lit("_"), F.col("b"))
```

#### 3. RDD API for New Development
```python
# NEVER - RDD API is unoptimized
rdd = df.rdd.map(lambda x: x.value * 2)

# DO - Use DataFrame API
df.withColumn("value", F.col("value") * 2)
```

#### 4. count() to Check Existence
```python
# NEVER - Forces full scan
if df.count() > 0:
    process(df)

# DO - Check first row only
if df.head(1):
    process(df)
```

#### 5. toPandas() on Large Datasets
```python
# NEVER - Loads everything into driver memory
pdf = large_df.toPandas()

# DO - Use Spark operations or sample first
sample_pdf = df.limit(1000).toPandas()
```

#### 6. Ignoring Data Skew
```python
# NEVER - Skewed join kills performance
df1.join(df2, "skewed_key")  # One partition gets 90% of data

# DO - Use salting or broadcast
broadcast(df2) if df2 is small
salt_join(df1, df2, "skewed_key") if both are large
```

#### 7. Hardcoded Paths
```python
# NEVER
df = spark.read.parquet("/user/data/2024/01/01/orders.parquet")

# DO - Use parameters
def read_orders(spark: SparkSession, base_path: str, date: str) -> DataFrame:
    path = f"{base_path}/{date}/orders.parquet"
    return spark.read.parquet(path)
```

#### 8. Unnecessary Shuffles
```python
# NEVER - Multiple shuffles
df.repartition(100).groupBy("key").count()

# DO - Let groupBy handle partitioning
df.groupBy("key").count()
```

#### 9. Missing unpersist()
```python
# NEVER - Memory leak
df.cache()
# ... use df ...
# forgot to unpersist

# DO - Always cleanup
df.cache()
result = df.groupBy("key").count()
df.unpersist()
```

#### 10. Python UDFs for Simple Operations
```python
# NEVER
@udf(DoubleType())
def multiply_by_two(x):
    return x * 2

# DO
df.withColumn("doubled", F.col("value") * 2)
```

## Configuration Best Practices

### Common Settings
```python
# Adaptive Query Execution (Spark 3.0+)
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")

# Shuffle partitions (adjust based on data size)
spark.conf.set("spark.sql.shuffle.partitions", "200")  # Default, tune as needed

# Broadcast threshold (10MB default)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "10485760")

# Dynamic allocation
spark.conf.set("spark.dynamicAllocation.enabled", "true")
spark.conf.set("spark.dynamicAllocation.minExecutors", "2")
spark.conf.set("spark.dynamicAllocation.maxExecutors", "100")
```

### Memory Tuning
- Set executor memory based on data size and cluster capacity
- Leave 10% overhead for off-heap memory
- Monitor GC time: if > 10% of task time, increase executor memory
- Use memory profiling to identify bottlenecks

## Testing

### Unit Testing DataFrames
```python
from pyspark.sql import SparkSession
import pytest

@pytest.fixture(scope="session")
def spark():
    return SparkSession.builder.master("local[2]").getOrCreate()

def test_transform_orders(spark):
    # Arrange
    input_data = [("order1", 100.0), ("order2", 200.0)]
    input_df = spark.createDataFrame(input_data, ["order_id", "amount"])

    # Act
    result = transform_orders(input_df)

    # Assert
    assert result.count() == 2
    assert "total_amount" in result.columns
    result_list = result.collect()
    assert result_list[0]["total_amount"] == 100.0
```

### Integration Testing
- Test with realistic data volumes
- Validate schema, row count, and key business logic
- Test partition pruning with EXPLAIN
- Verify performance on production-like data
