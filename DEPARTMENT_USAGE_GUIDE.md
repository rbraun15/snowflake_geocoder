# Department-Based Geocoding Guide

## Overview

This geocoding solution is designed as a **centralized service** that multiple departments can use simultaneously. The `Department` field allows you to track which department submitted each address and enables department-specific reporting and analytics.

## Why Department Tracking?

In a centralized geocoding service:
- ✅ **Accountability** - Know which department submitted which addresses
- ✅ **Usage Tracking** - Monitor which departments use the service most
- ✅ **Cost Allocation** - Track API usage by department
- ✅ **Access Control** - Filter results by department
- ✅ **Analytics** - Department-specific reporting and insights
- ✅ **Compliance** - Audit trail for data submissions

## Table Schema with Department

### Source_Addresses
```sql
Name        VARCHAR(255)    -- Descriptive name
Department  VARCHAR(100)    -- Department name (NEW!)
Address_ID  INTEGER         -- Auto-increment PK
Address     VARCHAR(500)    -- Full address string
GeoCoded    VARCHAR(3)      -- 'No' or 'Yes'
```

### Geocoded_Addresses
```sql
Geocoded_ID         INTEGER         -- Auto-increment PK
Name                VARCHAR(255)    -- From source
Department          VARCHAR(100)    -- From source (NEW!)
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

## Sample Data by Department

The solution includes sample addresses from different departments:

| Department | Count | Addresses |
|------------|-------|-----------|
| Sales | 2 | Miami Beach Property, Greenville Residence |
| Marketing | 2 | Rochester Home, Golden Gate Bridge |
| Operations | 1 | Empire State Building |
| Executive | 1 | White House |

## Adding Addresses by Department

### Single Address
```sql
INSERT INTO Source_Addresses (Name, Department, Address) 
VALUES ('Customer Site A', 'Sales', '123 Main St Boston MA 02101');
```

### Multiple Addresses (Same Department)
```sql
INSERT INTO Source_Addresses (Name, Department, Address) VALUES
    ('Marketing Event Location', 'Marketing', '1 Market St San Francisco CA 94105'),
    ('Trade Show Venue', 'Marketing', '100 Convention Center Dr Las Vegas NV 89109'),
    ('Promotional Popup Store', 'Marketing', '200 5th Ave New York NY 10010');
```

### Multiple Addresses (Different Departments)
```sql
INSERT INTO Source_Addresses (Name, Department, Address) VALUES
    ('Sales Office East', 'Sales', '50 State St Boston MA 02109'),
    ('Distribution Center', 'Operations', '1000 Warehouse Way Memphis TN 38118'),
    ('R&D Lab', 'Engineering', '1 Innovation Dr Palo Alto CA 94304'),
    ('Training Center', 'HR', '500 Learning Lane Austin TX 78701');
```

## Department-Specific Queries

### View All Addresses by Department
```sql
SELECT 
    Department,
    COUNT(*) as total_addresses,
    SUM(CASE WHEN GeoCoded = 'Yes' THEN 1 ELSE 0 END) as geocoded,
    SUM(CASE WHEN GeoCoded = 'No' THEN 1 ELSE 0 END) as pending
FROM Source_Addresses
GROUP BY Department
ORDER BY Department;
```

**Example Output:**
```
Department    | total_addresses | geocoded | pending
--------------|----------------|----------|--------
Executive     | 1              | 1        | 0
Marketing     | 2              | 2        | 0
Operations    | 1              | 1        | 0
Sales         | 2              | 2        | 0
```

### Get Geocoded Results for Specific Department
```sql
-- Sales department results
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
```

### Find Pending Addresses for Specific Department
```sql
SELECT 
    Address_ID,
    Name,
    Address
FROM Source_Addresses
WHERE Department = 'Marketing'
  AND GeoCoded = 'No'
ORDER BY Address_ID;
```

### Department Usage Statistics
```sql
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
```

### Department Activity Over Time
```sql
-- Last 30 days of activity
SELECT 
    DATE(Geocoded_Timestamp) as geocoded_date,
    Department,
    COUNT(*) as addresses_geocoded
