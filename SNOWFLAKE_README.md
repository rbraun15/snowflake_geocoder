# Snowflake Geocoding Solution

**Complete address geocoding running entirely within Snowflake using External Access Integration**

## What This Solution Does

Takes addresses like this:
```
4601 Collins Ave Miami Beach FL 33140
```

And returns structured geocoded data like this:
```
Street: Collins Ave
City: Miami Beach
State: Florida
Zip: 33140
Latitude: 25.8201
Longitude: -80.12256
```

**All processing happens within Snowflake** - no external applications needed!

## Architecture Overview

```
┌────────────────────────────────────────────────────────┐
│                    SNOWFLAKE                           │
│                                                        │
│  Source_Addresses (GeoCoded = 'No')                   │
│         ↓                                              │
│  Process_Ungeocoded_Addresses() Procedure             │
│         ↓                                              │
│  geocode_address() Python UDF                         │
│         ↓                                              │
│  External Access Integration                           │
│    • Network Rule: HERE API endpoint                   │
│    • Secret: API Key                                   │
│         ↓                                              │
│  ═══════════════════════════════════                   │
└─────────┼──────────────────────────────────────────────┘
          │ HTTPS
          ▼
   ┌─────────────┐
   │  HERE API   │
   └─────────────┘
          │
          ▼
┌─────────┴──────────────────────────────────────────────┐
│                    SNOWFLAKE                           │
│                                                        │
│  Parse JSON Response                                   │
│         ↓                                              │
│  Insert into Geocoded_Addresses                        │
│         ↓                                              │
│  Update GeoCoded = 'Yes'                               │
└────────────────────────────────────────────────────────┘
```

## 📦 What's Included

### Core SQL File
- **`geocode_demo_complete.sql`** - Complete implementation with:
  - Network rule configuration
  - Secret for API key storage
  - External Access Integration setup
  - Python UDF for geocoding
  - Source_Addresses table
  - Geocoded_Addresses table
  - Main processing stored procedure
  - Batch processing stored procedure
  - Monitoring views
  - Task scheduling (optional)
  - Sample data (6 addresses)

### Documentation
- **`SNOWFLAKE_README.md`** - This file (overview)
- **`SNOWFLAKE_GUIDE.md`** - Detailed guide with examples
- **`SNOWFLAKE_CHEATSHEET.md`** - Quick reference commands
- **`WORKFLOW.md`** - Architecture diagrams
- **`PROJECT_SUMMARY.md`** - Complete project summary

## 🚀 Quick Start (5 Minutes)

### Step 1: Get HERE API Key (2 min)
1. Visit https://account.here.com/sign-up
2. Create free account
3. Go to Access Manager
4. Create new app & API key
5. Copy the key

### Step 2: Update SQL File (1 min)
Open `geocode_demo_complete.sql` and find line 44:
```sql
SECRET_STRING = 'YOUR_API_KEY_HERE';
```
Replace with your actual API key.

### Step 3: Run in Snowflake (1 min)
1. Open Snowflake worksheet
2. Paste entire SQL script
3. Execute all

### Step 4: Process Addresses (1 min)
```sql
CALL Process_Ungeocoded_Addresses();
```

### Step 5: View Results
```sql
SELECT * FROM Geocoded_Addresses;
```

**Done!** You're now geocoding addresses in Snowflake! 🎉

## 🎯 Key Features

✅ **100% Snowflake Native** - No external applications  
✅ **Secure** - API key stored in Snowflake Secret  
✅ **Automated** - Stored procedures handle everything  
✅ **Scalable** - Can process millions of addresses  
✅ **Trackable** - GeoCoded flag prevents reprocessing  
✅ **Monitored** - Built-in views for status tracking  
✅ **Scheduled** - Optional TASK for automation  
✅ **Batch Processing** - Handle large volumes efficiently  

## 📊 Database Objects Created

### Tables
- **Source_Addresses** - Input addresses with GeoCoded flag
- **Geocoded_Addresses** - Results with parsed components

### Functions & Procedures
- **geocode_address()** - Python UDF calling HERE API
- **Process_Ungeocoded_Addresses()** - Main processing
- **Process_Ungeocoded_Addresses_Batch()** - Batch processing

