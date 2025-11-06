# Snowflake Geocoding - Complete Guide

## Overview

This solution runs **entirely within Snowflake** using External Access Integration to call the HERE Geocoding API. No external servers or applications required!

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        SNOWFLAKE                                 │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Source_Addresses Table                                 │    │
│  │  (Name, Address_ID, Address, GeoCoded)                 │    │
│  └──────────────────────┬─────────────────────────────────┘    │
│                         │                                        │
│                         ▼                                        │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Stored Procedure: Process_Ungeocoded_Addresses()      │    │
│  │  - Selects WHERE GeoCoded = 'No'                       │    │
│  │  - Calls geocode_address() UDF for each                │    │
│  └──────────────────────┬─────────────────────────────────┘    │
│                         │                                        │
│                         ▼                                        │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Python UDF: geocode_address()                         │    │
│  │  - Gets API key from Secret                            │    │
│  │  - Makes HTTP request via External Access Integration  │    │
│  └──────────────────────┬─────────────────────────────────┘    │
│                         │                                        │
│                         ▼                                        │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  External Access Integration                            │    │
│  │  - Network Rule: geocode.search.hereapi.com            │    │
│  │  - Secret: here_api_key_secret                         │    │
│  └──────────────────────┬─────────────────────────────────┘    │
└──────────────────────────┼──────────────────────────────────────┘
                           │
                           ▼  HTTPS Request
                ┌──────────────────────┐
                │   HERE API           │
                │   (External)         │
                └──────────┬───────────┘
                           │
                           ▼  JSON Response
┌──────────────────────────┼──────────────────────────────────────┐
│                        SNOWFLAKE                                 │
│                         │                                        │
│                         ▼                                        │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Parse JSON & Insert into Geocoded_Addresses          │    │
│  │  (Name, Address_ID, Address, Street, City, State,     │    │
│  │   Zip, Lat, Long)                                      │    │
│  └──────────────────────┬─────────────────────────────────┘    │
│                         │                                        │
│                         ▼                                        │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  UPDATE Source_Addresses SET GeoCoded = 'Yes'         │    │
│  └────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

## Step-by-Step Setup

### 1. Get HERE API Key (2 minutes)

