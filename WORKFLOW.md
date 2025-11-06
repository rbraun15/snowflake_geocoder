# Geocoding Workflow Documentation

## High-Level Process Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    GEOCODING WORKFLOW                            │
└─────────────────────────────────────────────────────────────────┘

  Step 1: Load Addresses
  ┌──────────────────────┐
  │  Source_Addresses    │
  │  ┌────────────────┐  │
  │  │ Name           │  │
  │  │ Address_ID     │  │
  │  │ Address        │  │
  │  │ GeoCoded: No   │  │
  │  └────────────────┘  │
  └──────────┬───────────┘
             │
             ▼
  Step 2: Filter Unprocessed
  ┌─────────────────────────┐
  │  WHERE GeoCoded = 'No'  │
  └──────────┬──────────────┘
             │
             ▼
  Step 3: Geocode via HERE API
  ┌──────────────────────────────────────┐
  │  For each address:                   │
  │  1. Format address                   │
  │  2. Call HERE API                    │
  │  3. Parse JSON response              │
  │     ┌─────────────────────────┐     │
  │     │ HERE Geocoding API      │     │
  │     │ ┌─────────────────────┐ │     │
  │     │ │ Input: Address      │ │     │
  │     │ │ Output: Lat/Long    │ │     │
  │     │ │         Components  │ │     │
  │     │ └─────────────────────┘ │     │
  │     └─────────────────────────┘     │
  └──────────┬───────────────────────────┘
             │
             ▼
  Step 4: Store Results
  ┌──────────────────────────┐
  │  Geocoded_Addresses      │
  │  ┌────────────────────┐  │
  │  │ Name               │  │
  │  │ Address_ID         │  │
  │  │ Address (original) │  │
  │  │ Street             │  │
  │  │ City               │  │
  │  │ State              │  │
  │  │ Zip                │  │
  │  │ Lat                │  │
  │  │ Long               │  │
  │  │ Timestamp          │  │
  │  └────────────────────┘  │
  └──────────┬───────────────┘
             │
             ▼
  Step 5: Update Flag
  ┌──────────────────────────┐
  │  UPDATE Source_Addresses │
  │  SET GeoCoded = 'Yes'    │
  │  WHERE Address_ID = ?    │
  └──────────────────────────┘
```

## Data Transformation Example

### Input (Source_Addresses)
```
┌────────────┬──────────────────────┬───────────────────────────────────────────────┬───────────┐
│ Address_ID │ Name                 │ Address                                       │ GeoCoded  │
├────────────┼──────────────────────┼───────────────────────────────────────────────┼───────────┤
│ 1          │ Miami Beach Property │ 4601 Collins Ave Miami Beach FL 33140         │ No        │
└────────────┴──────────────────────┴───────────────────────────────────────────────┴───────────┘
```

### HERE API Request
```http
GET https://geocode.search.hereapi.com/v1/geocode?q=4601+Collins+Ave+Miami+Beach+FL+33140&apiKey=YOUR_KEY
```

### HERE API Response (Simplified)
```json
{
  "items": [
    {
      "address": {
        "street": "Collins Ave",
        "houseNumber": "4601",
        "city": "Miami Beach",
        "state": "Florida",
        "postalCode": "33140"
      },
      "position": {
        "lat": 25.8201,
        "lng": -80.12256
      }
    }
  ]
}
```

### Output (Geocoded_Addresses)
```
┌────────────┬──────────────────────┬────────────┬─────────┬────────────┬─────────┬───────┬──────────┬────────────┐
│ Address_ID │ Name                 │ Street     │ City    │ State      │ Zip     │ Lat   │ Long     │ GeoCoded   │
├────────────┼──────────────────────┼────────────┼─────────┼────────────┼─────────┼───────┼──────────┼────────────┤
│ 1          │ Miami Beach Property │ Collins Ave│ Miami   │ Florida    │ 33140   │ 25.82 │ -80.123  │ Yes        │
│            │                      │            │ Beach   │            │         │       │          │            │
└────────────┴──────────────────────┴────────────┴─────────┴────────────┴─────────┴───────┴──────────┴────────────┘
```

## Error Handling Flow

```
┌─────────────────────────┐
│  Process Address        │
└──────────┬──────────────┘
           │
           ▼
    ┌──────────────┐
    │ Call API     │
    └──────┬───────┘
           │
           ├─────────────────────┐
           │                     │
           ▼                     ▼
    ┌─────────────┐      ┌─────────────────┐
    │  Success    │      │  Failure        │
    │  (HTTP 200) │      │  (API Error)    │
    └──────┬──────┘      └──────┬──────────┘
           │                     │
           ▼                     ▼
    ┌──────────────┐      ┌─────────────────┐
    │ Parse JSON   │      │ Log Error       │
    └──────┬───────┘      │ Skip Address    │
           │              │ GeoCoded = 'No' │
           ▼              └─────────────────┘
    ┌──────────────┐
    │ Valid Data?  │
    └──────┬───────┘
           │
           ├─────────────────────┐
           │                     │
           ▼                     ▼
    ┌─────────────┐      ┌─────────────────┐
    │  Yes        │      │  No             │
    │  Insert     │      │  Skip           │
    │  Set Yes    │      │  Keep No        │
    └─────────────┘      └─────────────────┘
