# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse_name": "",
# META       "default_lakehouse_workspace_id": ""
# META     }
# META   }
# META }

# CELL ********************

from pyspark.sql import DataFrame,Column,functions,types

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

%run /commonTransforms

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Test File
file = "Files/raw-bronze/wwi/Sales/Orders/2013-01/Sales_Orders_2013-01-01_000000.parquet"
# Config schema explicitly for testing purposes
# dataSchema="VendorID STRING,tpep_pickup_datetime TIMESTAMP,tpep_dropoff_datetime TIMESTAMP,passenger_count INT,trip_distance DOUBLE,RatecodeID STRING,store_and_fwd_flag STRING,PULocationID INT,DOLocationID INT,payment_type INT,fare_amount DOUBLE,extra DOUBLE,mta_tax DOUBLE,tip_amount DOUBLE,tolls_amount DOUBLE,improvement_surcharge DOUBLE,total_amount DOUBLE,congestion_surcharge DOUBLE"
input=spark.read.parquet(file)
# display(input)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

input = input.withColumn("sys_date1",lit(20275)) #Date in Julian Format
input = input.withColumn("sys_date2",lit("2020-10-01").cast("date")) #Date in Gregorian Format

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

display(input)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

ct=CommonTransforms(input)

# Remove duplicates
output=ct.deDuplicate()

# Remove duplicates based on key columns
output=ct.deDuplicate(["OrderID"])

# Remove leading and trailing spaces from all string columns
output=ct.trim()

# Replace Null Value with generic values
output = ct.replaceNull(0)
output = ct.replaceNull("NA")
output = ct.replaceNull("2020-01-01")

# Replace Null value in Timestamp columns
output = ct.replaceNull("1900-01-01T00:00:00","OrderDate")
output = ct.replaceNull("9999-12-31T23:59:59","ExpectedDeliveryDate")

# # Replace Null Values with custom defaults
# output = ct.replaceNull({"passenger_count":1,"store_and_fwd_flag":"N","tip_amount":0,"tolls_amount":0, "improvement_surcharge":0,"congestion_surcharge":0})

# Convert UTC timestamps to local
output = ct.utc_to_local("Australia/Sydney")
output = ct.utc_to_local("Australia/Sydney",["LastEditedWhen"])


# # Convert local timestamps to UTC
output = ct.local_to_utc("Australia/Sydney")
output = ct.local_to_utc("Australia/Sydney",["LastEditedWhen"])

# # Convert time from one Timezone to another
output = ct.changeTimezone("Australia/Sydney","America/New_York")

# # Drop system/non-business columns
# output = ct.dropSysColumns("store_and_fwd_flag")

# Add Checksum
output = ct.addChecksumCol("checksum")

# Convert Julian date to Calendar date
output = ct.julian_to_calendar("sys_date1")

# Convert Calendar date to Julian
output =ct.calendar_to_julian("sys_date2")

# Add literal value columns for e.g audit columns
audit={"audit_key":66363,"pipeline_id":"56f63394bb06dd7f6945f636f1d4018bd50f1850", "start_datetime": "2020-10-01 10:00:00", "end_datetime": "2020-10-01 10:02:05"}
output = ct.addLitCols(audit)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

display(output)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
