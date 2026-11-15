# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "40f9a510-7e67-4b26-83c4-f946b1c41b74",
# META       "default_lakehouse_name": "lh_silver",
# META       "default_lakehouse_workspace_id": "63f73055-fc7d-4d58-9646-a108f82eb52c"
# META     }
# META   }
# META }

# MARKDOWN ********************

# ### Spark Optimization Configs

# CELL ********************

spark.conf.set("spark.native.enabled", "true")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

%run /DeltaLakeFunctions

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ### Iterate through all tables in lakehouse and run OPTIMIZE and VACCUM commands

# CELL ********************

df = spark.sql("show tables")
tableList = df.select("tableName").rdd.flatMap(lambda x:x).collect()
# print (tables)
for table in tableList:
    print ("optimizing",table)
    optimizeDelta(table)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
