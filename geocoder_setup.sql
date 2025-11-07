------------------------------------------------------
-- Complete Geocoding Demo
-- Creates source and destination tables, and a process
-- to geocode addresses that haven't been processed yet
------------------------------------------------------

------------------------------------------------------
-- SETUP INSTRUCTIONS
------------------------------------------------------
/*
1. Go to https://account.here.com/ and create a free account
2. Once logged in, go to REST APIs > Access Manager
3. Click "Create new app" > give it a name > click "Create app"
4. Click "Create API key"
5. Copy the API key and replace 'YOUR_API_KEY_HERE' in the SECRET creation below
*/


------------------------------------------------------
-- Create DB and Schema
------------------------------------------------------
USE ROLE ACCOUNTADMIN;
CREATE DATABASE DEMO_GEOCODE;
CREATE SCHEMA DEMO_GEOCODE.ADDRESS_PROCESSING;

USE DATABASE DEMO_GEOCODE;
USE SCHEMA ADDRESS_PROCESSING;


------------------------------------------------------------------------------------------------
-- Create Network Rule for HERE API
------------------------------------------------------------------------------------------------
CREATE OR REPLACE NETWORK RULE here_geocode_network_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('geocode.search.hereapi.com');


------------------------------------------------------------------------------------------------
-- Create Secret to Store API Key
------------------------------------------------------------------------------------------------
CREATE OR REPLACE SECRET here_api_key_secret
TYPE = GENERIC_STRING 
--SECRET_STRING = 'YOUR_API_KEY_HERE';  -- Replace with your actual HERE API key


------------------------------------------------------------------------------------------------
-- Create External Access Integration
------------------------------------------------------------------------------------------------
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION here_geocode_integration
  ALLOWED_NETWORK_RULES = (here_geocode_network_rule)
  ALLOWED_AUTHENTICATION_SECRETS = (DEMO_GEOCODE.ADDRESS_PROCESSING.here_api_key_secret)
  ENABLED = true;


