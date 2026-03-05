# Spark Optimization Reference

Detailed configuration, patterns, and tuning guidance for Apache Spark/PySpark.
Load this file when diagnosing performance issues or configuring cluster settings.

---

## AQE Configuration (Best Practice #4)

Adaptive Query Execution handles most tuning automatically since Spark 3.2.
Verify these settings are active:

```python
spark = SparkSession.builder \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .config("spark.sql.adaptive.skewJoin.enabled", "true") \
    .config("spark.sql.adaptive.advisoryPartitionSizeInBytes", "128m") \
    .getOrCreate()
```

- `advisoryPartitionSizeInBytes=128m` — target partition size after coalescing
- `coalescePartitions.minPartitionNum` — set to number of cores as a floor
- `skewJoin.skewedPartitionFactor=5` — partition is skewed if > 5x median size
- `skewJoin.skewedPartitionThresholdInBytes=256m` — absolute skew threshold

AQE will automatically coalesce small shuffle partitions, so set
`shuffle.partitions` high (1000-4000) and let AQE reduce them at runtime.

---

## Delta OPTIMIZE and ZORDER (Best Practice #5)

Run OPTIMIZE regularly to compact small files toward the 1GB target:

```sql
-- Basic compaction
OPTIMIZE my_table;

-- With Z-ordering on join/filter columns (max 3-4 columns)
OPTIMIZE my_table ZORDER BY (event_date, user_id);

-- Target a specific partition
OPTIMIZE my_table WHERE event_date = '2024-01-15';
```

**Liquid Clustering (DBR 13.3+)** — preferred over ZORDER for new tables:

```sql
-- Define at table creation
CREATE TABLE my_table (id BIGINT, event_date DATE, user_id STRING)
CLUSTER BY (event_date, user_id);

-- Or convert existing table
ALTER TABLE my_table CLUSTER BY (event_date, user_id);
```

Liquid Clustering incrementally reorganizes data; no manual OPTIMIZE needed.
ZORDER is a full rewrite — expensive on large tables.

Schedule OPTIMIZE during off-peak hours via a maintenance job or
`delta.autoOptimize.autoCompact=true` for automatic compaction on write.

---

## Delta MERGE Patterns (Best Practice #6)

Always include the partition column in the join condition:

```python
# BAD — full table scan on source and target
target.alias("t").merge(
    source.alias("s"),
    "t.id = s.id"
).whenMatchedUpdateAll().execute()

# GOOD — partition pruning reduces scan by 80%+
target.alias("t").merge(
    source.alias("s"),
    "t.event_date = s.event_date AND t.id = s.id"  # partition col first
).whenMatchedUpdate(
    condition="t.value != s.value",  # selective update — skip unchanged rows
    set={"value": "s.value", "updated_at": "s.updated_at"}
).whenNotMatchedInsertAll().execute()
```

**Deletion vectors** (DBR 11.2+ / OSS Delta 2.3+) — enable for write-heavy tables:

```sql
ALTER TABLE my_table SET TBLPROPERTIES ('delta.enableDeletionVectors' = 'true');
```

Deletion vectors mark deleted/updated rows without rewriting data files,
dramatically reducing MERGE write amplification.

**MERGE optimization checklist:**
- Partition column in join condition (critical)
- `WHEN MATCHED AND (condition)` for selective updates
- Filter source to only changed records before MERGE
- Enable deletion vectors for high-frequency MERGE tables
- Run OPTIMIZE after bulk MERGEs to reclaim space

---

## Memory Configuration for PySpark (Best Practice #7)

Default memory overhead is 10% — insufficient for Python workloads:

```python
# spark-submit / SparkConf settings
spark = SparkSession.builder \
    .config("spark.executor.memory", "8g") \
    .config("spark.executor.memoryOverhead", "2g")   # 25% of executor memory \
    .config("spark.executor.pyspark.memory", "4g")   # explicit Pandas UDF budget \
    .config("spark.driver.memory", "4g") \
    .config("spark.driver.memoryOverhead", "1g") \
    .getOrCreate()
```

**Memory regions on an executor:**
- `executor.memory` — JVM heap (Spark engine, shuffle buffers, Tungsten)
- `executor.memoryOverhead` — off-heap (Python process, native libraries)
- `executor.pyspark.memory` — Python worker memory cap (within overhead)

**Sizing rules:**
- Overhead = max(384MB, 10% of executor memory) — default; set to 20-25% for PySpark
- `pyspark.memory` should be set explicitly when using Pandas UDFs or large Python objects
- Total container memory = executor.memory + executor.memoryOverhead