```

## Rate Limiting Strategy

The HERE API free tier allows:
- **250,000 requests per month**
- No explicit per-second limit, but best practice: ~5 requests/second max

### Implementation

**Python Version:**
```python
# Delay between requests
time.sleep(0.2)  # 200ms = 5 requests/second
```

**Snowflake Version:**
```sql
-- Snowflake can parallelize but respect rate limits
-- Consider using TASK scheduling for large batches
-- with appropriate delays between batches
```

## Batch Processing Recommendations

| Batch Size | Method | Estimated Time |
|------------|--------|----------------|
| < 100 addresses | Interactive processing | < 1 minute |
| 100-1,000 | Batch script with delays | 3-15 minutes |
| 1,000-10,000 | Scheduled tasks | 30 min - 2 hours |
| > 10,000 | Chunked processing over time | Hours/days |

## Database State Transitions

```
Initial State:
┌──────────────────────────┐
│ Source_Addresses         │
│ GeoCoded = 'No'          │
└────────────┬─────────────┘
             │
             │ Process_Ungeocoded_Addresses()
             ▼
┌──────────────────────────┐
│ API Call & Parse         │
└────────────┬─────────────┘
             │
             ├──────────────────────┐
             │                      │
     Success │                      │ Failure
             ▼                      ▼
┌──────────────────────────┐  ┌────────────────────┐
│ Insert into              │  │ No insert          │
│ Geocoded_Addresses       │  │ GeoCoded stays No  │
└────────────┬─────────────┘  └────────────────────┘
             │
             ▼
┌──────────────────────────┐
│ UPDATE Source_Addresses  │
│ SET GeoCoded = 'Yes'     │
└──────────────────────────┘

Final State:
┌──────────────────────────┐     ┌──────────────────────┐
│ Source_Addresses         │     │ Geocoded_Addresses   │
│ GeoCoded = 'Yes'         │────→│ (Full details)       │
└──────────────────────────┘     └──────────────────────┘
```

## Architecture Comparison

### Python/SQLite Architecture
```
┌──────────────────────────────────────────────────────┐
│                  Python Application                   │
│                                                       │
│  ┌──────────────┐    ┌──────────────┐               │
│  │  Menu/CLI    │    │  Business    │               │
│  │  Interface   │───→│  Logic       │               │
│  └──────────────┘    └──────┬───────┘               │
│                              │                        │
│                              ▼                        │
│                     ┌────────────────┐               │
│                     │  Requests Lib  │               │
│                     └────────┬───────┘               │
└──────────────────────────────┼────────────────────────┘
                               │
                               ▼
                     ┌─────────────────┐
                     │   HERE API      │
                     │   (Internet)    │
                     └─────────────────┘
                               │
                               ▼