------------------------------------------------------------------------------------------------
-- Create Python UDF to Call HERE API
------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION geocode_address(address_string STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.10
HANDLER = 'geocode_address'
EXTERNAL_ACCESS_INTEGRATIONS = (here_geocode_integration)
PACKAGES = ('snowflake-snowpark-python','requests')
SECRETS = ('here_api_key' = here_api_key_secret)
AS
$$
import _snowflake
import requests
import json
import urllib.parse

session = requests.Session()

def geocode_address(address_string):
    try:
        api_key = _snowflake.get_generic_secret_string('here_api_key')
        # URL encode the address
        encoded_address = urllib.parse.quote(address_string)
        url = f"https://geocode.search.hereapi.com/v1/geocode?q={encoded_address}&apiKey={api_key}"
        response = session.get(url)
        return response.text
    except Exception as e:
        return json.dumps({"error": str(e)})
$$;


------------------------------------------------------------------------------------------------
-- Create Source_Addresses Table
------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE Source_Addresses (
    Name VARCHAR(255),
    Department VARCHAR(100),
    Address_ID INTEGER AUTOINCREMENT,
    Address_Source_ID VARCHAR(100),
    Address VARCHAR(500),
    GeoCoded VARCHAR(3) DEFAULT 'No'
);


------------------------------------------------------------------------------------------------
-- Create Geocoded_Addresses Table
------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE Geocoded_Addresses (
    Geocoded_ID INTEGER AUTOINCREMENT,
    Name VARCHAR(255),
    Department VARCHAR(100),
    Address_ID INTEGER,
    Address_Source_ID VARCHAR(100),
    Address VARCHAR(500),
    Street VARCHAR(255),
    City VARCHAR(100),
    State VARCHAR(100),
    Zip VARCHAR(20),
    Lat FLOAT,
    Long FLOAT,
    Geocoded_Timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() 
);


------------------------------------------------------------------------------------------------
-- Insert Sample Addresses
------------------------------------------------------------------------------------------------
INSERT INTO Source_Addresses (Name, Address_Source_ID, Department, Address, GeoCoded) VALUES
    ('Miami Beach Property', 'A1', 'Sales', '4601 Collins Ave Miami Beach FL 33140', 'No'),
    ('Rochester Home', 'A2','Marketing', '114 Orland Rd Rochester NY 14622', 'No'),
    ('Greenville Residence','A3', 'Sales', '103 Autumn Rd Greenville SC 29650', 'No'),
        ('Clemson1', 'A4', 'Student', '217 W Main ST Central SC 29630', 'No'),
        ('Clemson2', 'A5', 'Student', '119 N Townville St Seneca SC 29678', 'No'),
        ('Clemson3', 'A6', 'Student', '356 Clemosn St Clemson SC 29631', 'No')
;


-- testing rest
delete from Geocoded_Addresses;
delete from Source_Addresses;
update Source_Addresses set GeoCoded = 'No';
------------------------------------------------------------------------------------------------
-- Create Stored Procedure to Process Ungeocoded Addresses
------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE Process_Ungeocoded_Addresses()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    processed_count INTEGER DEFAULT 0;
    error_count INTEGER DEFAULT 0;
    total_count INTEGER DEFAULT 0;
    result_message STRING;
BEGIN
    -- Get count of addresses to process
    SELECT COUNT(*) INTO :total_count
    FROM Source_Addresses
    WHERE GeoCoded = 'No';
    
    -- Process each ungeocoded address
    INSERT INTO Geocoded_Addresses (Name, Department, Address_ID, Address_Source_ID, Address, Street, City, State, Zip, Lat, Long)
    WITH addresses_to_process AS (
        SELECT 
            Name,
            Department,
            Address_ID,
            Address_Source_ID, 
            Address
        FROM Source_Addresses
        WHERE GeoCoded = 'No'
    ),
    geocoded_data AS (
        SELECT
            a.Name,
            a.Department,
            a.Address_ID,
            a.Address_Source_ID, 
            a.Address,
            PARSE_JSON(geocode_address(a.Address))::VARIANT AS api_response
        FROM addresses_to_process a
    ),
    parsed_results AS (
        SELECT
            g.Name,
            g.Department,
            g.Address_ID,
            g.Address_Source_ID, 
            g.Address,
            f.value:address.street::STRING AS street,
            f.value:address.city::STRING AS city,
            f.value:address.state::STRING AS state,
            f.value:address.postalCode::STRING AS zip,
            f.value:position.lat::FLOAT AS lat,
            f.value:position.lng::FLOAT AS long
        FROM geocoded_data g,
        LATERAL FLATTEN(input => g.api_response:items) f
    )
    SELECT 
        Name,
        Department,
        Address_ID,
        Address_Source_ID, 
        Address,
        street,
        city,
        state,
        zip,
        lat,
        long
    FROM parsed_results
    WHERE lat IS NOT NULL;  -- Only insert successful geocodes
    
    -- Get count of successfully processed addresses
    processed_count := SQLROWCOUNT;
    
    -- Update GeoCoded flag for successfully processed addresses
    UPDATE Source_Addresses
    SET GeoCoded = 'Yes'
    WHERE Address_ID IN (
        SELECT Address_ID 
        FROM Geocoded_Addresses 
        WHERE Address_ID NOT IN (
            SELECT Address_ID 
            FROM Source_Addresses 
            WHERE GeoCoded = 'Yes'
        )
    )
    AND GeoCoded = 'No';
    
    -- Calculate errors
    error_count := total_count - processed_count;
    
    -- Build result message
    result_message := 'Processing Complete. Total addresses to process: ' || total_count || 
                     ', Successfully geocoded: ' || processed_count || 
                     ', Errors: ' || error_count;
    
    RETURN result_message;
END;
$$;


------------------------------------------------------------------------------------------------
-- View Addresses That Need Geocoding
------------------------------------------------------------------------------------------------
SELECT 
    Address_ID,
    Address_Source_ID, 
    Name,
    Department,
    Address,
    GeoCoded
FROM Source_Addresses
WHERE GeoCoded = 'No'
ORDER BY Address_ID;


------------------------------------------------------------------------------------------------
-- EXECUTE THE GEOCODING PROCESS
-- Uncomment the line below to run the geocoding process
------------------------------------------------------------------------------------------------
CALL Process_Ungeocoded_Addresses();


------------------------------------------------------------------------------------------------
-- View All Source Addresses and Their Status
------------------------------------------------------------------------------------------------
SELECT 
    Address_ID,
    Address_Source_ID, 
    Name,
    Department,
    Address,
    GeoCoded
FROM Source_Addresses
ORDER BY Address_ID;


------------------------------------------------------------------------------------------------
-- View All Geocoded Results
------------------------------------------------------------------------------------------------
SELECT 
    Geocoded_ID,
    Name,
    Department,
    Address_ID,
    Address_Source_ID, 
    Address,
    Street,
    City,
    State,
    Zip,
    Lat,
    Long,
    Geocoded_Timestamp
FROM Geocoded_Addresses
ORDER BY Address_ID;


-- Test some samples
select address,  'https://www.google.com/maps?q=' || lat || ',' || long FROM Geocoded_Addresses where GEOCODED_TIMESTAMP is not null limit 5;


------------------------------------------------------------------------------------------------
-- View Joined Data (Source + Geocoded Results)
------------------------------------------------------------------------------------------------
SELECT 
    s.Address_ID,
    s.Address_Source_ID, 
    s.Name,
    s.Department,
    s.Address AS Original_Address,
    s.GeoCoded,
    g.Street,
    g.City,
    g.State,
    g.Zip,
    g.Lat,
    g.Long,
    g.Geocoded_Timestamp
FROM Source_Addresses s
LEFT JOIN Geocoded_Addresses g ON s.Address_ID = g.Address_ID
ORDER BY s.Address_ID;


------------------------------------------------------------------------------------------------
-- Add More Addresses to Process (Example)
------------------------------------------------------------------------------------------------
/*
INSERT INTO Source_Addresses (Name, Department, Address, GeoCoded) VALUES
    ('Test Address 1', 'Sales', '1 Market St San Francisco CA 94105', 'No'),
    ('Test Address 2', 'Marketing', '1060 W Addison St Chicago IL 60613', 'No');

-- Then run the process again
CALL Process_Ungeocoded_Addresses();
*/


------------------------------------------------------------------------------------------------
-- Manual Test of Single Address Geocoding
------------------------------------------------------------------------------------------------
/*
SELECT 
    '4601 Collins Ave Miami Beach FL 33140' AS test_address,
    PARSE_JSON(geocode_address('4601 Collins Ave Miami Beach FL 33140'))::VARIANT AS api_response;

-- Parse the results
WITH test_geocode AS (
    SELECT PARSE_JSON(geocode_address('4601 Collins Ave Miami Beach FL 33140'))::VARIANT AS api_response
)
SELECT
    f.value:address.houseNumber::STRING AS house_number,
    f.value:address.street::STRING AS street,
    f.value:address.city::STRING AS city,
    f.value:address.state::STRING AS state,
    f.value:address.stateCode::STRING AS state_code,
    f.value:address.postalCode::STRING AS zip,
    f.value:position.lat::FLOAT AS lat,
    f.value:position.lng::FLOAT AS long
FROM test_geocode,
LATERAL FLATTEN(input => test_geocode.api_response:items) f;
*/


------------------------------------------------------------------------------------------------
-- Error Handling: Find Addresses That Failed to Geocode
------------------------------------------------------------------------------------------------
SELECT 
    s.Address_ID,
    s.Address_Source_ID, 
    s.Name,
    s.Department,
    s.Address,
    s.GeoCoded
FROM Source_Addresses s
LEFT JOIN Geocoded_Addresses g ON s.Address_ID = g.Address_ID
WHERE g.Address_ID IS NULL 
  AND s.GeoCoded = 'No'
ORDER BY s.Address_ID;


------------------------------------------------------------------------------------------------
-- Reset Demo (Clears all geocoded data and resets flags)
------------------------------------------------------------------------------------------------
/*
DELETE FROM Geocoded_Addresses;
UPDATE Source_Addresses SET GeoCoded = 'No';
*/


------------------------------------------------------------------------------------------------
-- Create Monitoring View
------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW Geocoding_Status_View AS
SELECT 
    COUNT(*) as total_addresses,
    SUM(CASE WHEN GeoCoded = 'Yes' THEN 1 ELSE 0 END) as geocoded_count,
    SUM(CASE WHEN GeoCoded = 'No' THEN 1 ELSE 0 END) as pending_count,
    ROUND(100.0 * SUM(CASE WHEN GeoCoded = 'Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) as success_rate_pct
FROM Source_Addresses;

-- View the status
SELECT * FROM Geocoding_Status_View;


------------------------------------------------------------------------------------------------
-- Create Batch Processing Stored Procedure (Process Limited Number)
------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE Process_Ungeocoded_Addresses_Batch(batch_size INTEGER)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    processed_count INTEGER DEFAULT 0;
    total_to_process INTEGER DEFAULT 0;
    result_message STRING;
BEGIN
    -- Get count of addresses to process (limited by batch_size)
    SELECT COUNT(*) INTO :total_to_process
    FROM (
        SELECT Address_ID
        FROM Source_Addresses
        WHERE GeoCoded = 'No'
        LIMIT :batch_size
    );
    
    -- Process batch of ungeocoded addresses
    INSERT INTO Geocoded_Addresses (Name, Department, Address_ID, Address_Source_ID,  Address, Street, City, State, Zip, Lat, Long)
    WITH addresses_to_process AS (
        SELECT 
            Name,
            Department,
            Address_ID,
            Address_Source_ID, 
            Address
        FROM Source_Addresses
        WHERE GeoCoded = 'No'
        LIMIT :batch_size
    ),
    geocoded_data AS (
        SELECT
            a.Name,
            a.Department,
            a.Address_ID,
            a.Address_Source_ID, 
            a.Address,
            PARSE_JSON(geocode_address(a.Address))::VARIANT AS api_response
        FROM addresses_to_process a
    ),
    parsed_results AS (
        SELECT
            g.Name,
            g.Department,
            g.Address_ID,
            g.Address_Source_ID, 
            g.Address,
            f.value:address.street::STRING AS street,
            f.value:address.city::STRING AS city,
            f.value:address.state::STRING AS state,
            f.value:address.postalCode::STRING AS zip,
            f.value:position.lat::FLOAT AS lat,
            f.value:position.lng::FLOAT AS long
        FROM geocoded_data g,
        LATERAL FLATTEN(input => g.api_response:items) f
    )
    SELECT 
        Name,
        Department,
        Address_ID,
        Address_Source_ID, 
        Address,
        street,
        city,
        state,
        zip,
        lat,
        long
    FROM parsed_results
    WHERE lat IS NOT NULL;
    
    -- Get count of successfully processed addresses
    processed_count := SQLROWCOUNT;
    
    -- Update GeoCoded flag for successfully processed addresses
    UPDATE Source_Addresses
    SET GeoCoded = 'Yes'
    WHERE Address_ID IN (
        SELECT Address_ID 
        FROM Geocoded_Addresses 
        WHERE Address_ID NOT IN (
            SELECT Address_ID 
            FROM Source_Addresses 
            WHERE GeoCoded = 'Yes'
        )
    )
    AND GeoCoded = 'No';
    
    -- Build result message
    result_message := 'Batch Processing Complete. Batch size limit: ' || batch_size || 
                     ', Addresses found to process: ' || total_to_process ||
                     ', Successfully geocoded: ' || processed_count;
    
    RETURN result_message;
END;
$$;


------------------------------------------------------------------------------------------------
-- Example: Process in Batches of 100
------------------------------------------------------------------------------------------------
 
CALL Process_Ungeocoded_Addresses_Batch(100);
 


------------------------------------------------------------------------------------------------
-- Create View for Geocoding History/Analytics
------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW Geocoding_Analytics_View AS
SELECT 
    DATE_TRUNC('day', Geocoded_Timestamp) as geocoded_date,
    Department,
    COUNT(*) as addresses_geocoded, 
    COUNT(DISTINCT State) as states_covered,
    COUNT(DISTINCT City) as cities_covered,
    AVG(Lat) as avg_latitude,
    AVG(Long) as avg_longitude
FROM Geocoded_Addresses
GROUP BY DATE_TRUNC('day', Geocoded_Timestamp), Department
ORDER BY geocoded_date DESC, Department;

-- View analytics
SELECT * FROM Geocoding_Analytics_View;


------------------------------------------------------------------------------------------------
-- Create View for Failed/Unprocessed Addresses
------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW Unprocessed_Addresses_View AS
SELECT 
    s.Address_ID,
    s.Address_Source_ID, 
    s.Name,
    s.Department,
    s.Address,
    s.GeoCoded
FROM Source_Addresses s
LEFT JOIN Geocoded_Addresses g ON s.Address_ID = g.Address_ID
WHERE g.Address_ID IS NULL 
  AND s.GeoCoded = 'No'
ORDER BY s.Address_ID;

-- View unprocessed addresses
SELECT * FROM Unprocessed_Addresses_View;


------------------------------------------------------------------------------------------------
-- Department-Specific Queries (For Centralized Multi-Department Usage)
------------------------------------------------------------------------------------------------

-- View addresses by department
SELECT 
    Department,
    COUNT(*) as total_addresses,
    SUM(CASE WHEN GeoCoded = 'Yes' THEN 1 ELSE 0 END) as geocoded,
    SUM(CASE WHEN GeoCoded = 'No' THEN 1 ELSE 0 END) as pending
FROM Source_Addresses
GROUP BY Department
ORDER BY Department;


-- View geocoded results for a specific department
-- (Replace 'Sales' with your department name)
SELECT 
    Name,
    Address,
    City,
    State,
    Zip,
    Lat,
    Long,
    Geocoded_Timestamp
FROM Geocoded_Addresses
WHERE Department = 'Sales'
ORDER BY Geocoded_Timestamp DESC;


-- Get addresses for a specific department that need geocoding
SELECT 
    Address_ID,
    Address_Source_ID, 
    Name,
    Address
FROM Source_Addresses
WHERE Department = 'Marketing'
  AND GeoCoded = 'No'
ORDER BY Address_ID;


-- Summary statistics by department
SELECT 
    Department,
    COUNT(*) as total_geocoded,
    COUNT(DISTINCT State) as states_covered,
    COUNT(DISTINCT City) as cities_covered,
    MIN(Geocoded_Timestamp) as first_geocoded,
    MAX(Geocoded_Timestamp) as last_geocoded
FROM Geocoded_Addresses
GROUP BY Department
ORDER BY total_geocoded DESC;


-- Department usage over time (last 30 days)
SELECT 
    DATE(Geocoded_Timestamp) as geocoded_date,
    Department,
    COUNT(*) as addresses_geocoded
FROM Geocoded_Addresses
WHERE Geocoded_Timestamp >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY DATE(Geocoded_Timestamp), Department
ORDER BY geocoded_date DESC, Department;


-- Create a view for department summary
CREATE OR REPLACE VIEW Department_Summary_View AS
SELECT 
    s.Department,
    COUNT(DISTINCT s.Address_ID) as total_addresses,
    SUM(CASE WHEN s.GeoCoded = 'Yes' THEN 1 ELSE 0 END) as geocoded_count,
    SUM(CASE WHEN s.GeoCoded = 'No' THEN 1 ELSE 0 END) as pending_count,
    COUNT(DISTINCT g.State) as states_covered,
    COUNT(DISTINCT g.City) as cities_covered,
    MIN(g.Geocoded_Timestamp) as first_address_geocoded,
    MAX(g.Geocoded_Timestamp) as most_recent_geocoded
FROM Source_Addresses s
LEFT JOIN Geocoded_Addresses g ON s.Address_ID = g.Address_ID
GROUP BY s.Department
ORDER BY total_addresses DESC;

-- View department summary
SELECT * FROM Department_Summary_View;


------------------------------------------------------------------------------------------------
-- Optional: Create Task for Scheduled Processing
------------------------------------------------------------------------------------------------
/*
-- Create a task to run every hour
CREATE OR REPLACE TASK geocode_addresses_task
  WAREHOUSE = COMPUTE_WH  -- Change to your warehouse name
  SCHEDULE = 'USING CRON 0 * * * * America/New_York'  -- Every hour
AS
  CALL Process_Ungeocoded_Addresses();

-- Enable the task
ALTER TASK geocode_addresses_task RESUME;

-- Check task status
SHOW TASKS LIKE 'geocode_addresses_task';

-- View task history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME = 'GEOCODE_ADDRESSES_TASK'
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;

-- Suspend the task when not needed
ALTER TASK geocode_addresses_task SUSPEND;

-- Drop the task
DROP TASK IF EXISTS geocode_addresses_task;
*/


------------------------------------------------------------------------------------------------
-- Cleanup (Drop everything)
------------------------------------------------------------------------------------------------
/*
DROP TASK IF EXISTS geocode_addresses_task;
DROP VIEW IF EXISTS Department_Summary_View;
DROP VIEW IF EXISTS Unprocessed_Addresses_View;
DROP VIEW IF EXISTS Geocoding_Analytics_View;
DROP VIEW IF EXISTS Geocoding_Status_View;
DROP PROCEDURE IF EXISTS Process_Ungeocoded_Addresses_Batch;
DROP PROCEDURE IF EXISTS Process_Ungeocoded_Addresses;
DROP TABLE IF EXISTS Geocoded_Addresses;
DROP TABLE IF EXISTS Source_Addresses;
DROP FUNCTION IF EXISTS geocode_address(STRING);
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS here_geocode_integration;
DROP SECRET IF EXISTS here_api_key_secret;
DROP NETWORK RULE IF EXISTS here_geocode_network_rule;
DROP SCHEMA IF EXISTS DEMO_GEOCODE.ADDRESS_PROCESSING;
DROP DATABASE IF EXISTS DEMO_GEOCODE;
*/