Symptoms of insufficient overhead: executor killed by YARN/K8s with no Spark
error in the log; only container logs show OOM kill signal.

---

## Partition Strategy (Best Practice #8)

**Write partitioning** — partition on low-cardinality, high-selectivity columns:

```python
# Good partition columns: date, country, region, status
df.write \
    .partitionBy("event_date", "country") \
    .mode("overwrite") \
    .format("delta") \
    .save("/data/events")

# Dynamic partition overwrite — only replaces partitions present in the data
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
df.write.mode("overwrite").partitionBy("event_date").save(path)
```

**Target file size:** 128MB-1GB per partition file. Check with:

```python
# Approximate partition file count
spark.read.format("delta").load(path) \
    .groupBy("event_date") \
    .count() \
    .show()
```

**Repartition vs coalesce:**
- `repartition(n)` — full shuffle, produces exactly N balanced partitions
- `coalesce(n)` — no shuffle, merges partitions; use before write to reduce small files
- `repartition(n, col)` — hash-partitions on column; use before joins on that column

**Partition pruning** requires filter columns to match partition columns exactly.
Computed expressions (e.g., `YEAR(event_date)`) bypass pruning — filter on the
partition column directly.

---

## Caching Strategy (Best Practice #9)

```python
from pyspark import StorageLevel

# Safe default — spills to disk when memory is full
df.persist(StorageLevel.MEMORY_AND_DISK)

# Memory only — faster but risks OOM if executor memory is tight
df.persist(StorageLevel.MEMORY_ONLY)

# Serialized — more compact in memory, slightly slower to deserialize
df.persist(StorageLevel.MEMORY_AND_DISK_SER)

# Always unpersist when done
df.unpersist()
```

**When to cache:**
- DataFrame is used 2+ times in the same job (avoids recomputation)
- Source is expensive (complex join, aggregation, remote read)
- Iterative algorithms (MLlib, graph processing)

**When NOT to cache:**
- Delta Lake tables — Delta has its own caching and data skipping
- DataFrames used only once — caching adds overhead with no benefit
- Very large DataFrames that exceed executor memory * cores

Use the Spark UI Storage tab to verify cached DataFrames and their memory usage.
`df.is_cached` returns True only after an action triggers materialization.

---

## Reading Explain Plans (Best Practice #11)

```python
# Simple formatted plan
df.explain(mode="formatted")

# Full verbose plan (includes stats, codegen)
df.explain(mode="extended")
```

**Key nodes to look for:**

| Node | Meaning | Action |
|------|---------|--------|
| `Exchange` | Shuffle occurring | Investigate if avoidable |
| `BroadcastHashJoin` | Broadcast join used | Good — no shuffle |
| `SortMergeJoin` | Sort-merge join | Expensive; try broadcast |
| `BroadcastNestedLoopJoin` | Cartesian or non-equi join | Usually a bug |
| `Project` chain (nested) | `withColumn` loop | Replace with `select` |
| `Filter (PushedFilters)` | Predicate pushdown working | Good |
| `FileScan` + `PartitionFilters` | Partition pruning active | Good |
| `FileScan` + no `PartitionFilters` | Full table scan | Add partition filter |
| `HashAggregate` (2 stages) | Partial + final aggregation | Normal |

**Reading the plan bottom-up:** leaf nodes (scans) are at the bottom; root
(final output) is at the top. Wide transformations (Exchange) separate stages.

---

## Checkpointing Deep Lineage (Best Practice #12)

Break deep lineage with `df.checkpoint()` after many transformations:

```python
# Enable checkpointing
spark.sparkContext.setCheckpointDir("hdfs:///tmp/spark-checkpoints")
# or on cloud
spark.sparkContext.setCheckpointDir("s3://my-bucket/spark-checkpoints")

# Checkpoint after complex lineage (50+ transformations, iterative loops)
df_after_many_transforms = df.checkpoint()  # triggers action + saves to disk

# Eager checkpoint (default) — triggers immediately
# Lazy checkpoint — deferred to next action
df_lazy = df.checkpoint(eager=False)
```

**When to checkpoint:**
- Iterative ML algorithms (each iteration adds to lineage)
- Streaming jobs accumulating state
- Complex ETL pipelines with 50+ chained transformations
- After a `union` of many DataFrames

**checkpoint() vs persist():**
- `persist()` — stores in executor memory/disk; lineage is NOT broken
- `checkpoint()` — stores to reliable storage; lineage IS broken (Spark forgets ancestry)

Use `checkpoint()` when `persist()` alone doesn't prevent StackOverflow or
planning time is visibly slow (seconds to generate plan).
