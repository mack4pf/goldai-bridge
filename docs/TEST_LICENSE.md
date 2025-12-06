# Test License - Quick Start Guide

## 🧪 Test License Key

For testing and development purposes, we provide a **5-day test license**:

```
GOLDAI-TEST-2024
```

### Features
- ✅ Valid for **5 days** from activation
- ✅ Full system access (same as 30-day license)
- ✅ Perfect for testing EA and signals
- ✅ Can be reactivated after expiry for another 5 days

---

## How to Use Test License

### 1. **Activate Test License**

**Via API:**
```bash
POST http://localhost:3001/api/v1/license/activate
Content-Type: application/json

{
  "userId": "your_telegram_user_id",
  "licenseKey": "GOLDAI-TEST-2024"
}
```

**Response:**
```json
{
  "success": true,
  "licenseId": "abc123...",
  "expiresAt": "2023-12-11T14:00:00Z",
  "daysRemaining": 5,
  "isTestLicense": true,
  "message": "🧪 Test license activated (5 days)"
}
```

### 2. **Enter in MT5 EA**

In your MT5 Expert Advisor inputs:
- **License_Key**: `GOLDAI-TEST-2024`

### 3. **Test License Status**

**Check if valid:**
```bash
GET http://localhost:3001/api/v1/license/check?license=GOLDAI-TEST-2024
```

**Response (if active):**
```json
{
  "valid": true,
  "userId": "your_telegram_user_id",
  "expiresAt": "2023-12-11T14:00:00Z",
  "daysRemaining": 3,
  "isTestLicense": true
}
```

**Response (if expired):**
```json
{
  "valid": false,
  "reason": "License expired",
  "expiredAt": "2023-12-11T14:00:00Z"
}
```

---

## Regular License (30 Days)

For production use, you can generate and activate regular licenses:

### Generate New License Key
```javascript
const LicenseService = require('./src/services/licenseService');
const licenseService = new LicenseService(db);

const newKey = licenseService.generateLicenseKey();
// Example output: GOLDAI-A3F2-B8C1-D4E9
```

### Activate 30-Day License
```bash
POST http://localhost:3001/api/v1/license/activate
Content-Type: application/json

{
  "userId": "user_123",
  "licenseKey": "GOLDAI-A3F2-B8C1-D4E9"
}
```

---

## License Comparison

| Feature | Test License | Regular License |
|---------|--------------|-----------------|
| **Duration** | 5 days | 30 days |
| **Key** | `GOLDAI-TEST-2024` | Custom generated |
| **Full Features** | ✅ Yes | ✅ Yes |
| **Reactivation** | ✅ Unlimited | ❌ One-time per key |
| **Use Case** | Testing | Production |

---

## Testing Workflow

### Day 1: Setup
1. Activate test license
2. Configure EA in MT5
3. Verify license check works
4. Send test signals

### Days 2-4: Integration Testing
1. Test signal reception
2. Test watchlist monitoring
3. Test trade execution
4. Test daily limits
5. Monitor 5-day expiry countdown

### Day 5: Expiry Testing
1. Verify EA stops working at expiry
2. Test error messages
3. Reactivate test license
4. Verify EA resumes working

---

## Important Notes

> [!IMPORTANT]
> - Test license can be reactivated unlimited times
> - Each activation gives a fresh 5-day period
> - Expiry is calculated from activation time, not calendar days

> [!TIP]
> Use test license for:
> - Development and debugging
> - Demo accounts
> - User onboarding
> - Integration testing

> [!WARNING]
> Test license should NOT be used:
> - On live trading accounts
> - For production users
> - When real money is involved

---

## Quick Commands

### Activate Test License
```bash
curl -X POST http://localhost:3001/api/v1/license/activate \
  -H "Content-Type: application/json" \
  -d '{"userId":"test_user","licenseKey":"GOLDAI-TEST-2024"}'
```

### Check Test License
```bash
curl http://localhost:3001/api/v1/license/check?license=GOLDAI-TEST-2024
```

### Get User License Status
```bash
curl http://localhost:3001/api/v1/license/status/test_user
```

---

## Troubleshooting

### "License expired" error
**Solution:** Reactivate the test license for another 5 days

### EA not connecting
**Solution:** 
1. Check license key is exactly: `GOLDAI-TEST-2024`
2. Verify server is running on port 3001
3. Check MT5 WebRequest permissions

### License not found
**Solution:** Activate it first via `/license/activate` endpoint

---

## Next Steps

1. ✅ Activate test license
2. ✅ Set up MT5 EA
3. ✅ Send test signals
4. ✅ Verify full workflow
5. 🚀 Deploy with regular licenses

Perfect for getting started! 🎉
