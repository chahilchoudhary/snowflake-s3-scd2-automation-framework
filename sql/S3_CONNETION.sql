-- creating the connection with the s3 folder after give ima roles and policy and giving acces to both folder
create or replace storage integration s3_int
  type = external_stage
  storage_provider = 'S3'
  enabled = true
  storage_aws_role_arn = 'arn:aws:iam::397348546799:role/chahilsnowflakerole'
  storage_allowed_locations = ('s3://snow-flake-demochahil/account/','s3://snow-flake-demochahil/customer/')
  ;


DESC INTEGRATION s3_int;


-- CREATING DATABASE AND SCHEMA
CREATE DATABASE IF NOT EXISTS S3_DEMO;
USE DATABASE S3_DEMO;
CREATE OR REPLACE SCHEMA BANK_DEMO;
USE SCHEMA BANK_DEMO;

-- CREATING STAGE FOR BOTH DATA
-- Stage → to connect Snowflake with external data (like S3) so it can access files.
create stage ACCOUNT_STAGE
  storage_integration = s3_int
  url = 's3://snow-flake-demochahil/account/'
  ;

create stage CUSTOMER_STAGE
  storage_integration = s3_int
  url = 's3://snow-flake-demochahil/customer/'
  ;


LIST @ACCOUNT_STAGE;
LIST @CUSTOMER_STAGE;




-- File Formats (you can reuse or create separate)
-- File Format → to tell Snowflake how to read and parse those files (CSV, delimiter, header, etc.).

CREATE OR REPLACE FILE FORMAT account_format
  TYPE = CSV
  FIELD_DELIMITER = ','
  PARSE_HEADER = TRUE;

CREATE OR REPLACE FILE FORMAT customer_format
  TYPE = CSV
  FIELD_DELIMITER = ','
  PARSE_HEADER = TRUE;



--- Create ACCOUNT Table using ACCOUNT_STAGE 

CREATE OR REPLACE TABLE account_table
USING TEMPLATE (
  SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
  FROM TABLE(
    INFER_SCHEMA(
      LOCATION => '@ACCOUNT_STAGE',
      FILE_FORMAT => 'account_format'
    )
  )
);


-- Create CUSTOMER Table using CUSTOMER_STAGE
CREATE OR REPLACE TABLE customer_table
USING TEMPLATE (
  SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
  FROM TABLE(
    INFER_SCHEMA(
      LOCATION => '@CUSTOMER_STAGE',
      FILE_FORMAT => 'customer_format'
    )
  )
);



-- Load ACCOUNT Data
COPY INTO account_table
FROM @ACCOUNT_STAGE
FILE_FORMAT = (TYPE = CSV FIELD_DELIMITER = ',' PARSE_HEADER = TRUE ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

--Load CUSTOMER Data
COPY INTO customer_table
FROM @CUSTOMER_STAGE
FILE_FORMAT = (
  TYPE = CSV 
  FIELD_DELIMITER = ',' 
  PARSE_HEADER = TRUE 
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;


SELECT * FROM ACCOUNT_TABLE;
SELECT * FROM CUSTOMER_TABLE;


