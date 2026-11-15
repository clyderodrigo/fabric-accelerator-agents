# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   }
# META }

# MARKDOWN ********************

# # gold_dim_calendar
# Generated calendar spine 2018-01-01..2026-12-31, role-played in FactSales as
# OrderDateKey, DueDateKey and ShipDateKey.
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
target_table = "DimCalendar"
proc_name = "create_dimcalendar"

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
