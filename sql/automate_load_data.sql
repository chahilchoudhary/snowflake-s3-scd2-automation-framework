-- Assuming..
-- 1. You have AWS account and s3 bucket created
-- 2. AWS - Snowflake integration done
-- 3. Files uploaded to diff folders in s3 bucket

-- I have explained all above steps in AWS - Snowflake integration video
USE MYDB
-- Create database and schemas required
create database if not exists mydb;
create schema if not exists mydb.external_stages;
create schema if not exists mydb.staging;
create schema if not exists mydb.control;



-- Create the control table with data load details
CREATE or REPLACE TABLE mydb.control.copy_ctrl
(
stage_table_name string,
schema_name string,
database_name string,
storage_int string,
storage_loc string,
files_typ string,
files_pattern string,
field_delim string,
on_error string,
skip_header int,
force boolean,
truncate_cols boolean,
is_active boolean,
PRIMARY KEY(stage_table_name, schema_name, database_name)
);

-- Create target tables
CREATE OR REPLACE TABLE mydb.staging.account_data 
(
    account_id        STRING,
    cust_identifier   STRING,
    account_type      STRING,
    balance           NUMBER(10,0),
    currency          STRING,
    open_date         DATE,
    branch            STRING,
    status            STRING,
    interest_rate     NUMBER(5,2),
    overdraft         BOOLEAN,
    last_txn_date     DATE,
    risk_flag         STRING
);



CREATE OR REPLACE TABLE mydb.staging.customer_data 
(
    cust_identifier   STRING,
    first_name        STRING,
    last_name         STRING,
    age               NUMBER(3,0),
    gender            STRING,
    city              STRING,
    state             STRING,
    country           STRING,
    signup_date       DATE,
    status            STRING,
    credit_score      NUMBER(4,0),
    income            NUMBER(10,0)
);


-- Insert entries into Control table
DELETE FROM mydb.control.copy_ctrl;

INSERT INTO mydb.control.copy_ctrl VALUES
('account_data', 'staging', 'mydb', 's3_int', 's3://snow-flake-demochahil/account/', 'csv', '.*accounts.*', ',', 'CONTINUE', 1, True, True, True),
('customer_data', 'staging', 'mydb', 's3_int', 's3://snow-flake-demochahil/customer/', 'csv', '.*customers.*', ',', 'CONTINUE', 1, True, True, True)
;

select * from mydb.control.copy_ctrl;








-- stored procedure to automate load data

CREATE OR REPLACE PROCEDURE mydb.staging.sp_automate_data_copy()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS

DECLARE
curs cursor for SELECT * FROM mydb.control.copy_ctrl WHERE is_active = True;

tbl string;
sch string;
db string;
st_int string;
st_loc string;
file_typ string;
file_pat string;
fld_dlm string;
skp_hdr string;
forc string;
on_err string;
trun_col string;
cnt integer;
ret string;
file_format1 string;
copy_stmt string;
create_stage_stmt string;
fp string;

BEGIN

ret := '';

for rec in curs
do
	tbl := rec.stage_table_name;
	sch := rec.schema_name;
	db := rec.database_name;
	st_int := rec.storage_int;
	st_loc := rec.storage_loc;
	file_typ := rec.files_typ;
	file_pat := rec.files_pattern;
	fld_dlm := rec.field_delim;
	skp_hdr := rec.skip_header;
	forc := rec.force;
	on_err := rec.on_error;
	trun_col := rec.truncate_cols;
	
	if(:file_typ = 'csv') then	
		file_format1 := '(type='||:file_typ||' skip_header='||:skp_hdr||' field_delimiter=\''||:fld_dlm||'\' empty_field_as_null = TRUE)';
	else
		file_format1 := '(type='||:file_typ||')';
	end if;
		
	create_stage_stmt := 'CREATE OR REPLACE TEMPORARY STAGE mydb.external_stages.s3_stage
	URL = \''|| :st_loc || '\'
	STORAGE_INTEGRATION = '|| :st_int ||'
	FILE_FORMAT = ' ||:file_format1 ;

    execute immediate create_stage_stmt;
	
	fp := substring(:file_pat, 3, length(:file_pat)-4);
    
    list @mydb.external_stages.s3_stage;
        
	SELECT COUNT(1) INTO cnt FROM table(result_scan(last_query_id()));
	
	if (:cnt > 0) then

        copy_stmt := 'COPY INTO '||:db||'.'||:sch||'.'||:tbl || '
		FROM @mydb.external_stages.s3_stage
		pattern = \'' || :file_pat || '\' 
		ON_ERROR = ' || :on_err  || '
		FORCE = ' || :forc  || '
		TRUNCATECOLUMNS = ' || :trun_col 
        ;

       execute immediate copy_stmt;
		
		ret := :ret || :fp || ' Format files completed successfully. \n';
	
	else
		ret := :ret || :fp || ' Format files not present in the external stage. \n';
	end if;

