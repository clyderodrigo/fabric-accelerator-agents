# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   }
# META }

# MARKDOWN ********************

# # gold_sql_utils
# Shared T-SQL plumbing for the gold layer.
#
# Gold is a **Warehouse** (`dw_gold`), not a lakehouse, so Spark cannot write to it.
# The gold notebooks therefore execute the `gold.create_*` stored procedures over TDS
# using an AAD token minted by `notebookutils.credentials.getToken`.
#
# Consumers: `%run gold_sql_utils`, then call `gold_connect`, `gold_exec_proc`,
# `gold_table_count`.

# CELL ********************

import struct
import pyodbc

# SQL Server ODBC attribute used to pass an AAD access token to the driver.
SQL_COPT_SS_ACCESS_TOKEN = 1256
SQL_TOKEN_RESOURCE = "https://database.windows.net/"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

def gold_connect(sql_endpoint, database="dw_gold", timeout=600):
    """Open a TDS connection to a Fabric Warehouse using the notebook's AAD identity.

    sql_endpoint is the bare host from accelerator-config.gold_sql_endpoint,
    e.g. '<guid>.datawarehouse.fabric.microsoft.com' (no port, no protocol).
    """
    if not sql_endpoint:
        raise ValueError(
            "gold_sql_endpoint is empty. Set accelerator-config.gold_sql_endpoint to the "
            "dw_gold warehouse endpoint before running the gold layer."
        )
    if sql_endpoint.startswith(("http://", "https://")):
        raise ValueError(
            f"gold_sql_endpoint must be a bare host, got '{sql_endpoint}'."
        )

    token = notebookutils.credentials.getToken(SQL_TOKEN_RESOURCE)
    token_bytes = token.encode("utf-16-le")
    token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)

    connection_string = (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={sql_endpoint},1433;"
        f"DATABASE={database};"
        "Encrypt=yes;TrustServerCertificate=no;Connection Timeout=60;"
    )
    return pyodbc.connect(
        connection_string,
        attrs_before={SQL_COPT_SS_ACCESS_TOKEN: token_struct},
        timeout=timeout,
    )

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

def gold_exec_proc(conn, schema, proc_name):
    """Execute a gold L2 procedure and drain every result set it returns."""
    cursor = conn.cursor()
    try:
        cursor.execute(f"EXEC [{schema}].[{proc_name}]")
        while cursor.nextset():
            pass
        conn.commit()
    finally:
        cursor.close()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

def gold_table_count(conn, schema, table_name):
    """Row count for a gold table; raises if the proc never created it."""
    cursor = conn.cursor()
    try:
        cursor.execute(f"SELECT COUNT(*) FROM [{schema}].[{table_name}]")
        row = cursor.fetchone()
        return int(row[0])
    finally:
        cursor.close()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
