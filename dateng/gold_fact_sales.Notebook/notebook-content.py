# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   }
# META }

# MARKDOWN ********************

# # gold_fact_sales
# Sales fact at order-line grain. Header money (TaxAmt / Freight / TotalDue) is
# apportioned across the order lines so every measure stays additive.
#
# Child of `gold_00_orchestration`. Parameters are injected by
# `notebookutils.notebook.runMultiple`; the defaults below support a standalone run.

# METADATA ********************

# META {
# META   "language": "markdown",
# META   "language_group": "synapse_pyspark"
# META }

# PARAMETERS CELL ********************

gold_sql_endpoint = None
gold_warehouse_name = "dw_gold"
target_schema = "gold"
target_table = "FactSales"
proc_name = "create_factsales"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

%run gold_sql_utils

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

row_count = None
conn = gold_connect(gold_sql_endpoint, gold_warehouse_name)
try:
    gold_exec_proc(conn, target_schema, proc_name)
    row_count = gold_table_count(conn, target_schema, target_table)
finally:
    conn.close()

print(f"{target_schema}.{target_table}: {row_count} rows via {target_schema}.{proc_name}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

notebookutils.notebook.exit(f"{target_schema}.{target_table}: {row_count} rows")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