end for;

return :ret;

end;

-- counts before executing the procedure
/*
select count(1) from mydb.staging.account_data; -- 0
select count(1) from mydb.staging.customer_data; -- 0
*/

call mydb.staging.sp_automate_data_copy();

-- counts after executing the procedure
/*
select count(1) from mydb.staging.account_data; -- 220
select count(1) from mydb.staging.customer_data; -- 220
*/




CREATE SCHEMA IF NOT EXISTS mydb.target;

CREATE OR REPLACE TABLE mydb.target.customer_scd2 (
    cust_identifier STRING,
    first_name STRING,
    last_name STRING,
    age NUMBER,
    gender STRING,
    city STRING,
    state STRING,
    country STRING,
    signup_date DATE,
    status STRING,
    credit_score NUMBER,
    income NUMBER,

    eff_start_date TIMESTAMP,
    eff_end_date TIMESTAMP,
    is_active BOOLEAN,
    dw_lod_tmp TIMESTAMP,
    dw_upd_lod_tmp TIMESTAMP
);

CREATE OR REPLACE STREAM mydb.staging.stream_customer
ON TABLE mydb.staging.customer_data;

CREATE OR REPLACE PROCEDURE mydb.target.proc_customer_scd2()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    cur_ts TIMESTAMP;
BEGIN
    cur_ts := CURRENT_TIMESTAMP();

    -- 🔴 STEP 1: Expire old records ONLY if data changed
    UPDATE mydb.target.customer_scd2 tgt
    SET 
        eff_end_date = :cur_ts,
        is_active = FALSE,
        dw_upd_lod_tmp = :cur_ts
    FROM mydb.staging.stream_customer src
    WHERE tgt.cust_identifier = src.cust_identifier
      AND tgt.is_active = TRUE
      AND (
            NVL(tgt.first_name,'') <> NVL(src.first_name,'') OR
            NVL(tgt.last_name,'') <> NVL(src.last_name,'') OR
            NVL(tgt.age,0) <> NVL(src.age,0) OR
            NVL(tgt.city,'') <> NVL(src.city,'') OR
            NVL(tgt.state,'') <> NVL(src.state,'') OR
            NVL(tgt.status,'') <> NVL(src.status,'') OR
            NVL(tgt.credit_score,0) <> NVL(src.credit_score,0) OR
            NVL(tgt.income,0) <> NVL(src.income,0)
          );

    -- 🟢 STEP 2: Insert NEW + CHANGED records
    INSERT INTO mydb.target.customer_scd2
    SELECT
        cust_identifier,
        first_name,
        last_name,
        age,
        gender,
        city,
        state,
        country,
        signup_date,
        status,
        credit_score,
        income,
        :cur_ts,
        NULL,
        TRUE,
        :cur_ts,
        :cur_ts
    FROM mydb.staging.stream_customer
    WHERE METADATA$ACTION = 'INSERT';

    RETURN 'SCD2 LOAD COMPLETED';
END;
$$;

CREATE OR REPLACE TASK mydb.target.task_customer_scd2
WAREHOUSE = COMPUTE_WH
SCHEDULE = '1 MINUTES'
WHEN SYSTEM$STREAM_HAS_DATA('mydb.staging.stream_customer')
AS
CALL mydb.target.proc_customer_scd2();

ALTER TASK mydb.target.task_customer_scd2 RESUME;

SELECT * 
FROM mydb.staging.stream_customer;

SELECT * 
FROM mydb.staging.customer_data;
