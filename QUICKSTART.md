# Quick Start Guide - Geocoding Demo

Get started with geocoding in under 5 minutes!

## 🚀 Fastest Path: Python Version

### 1. Get HERE API Key (2 minutes)
1. Go to https://account.here.com/sign-up
2. Sign up for free account
3. Go to "Access Manager"
4. Click "Create new app" → Create API Key
5. Copy the API key

### 2. Install and Run (1 minute)
```bash
# Install dependencies
pip install requests

# Run the demo
python geocode_demo_python.py
```

### 3. Use It (2 minutes)
```
Enter your HERE API key: [paste your key]

Menu:
1. View Source Addresses
2. View Geocoded Addresses
3. View Combined Results
4. Process Ungeocoded Addresses    ← Start here!
5. Add New Address
6. Reset
7. Exit

Enter your choice: 4
```

That's it! The demo will geocode all sample addresses and show you the results.

## 📊 What You Get

**Input:**
- `4601 Collins Ave Miami Beach FL 33140`

**Output:**
- Street: `Collins Ave`
- City: `Miami Beach`
- State: `Florida`
- Zip: `33140`
- Latitude: `25.8201`
- Longitude: `-80.12256`

## 🎯 Common Use Cases

### Add Your Own Address
```
Menu choice: 5
Name: My Home
Address: 123 Main St Springfield MA 01103
```

Then process it (Menu choice: 4)

### Batch Process Addresses
```bash
python batch_geocode_example.py YOUR_API_KEY
```

### View All Results
```
Menu choice: 3
```

Shows a joined view of original addresses + geocoded results

## 🏢 Using Snowflake Instead?

### 1. Update the API Key
Open `geocode_demo_complete.sql` and find line ~51:
```sql
SECRET_STRING = 'YOUR_API_KEY_HERE';  -- Replace this
```

### 2. Run in Snowflake
Copy the entire SQL file and execute in your Snowflake worksheet

### 3. Geocode Addresses
```sql
CALL Process_Ungeocoded_Addresses();
```

## 💡 Sample Addresses Included

The demo comes with these pre-loaded addresses:
- Miami Beach Property
- Rochester Home
- Greenville Residence
- Empire State Building
- Golden Gate Bridge
- White House

## 📝 Key Tables

### Source_Addresses
Where addresses start (GeoCoded = 'No')

### Geocoded_Addresses
Where geocoded results are stored

## ⚠️ Troubleshooting

**"Invalid API key"**
- Make sure you copied the full key
- Verify it's a REST API key (not JavaScript)

**"No addresses to geocode"**
- All addresses already processed
- Use Menu option 6 to reset
- Or add new addresses with Menu option 5

**"Rate limit"**
- Free tier: 250,000 requests/month
- Script uses 0.2 second delay between requests
- You're well within limits!

## 📚 Want More Details?

- Full documentation: `README.md`
- Workflow diagrams: `WORKFLOW.md`
- Batch processing: `batch_geocode_example.py`

## 🆓 Free Tier Limits

HERE API Free Tier:
- ✅ 250,000 geocoding requests/month
- ✅ No credit card required
- ✅ Perfect for demos and testing

## 🎓 Next Steps

1. ✅ Run the demo with sample data
2. ✅ Add your own addresses
3. ✅ Try batch processing
4. ✅ Integrate into your application

## 🤝 Need Help?

- Review `README.md` for detailed docs
- Check `WORKFLOW.md` for architecture
- HERE API Docs: https://developer.here.com/

---

**That's it! You're geocoding addresses!** 🎉

