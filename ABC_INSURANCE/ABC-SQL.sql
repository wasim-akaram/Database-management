 
-- 1. DATABASE & SCHEMA
 
CREATE OR REPLACE DATABASE ABC;
USE DATABASE ABC;

CREATE OR REPLACE SCHEMA RAW_SH;

USE SCHEMA RAW_SH;

 
-- 2. FILE FORMATS

CREATE OR REPLACE FILE FORMAT CSV_FORMAT
TYPE = CSV
FIELD_DELIMITER = ','
SKIP_HEADER = 1
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
NULL_IF = ('NULL', 'null', '');

CREATE OR REPLACE FILE FORMAT JSON_FORMAT
TYPE = JSON;

 
-- 3. STAGE
 
CREATE OR REPLACE STAGE INSURANCE_STAGE;

 
-- 4. RAW TABLES
 
CREATE OR REPLACE TABLE POLICY_RAW (
    raw_data VARIANT,
    file_name STRING,
    load_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE TABLE CLAIMS_RAW (
    raw_data VARIANT,
    file_name STRING,
    load_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

 
-- 5. STREAMS
 
CREATE OR REPLACE STREAM POLICY_STREAM
ON TABLE POLICY_RAW;

CREATE OR REPLACE STREAM CLAIMS_STREAM
ON TABLE CLAIMS_RAW;

 
-- 6. LOAD POLICY DATA
 
COPY INTO POLICY_RAW (raw_data, file_name)
FROM (
    SELECT 
        OBJECT_CONSTRUCT(
            'policy_number', $1,
            'customer_id', $2,
            'first_name', $3,
            'last_name', $4,
            'ssn', $5,
            'email', $6,
            'phone', $7,
            'address', $8,
            'city', $9,
            'state', $10,
            'zip', $11,
            'policy_type', $12,
            'effective_date', $13,
            'expiration_date', $14,
            'annual_premium', $15,
            'payment_frequency', $16,
            'renewal_flag', $17,
            'policy_status', $18,
            'marital_status', $19,
            'agent_id', $20,
            'agency_name', $21,
            'agency_region', $22
        ),
        METADATA$FILENAME
    FROM @INSURANCE_STAGE
)
FILE_FORMAT = (FORMAT_NAME = CSV_FORMAT)
PATTERN = '.*policies.*\\.csv'
ON_ERROR = 'CONTINUE'
FORCE = FALSE;

 
-- 7. LOAD CLAIM DATA
 
COPY INTO CLAIMS_RAW (raw_data, file_name)
FROM (
    SELECT 
        $1,
        METADATA$FILENAME
    FROM @INSURANCE_STAGE
)
FILE_FORMAT = (FORMAT_NAME = JSON_FORMAT)
PATTERN = '.*claims.*\\.json'
ON_ERROR = 'CONTINUE'
FORCE = FALSE;

 
-- 8. VERIFY DATA
 
SELECT * FROM POLICY_RAW LIMIT 10;
SELECT * FROM CLAIMS_RAW LIMIT 10;

 
-- 9. VERIFY STREAM
 
SELECT * FROM POLICY_STREAM LIMIT 10;
SELECT * FROM CLAIMS_STREAM LIMIT 10;




----validation




  
-- 1. SCHEMA
  


CREATE OR REPLACE SCHEMA VALIDATION_SH;
USE SCHEMA VALIDATION_SH;

  
-- 2. VALIDATED POLICY TABLE
  
CREATE OR REPLACE TABLE VALIDATION_SH.VALIDATED_POLICIES (
    policy_number STRING,
    customer_id STRING,
    first_name STRING,
    last_name STRING,
    email STRING,
    phone STRING,
    state STRING,
    city STRING,
    zip STRING,
    policy_type STRING,
    effective_date DATE,
    expiration_date DATE,
    annual_premium NUMBER,
    policy_status STRING,
    agent_id STRING,

    agency_name STRING,
    agency_region STRING,

    -- VALIDATION FLAGS
    is_valid_email BOOLEAN,
    is_valid_phone BOOLEAN,
    is_valid_dates BOOLEAN,
    is_valid_premium BOOLEAN,

    source_file STRING,
    load_time TIMESTAMP
);
  
-- 3. VALIDATED CLAIM TABLE
  
CREATE OR REPLACE TABLE VALIDATED_CLAIMS (
    claim_id STRING,
    policy_number STRING,
    customer_id STRING,
    state STRING,
    city STRING,
    claim_type STRING,
    incident_date DATE,
    fnol_datetime TIMESTAMP,
    total_incurred NUMBER,
    total_paid NUMBER,

    -- VALIDATION
    fnol_delay_days NUMBER,

    source_file STRING,
    load_time TIMESTAMP
);

  
-- 4. POLICY VALIDATION
  
INSERT INTO VALIDATION_SH.VALIDATED_POLICIES
SELECT
    raw_data:policy_number::STRING,
    raw_data:customer_id::STRING,
    raw_data:first_name::STRING,
    raw_data:last_name::STRING,
    raw_data:email::STRING,
    raw_data:phone::STRING,
    raw_data:state::STRING,
    raw_data:city::STRING,
    raw_data:zip::STRING,
    raw_data:policy_type::STRING,

    TRY_TO_DATE(raw_data:effective_date::STRING),
    TRY_TO_DATE(raw_data:expiration_date::STRING),

    TRY_TO_NUMBER(REPLACE(raw_data:annual_premium::STRING, ',', '')),
    raw_data:policy_status::STRING,
    raw_data:agent_id::STRING,

    -- ADD THESE FROM RAW
    raw_data:agency_name::STRING,
    raw_data:agency_region::STRING,

    -- VALIDATIONS
    CASE 
        WHEN raw_data:email::STRING RLIKE '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
        THEN TRUE ELSE FALSE END,

    CASE 
        WHEN LENGTH(REGEXP_REPLACE(raw_data:phone::STRING, '[^0-9]', '')) BETWEEN 10 AND 15
        THEN TRUE ELSE FALSE END,

    CASE 
        WHEN TRY_TO_DATE(raw_data:effective_date::STRING) 
             < TRY_TO_DATE(raw_data:expiration_date::STRING)
        THEN TRUE ELSE FALSE END,

    CASE 
        WHEN TRY_TO_NUMBER(REPLACE(raw_data:annual_premium::STRING, ',', '')) > 0
        THEN TRUE ELSE FALSE END,

    file_name,
    CURRENT_TIMESTAMP

FROM RAW_SH.POLICY_RAW;
  
-- 5. CLAIM VALIDATION
  
INSERT INTO VALIDATED_CLAIMS
SELECT
    raw_data:claim_id::STRING,
    raw_data:policy_number::STRING,
    raw_data:customer_id::STRING,

    raw_data:address:state::STRING,
    raw_data:address:city::STRING,

    raw_data:claim_type::STRING,

    TRY_TO_DATE(raw_data:incident_date::STRING),
    TRY_TO_TIMESTAMP(raw_data:fnol_datetime::STRING),

    TRY_TO_NUMBER(REPLACE(raw_data:total_incurred::STRING, ',', '')),
    TRY_TO_NUMBER(REPLACE(raw_data:total_paid::STRING, ',', '')),

    -- REQ4 VALIDATION
    DATEDIFF('day',
        TRY_TO_DATE(raw_data:incident_date::STRING),
        TRY_TO_TIMESTAMP(raw_data:fnol_datetime::STRING)
    ),

    file_name,
    CURRENT_TIMESTAMP

FROM RAW_SH.CLAIMS_RAW;



----curated layer

  
-- 1. CREATE SCHEMA
  


CREATE OR REPLACE SCHEMA CURATED_SH;
USE SCHEMA CURATED_SH;

  
-- 2. DIMENSION TABLES
  

-- AGENT DIM
CREATE OR REPLACE TABLE CURATED_SH.DIM_AGENT AS
SELECT DISTINCT
    agent_id,
    agency_name,
    agency_region
FROM VALIDATION_SH.VALIDATED_POLICIES;

-- LOCATION DIM
CREATE OR REPLACE TABLE DIM_LOCATION AS
SELECT DISTINCT
    state,
    city,
    zip
FROM VALIDATION_SH.VALIDATED_POLICIES;

  
-- 3. FACT TABLES
  

-- FACT POLICIES
CREATE OR REPLACE TABLE FACT_POLICIES AS
SELECT
    policy_number,
    customer_id,
    agent_id,
    state,
    city,
    annual_premium,
    policy_status,
    effective_date,
    expiration_date,

    -- Derived Metrics
    CASE 
        WHEN is_valid_email = FALSE OR is_valid_phone = FALSE 
        THEN 1 ELSE 0 
    END AS invalid_contact_flag,

    CASE 
        WHEN is_valid_dates = FALSE OR is_valid_premium = FALSE 
        THEN 1 ELSE 0 
    END AS invalid_policy_flag

FROM VALIDATION_SH.VALIDATED_POLICIES;

-- FACT CLAIMS
CREATE OR REPLACE TABLE FACT_CLAIMS AS
SELECT
    claim_id,
    policy_number,
    customer_id,
    state,
    city,
    total_incurred,
    total_paid,
    fnol_delay_days,

    -- Derived Metrics
    (total_incurred - total_paid) AS claim_gap,

    CASE 
        WHEN fnol_delay_days > 2 THEN 1 ELSE 0 
    END AS late_claim_flag

FROM VALIDATION_SH.VALIDATED_CLAIMS;



-- REQ1: Invalid Contact %
CREATE OR REPLACE VIEW KPI_INVALID_CONTACT AS
SELECT agent_id,
(SUM(invalid_contact_flag) * 100.0) / COUNT(*) AS invalid_contact_percentage
FROM FACT_POLICIES
GROUP BY agent_id;

-- REQ2: Invalid Policy %
CREATE OR REPLACE VIEW KPI_INVALID_POLICY AS
SELECT state,
(SUM(invalid_policy_flag) * 100.0) / COUNT(*) AS invalid_percentage
FROM FACT_POLICIES
GROUP BY state;

-- REQ3: Agent Performance
CREATE OR REPLACE VIEW KPI_AGENT_PERFORMANCE AS
SELECT agent_id,
SUM(annual_premium) AS total_premium,
COUNT(*) AS total_policies
FROM FACT_POLICIES
GROUP BY agent_id;

-- REQ4: FNOL Lag
CREATE OR REPLACE VIEW KPI_FNOL_LAG AS
SELECT 
AVG(fnol_delay_days) AS avg_delay,
(SUM(late_claim_flag) * 100.0) / COUNT(*) AS late_claim_percentage
FROM FACT_CLAIMS;

-- REQ7: Claim Difference
CREATE 
OR REPLACE VIEW KPI_CLAIM_DIFF AS
SELECT 
AVG(claim_gap) AS avg_claim_difference
FROM FACT_CLAIMS;



--RUN THIS TO DISPLAY THE RESULT
-- REQ1
SELECT * FROM CURATED_SH.KPI_INVALID_CONTACT;

-- REQ2
SELECT * FROM CURATED_SH.KPI_INVALID_POLICY;

-- REQ3
SELECT * FROM CURATED_SH.KPI_AGENT_PERFORMANCE;

-- REQ4
SELECT * FROM CURATED_SH.KPI_FNOL_LAG;

-- REQ7
SELECT * FROM CURATED_SH.KPI_CLAIM_DIFF;


------ SECURITY

-- 1. CREATE SCHEMA
  


CREATE OR REPLACE SCHEMA SECURITY_SH;
USE SCHEMA SECURITY_SH;

  
-- 2. ROLES
  
CREATE OR REPLACE ROLE ADMIN_ROLE;
CREATE OR REPLACE ROLE ANALYST_ROLE;

  
-- 3. DYNAMIC DATA MASKING
  

-- EMAIL MASKING
CREATE OR REPLACE MASKING POLICY EMAIL_MASK AS (val STRING)
RETURNS STRING ->
CASE
    WHEN CURRENT_ROLE() = 'ADMIN_ROLE' THEN val
    ELSE '****@****.com'
END;

-- PHONE MASKING
CREATE OR REPLACE MASKING POLICY PHONE_MASK AS (val STRING)
RETURNS STRING ->
CASE
    WHEN CURRENT_ROLE() = 'ADMIN_ROLE' THEN val
    ELSE 'XXXXXXXXXX'
END;

  
-- 4. APPLY MASKING
  
ALTER TABLE VALIDATION_SH.VALIDATED_POLICIES
MODIFY COLUMN email SET MASKING POLICY EMAIL_MASK;

ALTER TABLE VALIDATION_SH.VALIDATED_POLICIES
MODIFY COLUMN phone SET MASKING POLICY PHONE_MASK;

  
-- 5. ROW ACCESS POLICY (REGION BASED)
  
CREATE OR REPLACE ROW ACCESS POLICY REGION_POLICY
AS (region STRING) RETURNS BOOLEAN ->
CASE
    WHEN CURRENT_ROLE() = 'ADMIN_ROLE' THEN TRUE
    WHEN CURRENT_ROLE() = 'ANALYST_ROLE' AND region = 'EAST' THEN TRUE
    ELSE FALSE
END;

ALTER TABLE VALIDATION_SH.VALIDATED_POLICIES
ADD ROW ACCESS POLICY REGION_POLICY ON (agency_region);

  
-- 6. APPLY ROW ACCESS POLICY
  
ALTER TABLE VALIDATION_SH.VALIDATED_POLICIES
ADD ROW ACCESS POLICY REGION_POLICY ON (agency_region);

  
-- 7. GRANTS
  
GRANT SELECT ON ALL TABLES IN SCHEMA VALIDATION_SH TO ROLE ANALYST_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA CURATED_SH TO ROLE ANALYST_ROLE;

  
-- 8. TEST
  
USE ROLE ANALYST_ROLE;

SELECT email, phone FROM VALIDATION_SH.VALIDATED_POLICIES;