### Views
- **Geocoding_Status_View** - Overall status dashboard
- **Unprocessed_Addresses_View** - Failed/pending addresses
- **Geocoding_Analytics_View** - Historical analytics

### Security Objects
- **here_geocode_network_rule** - Network access control
- **here_api_key_secret** - Encrypted API key storage
- **here_geocode_integration** - External access integration

## 💻 Common Usage Patterns

### Add & Process New Addresses
```sql
-- Add addresses
INSERT INTO Source_Addresses (Name, Address) VALUES
    ('Office', '1 Market St San Francisco CA 94105'),
    ('Warehouse', '100 Main St Boston MA 02101');

-- Process them
CALL Process_Ungeocoded_Addresses();

-- View results
SELECT * FROM Geocoding_Status_View;
```

### Monitor Progress
```sql
-- Check overall status
SELECT * FROM Geocoding_Status_View;

-- See what's pending
SELECT * FROM Unprocessed_Addresses_View;

-- View analytics
SELECT * FROM Geocoding_Analytics_View;
```

### Batch Processing
```sql
-- Process 100 at a time
CALL Process_Ungeocoded_Addresses_Batch(100);
```

### Schedule Automated Processing
```sql
-- Create hourly task
CREATE TASK geocode_addresses_task
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = 'USING CRON 0 * * * * America/New_York'
AS
  CALL Process_Ungeocoded_Addresses();

-- Enable it
ALTER TASK geocode_addresses_task RESUME;
```

## 📋 Table Schemas

### Source_Addresses
```sql
Name        VARCHAR(255)        -- Descriptive name
Address_ID  INTEGER             -- Auto-increment PK
Address     VARCHAR(500)        -- Full address string
GeoCoded    VARCHAR(3)          -- 'No' or 'Yes'
```

### Geocoded_Addresses
```sql
Geocoded_ID         INTEGER         -- Auto-increment PK
Name                VARCHAR(255)    -- From source
Address_ID          INTEGER         -- Links to source
Address             VARCHAR(500)    -- Original address
Street              VARCHAR(255)    -- Parsed street
City                VARCHAR(100)    -- Parsed city
State               VARCHAR(100)    -- Parsed state
Zip                 VARCHAR(20)     -- Parsed ZIP
Lat                 FLOAT           -- Latitude
Long                FLOAT           -- Longitude
Geocoded_Timestamp  TIMESTAMP_NTZ   -- When geocoded
```

## 🔐 Security Features

### API Key Protection
- Stored in Snowflake Secret (encrypted)
- Never exposed in queries or logs
- Retrieved securely by UDF at runtime

### Network Security
- Network rule restricts to HERE API only
- External Access Integration required
- ACCOUNTADMIN role required for setup

### Access Control
```sql
-- Grant permissions to other roles
GRANT USAGE ON DATABASE DEMO_GEOCODE TO ROLE your_role;
GRANT USAGE ON SCHEMA ADDRESS_PROCESSING TO ROLE your_role;
GRANT SELECT, INSERT ON TABLE Source_Addresses TO ROLE your_role;
GRANT USAGE ON PROCEDURE Process_Ungeocoded_Addresses() TO ROLE your_role;
```

## 📈 Scalability

| Addresses | Warehouse | Estimated Time |
|-----------|-----------|----------------|
| < 100 | X-Small | < 1 minute |
| 100-1,000 | Small | 3-15 minutes |
| 1,000-10,000 | Medium | 30 min - 2 hours |
| 10,000+ | Large | Hours (use batches) |

**Tip:** Use batch processing for large volumes:
```sql
CALL Process_Ungeocoded_Addresses_Batch(500);
```

## 💰 Cost Considerations

### HERE API
- **Free Tier:** 250,000 requests/month
- **No Credit Card Required**
- Perfect for most use cases

### Snowflake
- Warehouse compute costs (seconds to minutes)
- Storage costs (minimal for this use case)
- **Tip:** Suspend warehouse when not in use

## 🎓 Sample Data Included