┌──────────────────────────────┴────────────────────────┐
│                  SQLite Database                       │
│  ┌──────────────────┐  ┌──────────────────────┐      │
│  │Source_Addresses  │  │ Geocoded_Addresses   │      │
│  └──────────────────┘  └──────────────────────┘      │
└────────────────────────────────────────────────────────┘
```

### Snowflake Architecture
```
┌────────────────────────────────────────────────────────┐
│              Snowflake Data Cloud                      │
│                                                        │
│  ┌──────────────────┐  ┌──────────────────────┐      │
│  │Source_Addresses  │  │ Geocoded_Addresses   │      │
│  └────────┬─────────┘  └──────────────────────┘      │
│           │                                            │
│           ▼                                            │
│  ┌────────────────────────────────┐                   │
│  │  Stored Procedure              │                   │
│  │  Process_Ungeocoded_Addresses  │                   │
│  └──────────────┬─────────────────┘                   │
│                 │                                      │
│                 ▼                                      │
│  ┌─────────────────────────────────┐                  │
│  │  Python UDF                     │                  │
│  │  geocode_address()              │                  │
│  └──────────────┬──────────────────┘                  │
│                 │                                      │
│                 ▼                                      │
│  ┌─────────────────────────────────┐                  │
│  │  External Access Integration    │                  │
│  │  + Network Rule                 │                  │
│  │  + Secret (API Key)             │                  │
│  └──────────────┬──────────────────┘                  │
└─────────────────┼───────────────────────────────────────┘
                  │
                  ▼
        ┌─────────────────┐
        │   HERE API      │
        │   (Internet)    │
        └─────────────────┘
```

## Security Considerations

### API Key Storage

**Python Version:**
- Option 1: Environment variable
  ```python
  import os
  api_key = os.environ.get('HERE_API_KEY')
  ```
- Option 2: Config file (not in git)
- Option 3: Secrets manager (production)

**Snowflake Version:**
- Uses Snowflake Secrets (best practice)
- API key never exposed in queries
- Managed through Snowflake security

### Network Security

**Python Version:**
- Direct HTTPS connection
- Verify SSL certificates
- Consider using proxy if needed

**Snowflake Version:**
- External Access Integration
- Network rules define allowed endpoints
- Controlled through Snowflake security policies

## Performance Optimization

### Sequential Processing (Current Implementation)
```
Address 1 → API → Process → Store → Update
   ↓
Address 2 → API → Process → Store → Update
   ↓
Address 3 → API → Process → Store → Update
```

**Time:** N addresses × (API latency + processing)

### Potential Improvements

1. **Batch API Calls** (if API supports)
2. **Parallel Processing** (respect rate limits)
3. **Caching** (avoid re-geocoding same address)
4. **Async Processing** (Python asyncio)

## Monitoring and Logging

### Key Metrics to Track

1. **Success Rate**
   - Addresses geocoded / Addresses attempted

2. **API Response Time**
   - Average latency per request

3. **Error Types**
   - Invalid addresses
   - API failures
   - Network issues

4. **Daily Volume**
   - Track against API quota

### Example Query (Snowflake)
```sql
SELECT 
    COUNT(*) as total_addresses,
    SUM(CASE WHEN GeoCoded = 'Yes' THEN 1 ELSE 0 END) as geocoded,
    SUM(CASE WHEN GeoCoded = 'No' THEN 1 ELSE 0 END) as pending,
    ROUND(100.0 * SUM(CASE WHEN GeoCoded = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) as success_rate_pct
FROM Source_Addresses;
```

## Troubleshooting Guide

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| No results | Invalid API key | Verify key at HERE portal |
| Rate limit error | Too many requests | Increase delay between calls |
| Address not found | Ambiguous address | Add more specificity (city, state) |
| Wrong coordinates | Multiple matches | Review address format |
| Network error | Firewall/proxy | Check network rules |
| Database locked (SQLite) | Concurrent access | Use connection pooling |

## Next Steps / Extensions

1. **Add reverse geocoding** (lat/long → address)
2. **Batch geocoding API** (multiple addresses per request)
3. **Address validation** before geocoding
4. **Duplicate detection** (same address, different format)
5. **Geocoding quality score** tracking
6. **Historical tracking** (address changes over time)
7. **Integration with mapping tools** (display on map)
8. **CSV import/export** functionality

