# Snowflake Geocoding - Quick Reference

## 🚀 Quick Setup (3 Steps)

```sql
-- 1. Update API key in geocode_demo_complete.sql (line 44)
SECRET_STRING = 'YOUR_ACTUAL_HERE_API_KEY';

-- 2. Run entire SQL script

-- 3. Process addresses
CALL Process_Ungeocoded_Addresses();
```

## 📋 Essential Commands

### Add Addresses

```sql
-- Add single address
INSERT INTO Source_Addresses (Name, Department, Address) 
VALUES ('My Location', 'Sales', '123 Main St Springfield MA 01103');

-- Add multiple addresses
INSERT INTO Source_Addresses (Name, Department, Address) VALUES
    ('Office', 'Sales', '1 Market St San Francisco CA 94105'),
    ('Warehouse', 'Operations', '456 Industrial Blvd Portland OR 97201'),
    ('Event Venue', 'Marketing', '789 Convention Way Austin TX 78701');
```

### Process Addresses

```sql
-- Process all ungeocoded addresses
CALL Process_Ungeocoded_Addresses();

-- Process in batches of 100
CALL Process_Ungeocoded_Addresses_Batch(100);
```

### View Results

```sql
-- Check status overview
SELECT * FROM Geocoding_Status_View;

-- View all geocoded results
SELECT * FROM Geocoded_Addresses ORDER BY Address_ID;

-- View combined (source + geocoded)
SELECT 
    s.Name,
    s.Address AS Original,
    g.City,
    g.State,
    g.Lat,
    g.Long
FROM Source_Addresses s
LEFT JOIN Geocoded_Addresses g ON s.Address_ID = g.Address_ID
ORDER BY s.Address_ID;

-- View unprocessed addresses only
SELECT * FROM Unprocessed_Addresses_View;

-- View geocoding analytics
SELECT * FROM Geocoding_Analytics_View;
```

## 🏢 Department-Specific Queries

```sql
-- View summary by department
SELECT * FROM Department_Summary_View;

-- View addresses by department
SELECT 
    Department,
    COUNT(*) as total_addresses,
    SUM(CASE WHEN GeoCoded = 'Yes' THEN 1 ELSE 0 END) as geocoded,
    SUM(CASE WHEN GeoCoded = 'No' THEN 1 ELSE 0 END) as pending
FROM Source_Addresses
GROUP BY Department
ORDER BY Department;

-- Get results for specific department
SELECT * FROM Geocoded_Addresses 
WHERE Department = 'Sales' 
ORDER BY Geocoded_Timestamp DESC;

-- Find pending addresses for specific department
SELECT Name, Address 
FROM Source_Addresses 
WHERE Department = 'Marketing' AND GeoCoded = 'No';
```

## 🔍 Monitoring Queries

```sql
-- How many addresses are geocoded vs pending?
SELECT GeoCoded, COUNT(*) 
FROM Source_Addresses 
GROUP BY GeoCoded;

-- What's the success rate?
SELECT * FROM Geocoding_Status_View;

-- Which addresses failed to geocode?
SELECT s.Address_ID, s.Address
FROM Source_Addresses s
LEFT JOIN Geocoded_Addresses g ON s.Address_ID = g.Address_ID
WHERE s.GeoCoded = 'No' AND g.Address_ID IS NULL;

-- How many addresses geocoded today?
SELECT COUNT(*) 
FROM Geocoded_Addresses 
WHERE DATE(Geocoded_Timestamp) = CURRENT_DATE();
```

## 🧪 Testing

```sql
-- Test single address
SELECT geocode_address('4601 Collins Ave Miami Beach FL 33140');

-- Test with parsed result
WITH test AS (
    SELECT PARSE_JSON(geocode_address('4601 Collins Ave Miami Beach FL 33140'))::VARIANT AS data
)
SELECT
    f.value:address.city::STRING AS city,
    f.value:address.state::STRING AS state,
    f.value:position.lat::FLOAT AS lat,
    f.value:position.lng::FLOAT AS long
FROM test, LATERAL FLATTEN(input => test.data:items) f;
```

## 🔄 Maintenance