FROM Geocoded_Addresses
WHERE Geocoded_Timestamp >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY DATE(Geocoded_Timestamp), Department
ORDER BY geocoded_date DESC, Department;
```

## Built-in Department Views

### Department Summary View
Shows overall statistics for each department:

```sql
SELECT * FROM Department_Summary_View;
```

**Columns:**
- `Department` - Department name
- `total_addresses` - Total addresses submitted
- `geocoded_count` - Successfully geocoded
- `pending_count` - Not yet geocoded
- `states_covered` - Number of unique states
- `cities_covered` - Number of unique cities
- `first_address_geocoded` - When first address was geocoded
- `most_recent_geocoded` - Most recent geocoding

## Common Use Cases

### 1. Sales Team Geocoding Customer Addresses

```sql
-- Sales adds customer addresses
INSERT INTO Source_Addresses (Name, Department, Address) VALUES
    ('Customer A Headquarters', 'Sales', '100 Business Pkwy Dallas TX 75201'),
    ('Customer B Branch Office', 'Sales', '200 Commerce St Denver CO 80202'),
    ('Customer C Main Site', 'Sales', '300 Industrial Dr Phoenix AZ 85001');

-- Process all addresses (including Sales')
CALL Process_Ungeocoded_Addresses();

-- Sales views their geocoded addresses
SELECT 
    Name,
    City,
    State,
    Lat,
    Long
FROM Geocoded_Addresses
WHERE Department = 'Sales'
ORDER BY Name;
```

### 2. Marketing Team Planning Event Locations

```sql
-- Marketing adds potential event venues
INSERT INTO Source_Addresses (Name, Department, Address) VALUES
    ('Convention Center Option A', 'Marketing', '400 Convention Way Orlando FL 32801'),
    ('Hotel Venue Option B', 'Marketing', '500 Hotel Plaza Miami FL 33131'),
    ('Stadium Option C', 'Marketing', '600 Stadium Rd Atlanta GA 30303');

-- Geocode them
CALL Process_Ungeocoded_Addresses();

-- Marketing analyzes locations
SELECT 
    Name,
    City,
    State,
    Lat,
    Long,
    -- Calculate distance from company HQ (example coordinates)
    ST_DISTANCE(
        ST_POINT(Long, Lat),
        ST_POINT(-80.1918, 25.7617)  -- Miami HQ example
    ) as distance_from_hq_meters
FROM Geocoded_Addresses
WHERE Department = 'Marketing'
ORDER BY distance_from_hq_meters;
```

### 3. Operations Team Managing Facilities

```sql
-- Operations tracks facility locations
INSERT INTO Source_Addresses (Name, Department, Address) VALUES
    ('Warehouse North', 'Operations', '1000 Logistics Blvd Chicago IL 60601'),
    ('Warehouse South', 'Operations', '2000 Distribution Way Houston TX 77001'),
    ('Warehouse West', 'Operations', '3000 Freight Ave Los Angeles CA 90001');

-- Geocode and analyze
CALL Process_Ungeocoded_Addresses();

-- Operations views their facilities
SELECT 
    Name,
    Address,
    City,
    State,
    Lat,
    Long
FROM Geocoded_Addresses
WHERE Department = 'Operations'
ORDER BY State, City;
```

### 4. Cross-Department Reporting

```sql
-- Executive dashboard: all departments
SELECT 
    Department,
    total_addresses,
    geocoded_count,
    pending_count,
    ROUND(100.0 * geocoded_count / NULLIF(total_addresses, 0), 2) as success_rate_pct
FROM Department_Summary_View
ORDER BY total_addresses DESC;
```

## Access Control Patterns

### Row-Level Security by Department

You can implement row-level security in Snowflake to ensure departments only see their own data:

```sql
-- Create secure view for Sales
CREATE OR REPLACE SECURE VIEW Sales_Geocoded_Addresses AS
SELECT 
    Geocoded_ID,
    Name,
    Address,
    Street,
    City,
    State,
    Zip,
    Lat,
    Long,
    Geocoded_Timestamp
FROM Geocoded_Addresses
WHERE Department = 'Sales';

-- Grant access to Sales role
GRANT SELECT ON VIEW Sales_Geocoded_Addresses TO ROLE SALES_ROLE;
```

### Dynamic Row-Level Security

```sql
-- Create a secure view that filters by user's department
CREATE OR REPLACE SECURE VIEW My_Department_Addresses AS
SELECT 
    s.Name,
    s.Address,
    s.GeoCoded,
    g.City,
    g.State,
    g.Lat,
    g.Long
FROM Source_Addresses s
LEFT JOIN Geocoded_Addresses g ON s.Address_ID = g.Address_ID
WHERE s.Department = CURRENT_USER_DEPARTMENT();  -- Assumes you have a function/mapping
```

## Department Analytics Examples

### Most Active Departments
```sql
SELECT 
    Department,
    COUNT(*) as addresses_submitted,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as pct_of_total
FROM Source_Addresses
GROUP BY Department
ORDER BY addresses_submitted DESC;
```

### Department Geocoding Success Rates
```sql
SELECT 
    Department,
    COUNT(*) as total_submitted,
    SUM(CASE WHEN GeoCoded = 'Yes' THEN 1 ELSE 0 END) as successful,
    ROUND(100.0 * SUM(CASE WHEN GeoCoded = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) as success_rate
FROM Source_Addresses
GROUP BY Department
ORDER BY success_rate DESC;
```

### Geographic Distribution by Department
```sql
SELECT 
    Department,
    State,
    COUNT(*) as address_count
FROM Geocoded_Addresses
GROUP BY Department, State
ORDER BY Department, address_count DESC;
```

### Monthly Usage by Department
```sql
SELECT 
    TO_CHAR(Geocoded_Timestamp, 'YYYY-MM') as month,
    Department,
    COUNT(*) as addresses_geocoded
FROM Geocoded_Addresses
GROUP BY TO_CHAR(Geocoded_Timestamp, 'YYYY-MM'), Department
ORDER BY month DESC, Department;
```

## Best Practices

### 1. **Standardize Department Names**
Use consistent department names across your organization:
```sql
-- Good
'Sales', 'Marketing', 'Operations', 'Engineering', 'HR'

-- Avoid
'sales', 'SALES', 'Sales Dept', 'Sales Department'
```

### 2. **Create a Department Reference Table**
```sql
CREATE TABLE Department_Reference (
    Department_ID INTEGER PRIMARY KEY,
    Department_Name VARCHAR(100) UNIQUE,
    Department_Code VARCHAR(10),
    Cost_Center VARCHAR(20),
    Manager_Email VARCHAR(255)
);

-- Insert valid departments
INSERT INTO Department_Reference VALUES
    (1, 'Sales', 'SLS', 'CC-1000', 'sales.manager@company.com'),
    (2, 'Marketing', 'MKT', 'CC-2000', 'marketing.manager@company.com'),
    (3, 'Operations', 'OPS', 'CC-3000', 'ops.manager@company.com');
```

### 3. **Add Foreign Key Constraint** (Optional)
```sql
ALTER TABLE Source_Addresses 
ADD CONSTRAINT fk_department 
FOREIGN KEY (Department) 
REFERENCES Department_Reference(Department_Name);
```

### 4. **Create Department-Specific Procedures**

For department-specific batch processing:
```sql
CREATE OR REPLACE PROCEDURE Process_Department_Addresses(dept_name VARCHAR)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO Geocoded_Addresses (Name, Department, Address_ID, Address, Street, City, State, Zip, Lat, Long)
    WITH addresses_to_process AS (
        SELECT 
            Name,
            Department,
            Address_ID,
            Address
        FROM Source_Addresses
        WHERE GeoCoded = 'No'
          AND Department = :dept_name
    ),
    -- ... rest of geocoding logic
    
    RETURN 'Processed addresses for department: ' || dept_name;
END;
$$;

-- Usage
CALL Process_Department_Addresses('Sales');
```

## Reporting Templates

### Executive Summary Report
```sql
SELECT 
    'Total Departments' as metric,
    COUNT(DISTINCT Department) as value
FROM Source_Addresses
UNION ALL
SELECT 
    'Total Addresses',
    COUNT(*)
FROM Source_Addresses
UNION ALL
SELECT 
    'Total Geocoded',
    COUNT(*)
FROM Geocoded_Addresses
UNION ALL
SELECT 
    'Success Rate %',
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Source_Addresses WHERE GeoCoded = 'Yes'), 2)
FROM Geocoded_Addresses;
```

### Department Activity Report
```sql
SELECT 
    Department,
    COUNT(*) as addresses_submitted,
    SUM(CASE WHEN GeoCoded = 'Yes' THEN 1 ELSE 0 END) as geocoded,
    SUM(CASE WHEN GeoCoded = 'No' THEN 1 ELSE 0 END) as pending,
    MAX(CASE WHEN GeoCoded = 'Yes' 
        THEN (SELECT Geocoded_Timestamp FROM Geocoded_Addresses g 
              WHERE g.Address_ID = s.Address_ID) 
        END) as last_activity
FROM Source_Addresses s
GROUP BY Department
ORDER BY addresses_submitted DESC;
```

## Summary

The Department field transforms this into a **true centralized service** where:

✅ Multiple departments can submit addresses independently  
✅ Each department can track their own submissions  
✅ Central IT can monitor usage across departments  
✅ Reporting shows department-level analytics  
✅ Access control can be department-based  
✅ Costs can be allocated by department  

This makes the geocoding solution **enterprise-ready for multi-team environments**!

