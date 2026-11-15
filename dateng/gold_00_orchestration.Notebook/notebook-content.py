# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   }
# META }

# MARKDOWN ********************

# # gold_00_orchestration
# Entry point for the gold layer of `[DEV] DatEng`.
#
# Gold is a Warehouse (`dw_gold`), so each table is loaded by a `gold.create_*` stored
# procedure. This notebook fans out to one child notebook per table through
# `notebookutils.notebook.runMultiple`, which gives parallel execution plus a DAG.
#
# Order: every dimension first, then `FactSales` once all four dimensions have landed.
#
# Prerequisites:
# * `lh_silver` holds the `silver_saleslt_*` tables produced by the L1 notebooks.
# * `accelerator-config.gold_sql_endpoint` points at this workspace's `dw_gold` endpoint.
# * `gold_sql_utils` exists in this workspace (the children `%run` it).

# METADATA ********************

# META {
# META   "language": "markdown",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

config = notebookutils.variableLibrary.getLibrary("accelerator-config")

gold_sql_endpoint = config.gold_sql_endpoint
gold_warehouse_name = "dw_gold"
gold_schema = "gold"

print(f"workspace   : {config.gold_workspace_id}")
print(f"warehouse   : {gold_warehouse_name} ({config.gold_warehouse_id})")
print(f"sql endpoint: {gold_sql_endpoint}")

# Fail fast rather than let five children fail on an empty endpoint.
if not gold_sql_endpoint:
    raise ValueError(
        "accelerator-config.gold_sql_endpoint is empty. Populate the variable library "
        "before running the gold layer."
    )

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

timeout_per_cell_in_seconds = 1800   # a full CTAS over silver can outrun the 90s default
retry = 1                            # one retry absorbs transient TDS / capacity throttling
retry_interval_in_seconds = 30
timeout_in_seconds = 7200            # whole DAG
concurrency = 5                      # five tables, five children; no benefit going wider

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

params_to_pass = {
    "gold_sql_endpoint": gold_sql_endpoint,
    "gold_warehouse_name": gold_warehouse_name,
}

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

def gold_activity(name, path, depends_on=None):
    activity = {
        "name": name,
        "path": path,
        "timeoutPerCellInSeconds": timeout_per_cell_in_seconds,
        "retry": retry,
        "retryIntervalInSeconds": retry_interval_in_seconds,
        "args": params_to_pass,
    }
    if depends_on:
        activity["dependencies"] = depends_on
    return activity


dimensions = ["dim_address", "dim_calendar", "dim_customer", "dim_product"]

pipeline = {
    "activities": [gold_activity(d, f"gold_{d}") for d in dimensions]
    + [gold_activity("fact_sales", "gold_fact_sales", depends_on=dimensions)],
    "timeoutInSeconds": timeout_in_seconds,
    "concurrency": concurrency,
}

print(f"{len(pipeline['activities'])} activities: dims run in parallel, fact_sales waits for all four")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

run_summary = notebookutils.notebook.runMultiple(pipeline, {"displayDAGViaGraphviz": True})
print(run_summary)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