```sql
-- Reset for testing (clears geocoded data)
DELETE FROM Geocoded_Addresses;
UPDATE Source_Addresses SET GeoCoded = 'No';

-- Delete specific address
DELETE FROM Source_Addresses WHERE Address_ID = 123;
DELETE FROM Geocoded_Addresses WHERE Address_ID = 123;

-- Reprocess failed addresses (mark them as 'No' again)
UPDATE Source_Addresses 
SET GeoCoded = 'No' 
WHERE Address_ID NOT IN (SELECT Address_ID FROM Geocoded_Addresses);
```

## ⏰ Scheduled Processing

```sql
-- Create hourly task
CREATE TASK geocode_addresses_task
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = 'USING CRON 0 * * * * America/New_York'
AS
  CALL Process_Ungeocoded_Addresses();

-- Enable task
ALTER TASK geocode_addresses_task RESUME;

-- Check task status
SHOW TASKS;

-- View task history
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME = 'GEOCODE_ADDRESSES_TASK'
ORDER BY SCHEDULED_TIME DESC LIMIT 10;

-- Suspend task
ALTER TASK geocode_addresses_task SUSPEND;
```

## 🔐 Security Objects

```sql
-- View network rules
SHOW NETWORK RULES;

-- View secrets (won't show the actual secret value)
SHOW SECRETS;

-- View external access integrations
SHOW INTEGRATIONS;

-- View functions
SHOW FUNCTIONS LIKE 'geocode%';

-- View procedures
SHOW PROCEDURES LIKE 'Process%';
```

## 📊 Key Tables & Views

| Object | Purpose |
|--------|---------|
| `Source_Addresses` | Input addresses (GeoCoded flag) |
| `Geocoded_Addresses` | Geocoded results with lat/long |
| `Geocoding_Status_View` | Overall status dashboard |
| `Unprocessed_Addresses_View` | Addresses that failed or pending |
| `Geocoding_Analytics_View` | History and analytics |

## 🎯 Key Components

| Object | Purpose |
|--------|---------|
| `here_geocode_network_rule` | Allows access to HERE API |
| `here_api_key_secret` | Stores API key securely |
| `here_geocode_integration` | External access integration |
| `geocode_address()` | UDF that calls HERE API |
| `Process_Ungeocoded_Addresses()` | Main processing procedure |
| `Process_Ungeocoded_Addresses_Batch()` | Batch processing procedure |

## 💡 Tips

- **Start small:** Test with a few addresses before bulk processing
- **Use batches:** For large volumes, use batch processing (100-1000 at a time)
- **Monitor:** Check `Geocoding_Status_View` regularly
- **Schedule:** Use TASKS for automated processing
- **Free tier:** HERE provides 250k requests/month free

## 🔧 Troubleshooting

```sql
-- Check if integration is enabled
SHOW INTEGRATIONS LIKE 'here_geocode_integration';

-- Verify secret exists
SHOW SECRETS LIKE 'here_api_key_secret';

-- Check network rule
SHOW NETWORK RULES LIKE 'here_geocode_network_rule';

-- Test UDF directly
SELECT geocode_address('1600 Pennsylvania Avenue NW Washington DC 20500');
```

## 📝 Common Workflows

### Daily Processing Workflow

```sql
-- 1. Check what needs processing
SELECT COUNT(*) FROM Source_Addresses WHERE GeoCoded = 'No';

-- 2. Process them
CALL Process_Ungeocoded_Addresses();

-- 3. Check results
SELECT * FROM Geocoding_Status_View;

-- 4. Review any failures
SELECT * FROM Unprocessed_Addresses_View;
```

### Bulk Import Workflow

```sql
-- 1. Load addresses into Source_Addresses
INSERT INTO Source_Addresses (Name, Address)
SELECT name_col, address_col FROM your_staging_table;

-- 2. Process in batches
CALL Process_Ungeocoded_Addresses_Batch(500);

-- 3. Monitor progress
SELECT * FROM Geocoding_Status_View;

-- 4. Repeat batch processing until done
-- (or use a TASK to automate)
```

## 🆘 Need More Help?

- **Full Documentation:** See `SNOWFLAKE_GUIDE.md`
- **Architecture Details:** See `WORKFLOW.md`
- **API Documentation:** https://developer.here.com/

---

**Quick Start:** Replace API key → Run SQL script → `CALL Process_Ungeocoded_Addresses();` → Done! 🎉