1. Go to https://account.here.com/sign-up
2. Create a free account
3. Navigate to **REST APIs** > **Access Manager**
4. Click **"Create new app"** and give it a name
5. Click **"Create API key"**
6. Copy the API key (you'll need it in step 3)

**Free Tier:** 250,000 requests/month

### 2. Open Snowflake Worksheet

1. Log into your Snowflake account
2. Open a new SQL worksheet
3. Open the file `geocode_demo_complete.sql`

### 3. Update API Key

Find this line (around line 44):

```sql
SECRET_STRING = 'YOUR_API_KEY_HERE';  -- Replace with your actual HERE API key
```

Replace `YOUR_API_KEY_HERE` with your actual HERE API key.

### 4. Run the Entire Script

Select all and execute. This will create:

- ✅ Database: `DEMO_GEOCODE`
- ✅ Schema: `ADDRESS_PROCESSING`
- ✅ Network Rule: `here_geocode_network_rule`
- ✅ Secret: `here_api_key_secret`
- ✅ External Access Integration: `here_geocode_integration`
- ✅ Function: `geocode_address()`
- ✅ Table: `Source_Addresses` (with 6 sample addresses)
- ✅ Table: `Geocoded_Addresses` (empty, ready for results)
- ✅ Stored Procedure: `Process_Ungeocoded_Addresses()`

### 5. Verify Setup

Check that sample addresses were inserted:

```sql
SELECT * FROM Source_Addresses;
```

You should see 6 addresses with `GeoCoded = 'No'`.

### 6. Test Single Address (Optional)

Test the UDF with one address:

```sql
SELECT 
    '4601 Collins Ave Miami Beach FL 33140' AS test_address,
    PARSE_JSON(geocode_address('4601 Collins Ave Miami Beach FL 33140'))::VARIANT AS api_response;
```

### 7. Run the Geocoding Process

Process all ungeocoded addresses:

```sql
CALL Process_Ungeocoded_Addresses();
```

You'll see a message like:
```
Processing Complete. Total addresses to process: 6, Successfully geocoded: 6, Errors: 0
```

### 8. View Results

See the geocoded results:

```sql
SELECT 
    Geocoded_ID,
    Name,
    Address,
    City,
    State,
    Zip,
    Lat,
    Long
FROM Geocoded_Addresses
ORDER BY Address_ID;
```

## Key Components Explained

### 1. Network Rule

```sql
CREATE OR REPLACE NETWORK RULE here_geocode_network_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('geocode.search.hereapi.com');
```

**Purpose:** Defines which external endpoints Snowflake can connect to. This is a security feature that ensures your UDFs can only access approved domains.

### 2. Secret

```sql
CREATE OR REPLACE SECRET here_api_key_secret
TYPE = GENERIC_STRING 
SECRET_STRING = 'YOUR_API_KEY_HERE';
```

**Purpose:** Securely stores your API key. The key is encrypted and not visible in queries or logs.

### 3. External Access Integration

```sql
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION here_geocode_integration
  ALLOWED_NETWORK_RULES = (here_geocode_network_rule)
  ALLOWED_AUTHENTICATION_SECRETS = (DEMO_GEOCODE.ADDRESS_PROCESSING.here_api_key_secret)
  ENABLED = true;
```

**Purpose:** Ties together the network rule and secret, creating a secure pathway for external API calls.

### 4. Python UDF

```sql
CREATE OR REPLACE FUNCTION geocode_address(address_string STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.10
HANDLER = 'geocode_address'
EXTERNAL_ACCESS_INTEGRATIONS = (here_geocode_integration)
PACKAGES = ('snowflake-snowpark-python','requests')
SECRETS = ('here_api_key' = here_api_key_secret)
```

**Purpose:** Makes the actual API call to HERE. Uses the external access integration to connect and retrieves the API key from the secret.

### 5. Stored Procedure

```sql
CREATE OR REPLACE PROCEDURE Process_Ungeocoded_Addresses()
```

**Purpose:** Orchestrates the entire workflow:
1. Finds addresses where `GeoCoded = 'No'`
2. Calls `geocode_address()` for each
3. Parses the JSON response
4. Inserts into `Geocoded_Addresses`
5. Updates `GeoCoded = 'Yes'`

## Usage Workflows

### Adding New Addresses

```sql
-- Add one address
INSERT INTO Source_Addresses (Name, Address, GeoCoded) 
VALUES ('My Office', '1 Market St San Francisco CA 94105', 'No');

-- Add multiple addresses
INSERT INTO Source_Addresses (Name, Address, GeoCoded) VALUES
    ('Location 1', '123 Main St Springfield MA 01103', 'No'),
    ('Location 2', '456 Oak Ave Portland OR 97201', 'No'),
    ('Location 3', '789 Elm Blvd Austin TX 78701', 'No');

-- Process them
CALL Process_Ungeocoded_Addresses();
```

### Viewing Processing Status

```sql
-- Check overall status
SELECT 
    GeoCoded,
    COUNT(*) as count
FROM Source_Addresses
GROUP BY GeoCoded;

-- See unprocessed addresses
SELECT 
    Address_ID,
    Name,
    Address
FROM Source_Addresses
WHERE GeoCoded = 'No'
ORDER BY Address_ID;
```

### Viewing Results

```sql
-- Combined view (source + geocoded)
SELECT 
    s.Address_ID,
    s.Name,
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
```

### Error Tracking

```sql
-- Find addresses that failed to geocode
SELECT 
    s.Address_ID,
    s.Name,
    s.Address
FROM Source_Addresses s
LEFT JOIN Geocoded_Addresses g ON s.Address_ID = g.Address_ID
WHERE g.Address_ID IS NULL 
  AND s.GeoCoded = 'No';
```

## Scheduling Automated Processing

You can schedule the geocoding process to run automatically using Snowflake TASKS:

```sql
-- Create a task to run every hour
CREATE OR REPLACE TASK geocode_addresses_task
  WAREHOUSE = YOUR_WAREHOUSE
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
```

## Performance Considerations

### Batch Size

The stored procedure processes ALL ungeocoded addresses in one call. For very large batches:

```sql
-- Process only 100 at a time
-- Modify the stored procedure or create a new one:
CREATE OR REPLACE PROCEDURE Process_Ungeocoded_Addresses_Batch(batch_size INTEGER)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    processed_count INTEGER DEFAULT 0;
BEGIN
    -- Insert with LIMIT
    INSERT INTO Geocoded_Addresses (Name, Address_ID, Address, Street, City, State, Zip, Lat, Long)
    WITH addresses_to_process AS (
        SELECT 
            Name,
            Address_ID,
            Address
        FROM Source_Addresses
        WHERE GeoCoded = 'No'
        LIMIT :batch_size
    ),
    geocoded_data AS (
        SELECT
            a.Name,
            a.Address_ID,
            a.Address,
            PARSE_JSON(geocode_address(a.Address))::VARIANT AS api_response
        FROM addresses_to_process a
    ),
    parsed_results AS (
        SELECT
            g.Name,
            g.Address_ID,
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
        Address_ID,
        Address,
        street,
        city,
        state,
        zip,
        lat,
        long
    FROM parsed_results
    WHERE lat IS NOT NULL;
    
    processed_count := SQLROWCOUNT;
    
    -- Update flags
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
    
    RETURN 'Processed ' || processed_count || ' addresses';
END;
$$;

-- Use it
CALL Process_Ungeocoded_Addresses_Batch(100);
```

### Warehouse Sizing

For geocoding workloads:
- **Small**: < 1,000 addresses
- **Medium**: 1,000 - 10,000 addresses
- **Large**: > 10,000 addresses

## Monitoring & Analytics

### Create a monitoring view

```sql
CREATE OR REPLACE VIEW Geocoding_Status_View AS
SELECT 
    COUNT(*) as total_addresses,
    SUM(CASE WHEN GeoCoded = 'Yes' THEN 1 ELSE 0 END) as geocoded_count,
    SUM(CASE WHEN GeoCoded = 'No' THEN 1 ELSE 0 END) as pending_count,
    ROUND(100.0 * SUM(CASE WHEN GeoCoded = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) as success_rate_pct
FROM Source_Addresses;

-- View status
SELECT * FROM Geocoding_Status_View;
```

### Track geocoding over time

```sql
SELECT 
    DATE_TRUNC('day', Geocoded_Timestamp) as geocoded_date,
    COUNT(*) as addresses_geocoded,
    COUNT(DISTINCT State) as states_covered
FROM Geocoded_Addresses
GROUP BY DATE_TRUNC('day', Geocoded_Timestamp)
ORDER BY geocoded_date DESC;
```

## Troubleshooting

### Issue: "Invalid API key" error

**Solution:** 
- Verify you updated the SECRET with your actual HERE API key
- Test your key directly at https://geocode.search.hereapi.com/

### Issue: External Access Integration not working

**Solution:**
- Ensure you have ACCOUNTADMIN role: `USE ROLE ACCOUNTADMIN;`
- Verify network rule allows the correct host
- Check integration is enabled: `SHOW INTEGRATIONS;`

### Issue: No results returned

**Solution:**
- Test the UDF directly with a known good address
- Check the JSON response for errors
- Verify the address format is reasonable

### Issue: Slow performance

**Solution:**
- Use a larger warehouse
- Process in batches using the batch procedure
- Consider parallel processing (requires task orchestration)

## Security Best Practices

✅ **API Key Storage:** Stored in Snowflake Secret (encrypted)  
✅ **Network Restrictions:** Only HERE API domain allowed  
✅ **Role-Based Access:** Use ACCOUNTADMIN for setup, grant specific permissions for operations  
✅ **Audit Trail:** Snowflake tracks all access and changes  

### Grant permissions to other roles

```sql
-- Allow a specific role to use the geocoding functionality
GRANT USAGE ON DATABASE DEMO_GEOCODE TO ROLE YOUR_ROLE;
GRANT USAGE ON SCHEMA DEMO_GEOCODE.ADDRESS_PROCESSING TO ROLE YOUR_ROLE;
GRANT SELECT, INSERT, UPDATE ON TABLE Source_Addresses TO ROLE YOUR_ROLE;
GRANT SELECT ON TABLE Geocoded_Addresses TO ROLE YOUR_ROLE;
GRANT USAGE ON FUNCTION geocode_address(STRING) TO ROLE YOUR_ROLE;
GRANT USAGE ON PROCEDURE Process_Ungeocoded_Addresses() TO ROLE YOUR_ROLE;
```

## Cleanup

To remove everything:

```sql
-- Drop all objects (in order)
DROP PROCEDURE IF EXISTS Process_Ungeocoded_Addresses;
DROP TABLE IF EXISTS Geocoded_Addresses;
DROP TABLE IF EXISTS Source_Addresses;
DROP FUNCTION IF EXISTS geocode_address(STRING);
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS here_geocode_integration;
DROP SECRET IF EXISTS here_api_key_secret;
DROP NETWORK RULE IF EXISTS here_geocode_network_rule;
DROP SCHEMA IF EXISTS DEMO_GEOCODE.ADDRESS_PROCESSING;
DROP DATABASE IF EXISTS DEMO_GEOCODE;
```

## Summary

This solution provides:

✅ **100% Snowflake-based** - No external applications needed  
✅ **Secure** - API key stored in Snowflake Secret  
✅ **Automated** - Stored procedure handles entire workflow  
✅ **Scalable** - Can process millions of addresses  
✅ **Trackable** - GeoCoded flag prevents reprocessing  
✅ **Free** - Uses HERE API free tier (250k requests/month)  

**You're now geocoding addresses entirely within Snowflake!** 🎉

