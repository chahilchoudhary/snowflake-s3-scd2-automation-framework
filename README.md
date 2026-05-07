# 🚀 Snowflake Automated S3 Data Ingestion & SCD Type 2 Framework

## 📌 Overview

This project demonstrates a complete end-to-end automated data engineering pipeline using AWS S3 and Snowflake.

The framework automatically ingests CSV files from AWS S3 into Snowflake staging tables using a metadata-driven control framework and performs incremental SCD Type 2 processing using Snowflake Streams and Tasks.

The solution is fully automated, scalable, reusable, and designed using enterprise-level ELT architecture principles.

---

# 🏗️ Architecture Diagram

![Architecture](architecture/workflow_architecture.png)

---

# ⚡ Key Features

## ✅ Automated S3 Data Ingestion
- Automatically loads CSV files from AWS S3
- Dynamic external stage creation
- Metadata-driven ingestion framework
- Reusable stored procedure

---

## ✅ Metadata-Driven Framework
Control table manages:
- Table names
- Schema names
- Storage locations
- File patterns
- File types
- Delimiters
- Error handling
- Active flags

---

## ✅ Dynamic COPY INTO Processing
Stored procedure dynamically:
- Reads metadata
- Creates stages
- Validates files
- Executes COPY INTO commands
- Loads staging tables

---

## ✅ Incremental CDC Processing
Snowflake Streams capture:
- New records
- Updated records

for incremental processing.

---

## ✅ SCD Type 2 Historical Tracking
Maintains complete history using:
- EFF_START_DATE
- EFF_END_DATE
- IS_ACTIVE flag

---

## ✅ Automated Scheduling
Snowflake Tasks automatically execute the SCD2 process every minute whenever stream data is available.

---

# 🛠️ Technologies Used

| Technology | Purpose |
|---|---|
| AWS S3 | Source storage |
| Snowflake | Cloud data warehouse |
| Snowflake Streams | Change Data Capture |
| Snowflake Tasks | Scheduling |
| SQL Stored Procedures | Automation |
| Dynamic SQL | Metadata-driven processing |

---

# 📂 Project Structure

```bash
snowflake-s3-scd2-automation-framework/
│
├── architecture/
│   └── workflow_architecture.png
│
├── sql/
│   ├── 01_create_database_schema.sql
│   ├── 02_control_table.sql
│   ├── 03_staging_tables.sql
│   ├── 04_control_table_data.sql
│   ├── 05_auto_load_procedure.sql
│   ├── 06_create_stream.sql
│   ├── 07_scd2_procedure.sql
│   ├── 08_create_task.sql
│   └── 09_execution_queries.sql
│
├── sample-data/
│   ├── accounts.csv
│   └── customers.csv
│
├── screenshots/
│
└── README.md
```

---

# 🔄 Workflow

## Step 1 — Upload Files to AWS S3

CSV files are uploaded into:
- account/
- customer/

folders inside the S3 bucket.

---

## Step 2 — Metadata Configuration

Control table stores ingestion configuration details for every table.

---

## Step 3 — Execute Automated Load Procedure

```sql
CALL mydb.staging.sp_automate_data_copy();
```

The procedure:
- Reads control table metadata
- Creates temporary stages dynamically
- Validates files
- Loads data into staging tables

---

## Step 4 — Stream Captures Changes

Snowflake Stream tracks:
- INSERT records
- UPDATED records

for incremental CDC processing.

---

## Step 5 — SCD Type 2 Processing

Task automatically triggers:

```sql
CALL mydb.target.proc_customer_scd2();
```

The procedure:
- Expires old records
- Updates historical end dates
- Inserts new active versions

---

# 📊 Final Target Table

```sql
MYDB.TARGET.CUSTOMER_SCD2
```

Maintains complete historical customer records.

---

# 📸 Sample Screenshots

## Architecture Workflow
<img width="1408" height="768" alt="Gemini_Generated_Image_h6nuryh6nuryh6nu" src="https://github.com/user-attachments/assets/3de92e73-5034-472c-924a-cfdd8b387b85" />


## Stored Procedure Execution
<img width="959" height="413" alt="image" src="https://github.com/user-attachments/assets/d83ad191-32bd-44e1-b214-fb3dfabbb929" />



## Stream Output
<img width="1600" height="721" alt="image" src="https://github.com/user-attachments/assets/4807bcf6-f71b-4b77-b4cc-4cbb247236a2" />


## s3 bucket folders
<img width="958" height="381" alt="image" src="https://github.com/user-attachments/assets/861eca60-402f-42bb-99c8-7f0d9a808ddc" />

---

# 🚀 Future Enhancements

- JSON & Parquet support
- Generic reusable SCD framework
- Audit logging framework
- Error handling tables
- Airflow orchestration
- CI/CD deployment
- dbt integration

---

# 👨‍💻 Author

## chahil choudhary

Data Engineering | Snowflake | AWS | Automation

---

# ⭐ Support

If you found this project useful, give this repository a ⭐ on GitHub.