Six addresses ready to test:
1. Miami Beach Property - `4601 Collins Ave Miami Beach FL 33140`
2. Rochester Home - `114 Orland Rd Rochester NY 14622`
3. Greenville Residence - `103 Autumn Rd Greenville SC 29650`
4. Empire State Building - `350 5th Ave New York NY 10118`
5. Golden Gate Bridge - `1 Golden Gate Bridge San Francisco CA 94129`
6. White House - `1600 Pennsylvania Avenue NW Washington DC 20500`

## 🔧 Troubleshooting

### "Invalid API key" Error
✓ Verify you updated the SECRET with your actual key  
✓ Test key at https://geocode.search.hereapi.com/

### External Access Integration Error
✓ Ensure you're using ACCOUNTADMIN role  
✓ Check: `SHOW INTEGRATIONS;`

### No Results
✓ Test UDF directly: `SELECT geocode_address('test address');`  
✓ Check if addresses exist: `SELECT * FROM Unprocessed_Addresses_View;`

### Performance Issues
✓ Use batch processing for large volumes  
✓ Increase warehouse size  
✓ Schedule processing during off-peak hours

## 📚 Documentation

- **Quick Reference:** `SNOWFLAKE_CHEATSHEET.md`
- **Detailed Guide:** `SNOWFLAKE_GUIDE.md`
- **Architecture:** `WORKFLOW.md`
- **Complete Overview:** `PROJECT_SUMMARY.md`

## 🎯 Use Cases

✅ **Data Enrichment** - Add coordinates to customer addresses  
✅ **Sales Territory** - Map addresses to territories  
✅ **Logistics** - Calculate distances and routes  
✅ **Analytics** - Aggregate data by geography  
✅ **Visualization** - Plot addresses on maps  
✅ **Compliance** - Verify address accuracy  

## 🔄 Workflow Example

```sql
-- 1. Load your addresses
INSERT INTO Source_Addresses (Name, Address)
SELECT customer_name, customer_address 
FROM your_customer_table
WHERE geocoded_flag IS NULL;

-- 2. Process them
CALL Process_Ungeocoded_Addresses();

-- 3. Check status
SELECT * FROM Geocoding_Status_View;

-- 4. Use the results
SELECT 
    c.customer_id,
    c.customer_name,
    g.City,
    g.State,
    g.Lat,
    g.Long
FROM your_customer_table c
JOIN Source_Addresses s ON c.customer_address = s.Address
JOIN Geocoded_Addresses g ON s.Address_ID = g.Address_ID;
```

## 🧹 Cleanup

To remove everything:
```sql
DROP PROCEDURE IF EXISTS Process_Ungeocoded_Addresses_Batch;
DROP PROCEDURE IF EXISTS Process_Ungeocoded_Addresses;
DROP VIEW IF EXISTS Geocoding_Analytics_View;
DROP VIEW IF EXISTS Unprocessed_Addresses_View;
DROP VIEW IF EXISTS Geocoding_Status_View;
DROP TABLE IF EXISTS Geocoded_Addresses;
DROP TABLE IF EXISTS Source_Addresses;
DROP FUNCTION IF EXISTS geocode_address(STRING);
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS here_geocode_integration;
DROP SECRET IF EXISTS here_api_key_secret;
DROP NETWORK RULE IF EXISTS here_geocode_network_rule;
DROP SCHEMA IF EXISTS DEMO_GEOCODE.ADDRESS_PROCESSING;
DROP DATABASE IF EXISTS DEMO_GEOCODE;
```

## ✅ Next Steps

1. ✓ Get HERE API key
2. ✓ Update SQL file with your key
3. ✓ Run the script in Snowflake
4. ✓ Test with sample addresses
5. ✓ Load your own addresses
6. ✓ Schedule automated processing (optional)
7. ✓ Integrate with your workflows

## 🙋 Support

- **HERE API Docs:** https://developer.here.com/
- **Snowflake Docs:** https://docs.snowflake.com/
- **External Access:** https://docs.snowflake.com/en/developer-guide/external-network-access/

---

**You're now ready to geocode addresses entirely within Snowflake!** 🌍📍

For quick commands, see: **`SNOWFLAKE_CHEATSHEET.md`**

