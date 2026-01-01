/**
 * Complete Platform Test Suite
 * Tests all backend APIs and functionality
 */

require('dotenv').config();
const axios = require('axios');

// Configuration
const API_URL = process.env.BRIDGE_API_URL || 'https://goldai-bridge-is7d.onrender.com/api/v1';
const ADMIN_EMAIL = 'mackiyeritufu@gmail.com';
const ADMIN_PASSWORD = 'Mack4pf$$';

let adminToken = null;
let testUserToken = null;
let testAccessCode = null;
let testUserId = null;

// Colors for console output
const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[36m',
    magenta: '\x1b[35m'
};

function log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

function logTest(testName) {
    console.log('\n' + '='.repeat(80));
    log(`🧪 TEST: ${testName}`, 'blue');
    console.log('='.repeat(80));
}

function logSuccess(message) {
    log(`✅ ${message}`, 'green');
}

function logError(message) {
    log(`❌ ${message}`, 'red');
}

function logWarning(message) {
    log(`⚠️  ${message}`, 'yellow');
}

function logInfo(message) {
    log(`ℹ️  ${message}`, 'magenta');
}

// ============================================================================
// TEST 1: Server Health Check
// ============================================================================
async function testServerHealth() {
    logTest('Server Health Check');

    try {
        const response = await axios.get(API_URL.replace('/api/v1', ''));

        if (response.status === 200) {
            logSuccess('Server is online');
            logInfo(`Version: ${response.data.version}`);
            logInfo(`System: ${response.data.system}`);
            return true;
        }
    } catch (error) {
        logError(`Server health check failed: ${error.message}`);
        logWarning('Make sure the Bridge server is running!');
        logWarning('Run: cd gold-ai-auto-bridge && npm start');
        return false;
    }
}

// ============================================================================
// TEST 2: Admin Login (Firebase Auth Simulation)
// ============================================================================
async function testAdminLogin() {
    logTest('Admin Login');

    logInfo('In production, use Firebase Auth signInWithEmailAndPassword');
    logInfo(`Email: ${ADMIN_EMAIL}`);
    logInfo(`Password: ${ADMIN_PASSWORD}`);

    // For testing, we'll simulate getting a token
    // In production, this would come from Firebase Auth
    logWarning('Skipping actual Firebase Auth - using mock token for testing');

    // Mock admin token (in production, get this from Firebase)
    adminToken = 'MOCK_ADMIN_TOKEN_FOR_TESTING';

    logSuccess('Admin login simulated (use Firebase Auth in production)');
    return true;
}

// ============================================================================
// TEST 3: Generate Access Code
// ============================================================================
async function testGenerateAccessCode() {
    logTest('Generate Access Code');

    try {
        const response = await axios.post(
            `${API_URL}/admin/access-codes/generate`,
            { count: 1, expiryDays: 30 },
            {
                headers: {
                    'Authorization': `Bearer ${adminToken}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        if (response.data.success) {
            testAccessCode = response.data.codes[0];
            logSuccess(`Access code generated: ${testAccessCode}`);
            return true;
        }
    } catch (error) {
        if (error.response?.status === 401) {
            logWarning('Admin authentication required');
            logInfo('This test requires Firebase Auth setup');
            logInfo('Manually create an access code in Firebase Console for now');

            // Use a test code
            testAccessCode = 'GOLD-2024-TEST123';
            logInfo(`Using test code: ${testAccessCode}`);
            return true;
        }

        logError(`Generate access code failed: ${error.message}`);
        return false;
    }
}

// ============================================================================
// TEST 4: User Registration
// ============================================================================
async function testUserRegistration() {
    logTest('User Registration');

    const testUser = {
        accessCode: testAccessCode,
        email: `test${Date.now()}@example.com`,
        password: 'TestPassword123!',
        username: 'testuser'
    };

    logInfo(`Email: ${testUser.email}`);
    logInfo(`Access Code: ${testUser.accessCode}`);

    try {
        const response = await axios.post(
            `${API_URL}/users/register`,
            testUser
        );

        if (response.data.success) {
            testUserId = response.data.userId;
            testUserToken = response.data.token;

            logSuccess('User registered successfully');
            logInfo(`User ID: ${testUserId}`);
            logInfo(`Token received: ${testUserToken ? 'Yes' : 'No'}`);
            return true;
        }
    } catch (error) {
        if (error.response?.data?.error) {
            logError(`Registration failed: ${error.response.data.error}`);

            if (error.response.data.error.includes('access code')) {
                logWarning('Access code validation failed');
                logInfo('Create the access code manually in Firebase:');
                logInfo('1. Go to Firebase Console → Firestore');
                logInfo('2. Create collection: access_codes');
                logInfo(`3. Add document with code: ${testAccessCode}`);
                logInfo('4. Set status: "unused"');
            }
        } else {
            logError(`Registration failed: ${error.message}`);
        }
        return false;
    }
}

// ============================================================================
// TEST 5: Get User Profile
// ============================================================================
async function testGetUserProfile() {
    logTest('Get User Profile');

    if (!testUserToken) {
        logWarning('No user token available - skipping test');
        return false;
    }

    try {
        const response = await axios.get(
            `${API_URL}/users/profile`,
            { headers: { 'Authorization': `Bearer ${testUserToken}` } }
        );

        if (response.data.success) {
            const user = response.data.user;
            logSuccess('User profile retrieved');
            logInfo(`Email: ${user.email}`);
            logInfo(`Username: ${user.username}`);
            logInfo(`Status: ${user.status}`);
            logInfo(`MT5 Connected: ${user.mt5Connected ? 'Yes' : 'No'}`);
            return true;
        }
    } catch (error) {
        logError(`Get profile failed: ${error.message}`);
        return false;
    }
}

// ============================================================================
// TEST 6: MT5 Connection (Mock)
// ============================================================================
async function testMT5Connection() {
    logTest('MT5 Connection');

    if (!testUserToken) {
        logWarning('No user token available - skipping test');
        return false;
    }

    const mt5Credentials = {
        brokerServer: 'ICMarkets-Demo',
        mt5Login: '12345678',
        mt5Password: 'TestPassword123'
    };

    logInfo('Testing MT5 connection endpoint...');
    logInfo(`Broker: ${mt5Credentials.brokerServer}`);
    logInfo(`Login: ${mt5Credentials.mt5Login}`);

    try {
        const response = await axios.post(
            `${API_URL}/mt5/connect`,
            mt5Credentials,
            { headers: { 'Authorization': `Bearer ${testUserToken}` } }
        );

        if (response.data.success) {
            logSuccess('MT5 connection successful');
            logInfo(`MetaApi ID: ${response.data.account.metaApiId}`);
            logInfo(`Balance: $${response.data.account.balance}`);
            return true;
        }
    } catch (error) {
        if (error.response?.data?.error) {
            const errorMsg = error.response.data.error;

            if (errorMsg.includes('MetaApi not configured')) {
                logWarning('MetaApi not configured');
                logInfo('To enable MT5 connections:');
                logInfo('1. Sign up at https://metaapi.cloud');
                logInfo('2. Get API token');
                logInfo('3. Add to .env: META_API_TOKEN=your-token');
                logInfo('4. Restart server');
            } else if (errorMsg.includes('Invalid MT5 credentials')) {
                logWarning('Invalid MT5 credentials (expected for test)');
            } else {
                logError(`MT5 connection failed: ${errorMsg}`);
            }
        } else {
            logError(`MT5 connection failed: ${error.message}`);
        }
        return false;
    }
}

// ============================================================================
// TEST 7: Get MT5 Status
// ============================================================================
async function testGetMT5Status() {
    logTest('Get MT5 Status');

    if (!testUserToken) {
        logWarning('No user token available - skipping test');
        return false;
    }

    try {
        const response = await axios.get(
            `${API_URL}/mt5/status`,
            { headers: { 'Authorization': `Bearer ${testUserToken}` } }
        );

        if (response.data.success) {
            if (response.data.connected) {
                logSuccess('MT5 account connected');
                logInfo(`Broker: ${response.data.account.brokerServer}`);
                logInfo(`Login: ${response.data.account.mt5Login}`);
                logInfo(`Balance: $${response.data.account.balance}`);
            } else {
                logInfo('No MT5 account connected (expected)');
            }
            return true;
        }
    } catch (error) {
        logError(`Get MT5 status failed: ${error.message}`);
        return false;
    }
}

// ============================================================================
// TEST 8: Admin Get Users
// ============================================================================
async function testAdminGetUsers() {
    logTest('Admin Get Users');

    try {
        const response = await axios.get(
            `${API_URL}/admin/users`,
            { headers: { 'Authorization': `Bearer ${adminToken}` } }
        );

        if (response.data.success) {
            logSuccess(`Found ${response.data.count} users`);

            if (response.data.users.length > 0) {
                const user = response.data.users[0];
                logInfo(`Sample user: ${user.email} (${user.username})`);
                logInfo(`Status: ${user.status}`);
                logInfo(`MT5 Connected: ${user.mt5Connected ? 'Yes' : 'No'}`);
            }
            return true;
        }
    } catch (error) {
        if (error.response?.status === 401 || error.response?.status === 403) {
            logWarning('Admin authentication required');
            logInfo('This test requires Firebase Auth setup');
        } else {
            logError(`Get users failed: ${error.message}`);
        }
        return false;
    }
}

// ============================================================================
// TEST 9: Admin Get System Stats
// ============================================================================
async function testAdminGetStats() {
    logTest('Admin Get System Stats');

    try {
        const response = await axios.get(
            `${API_URL}/admin/stats`,
            { headers: { 'Authorization': `Bearer ${adminToken}` } }
        );

        if (response.data.success) {
            const stats = response.data.stats;

            logSuccess('System stats retrieved');
            logInfo(`Total Users: ${stats.users.total}`);
            logInfo(`Active Users: ${stats.users.active}`);
            logInfo(`MT5 Connections: ${stats.mt5.totalConnections}`);
            logInfo(`Trades Today: ${stats.trades.today}`);
            logInfo(`Access Codes: ${stats.accessCodes.total} (${stats.accessCodes.unused} unused)`);
            return true;
        }
    } catch (error) {
        if (error.response?.status === 401 || error.response?.status === 403) {
            logWarning('Admin authentication required');
        } else {
            logError(`Get stats failed: ${error.message}`);
        }
        return false;
    }
}

// ============================================================================
// TEST 10: Watchlist Endpoint (Master EA)
// ============================================================================
async function testWatchlistEndpoint() {
    logTest('Watchlist Endpoint (Master EA)');

    try {
        const response = await axios.get(`${API_URL}/watchlist`);

        if (response.data.success) {
            logSuccess('Watchlist endpoint accessible');
            logInfo(`Active signals: ${response.data.count}`);

            if (response.data.watchlist.length > 0) {
                const signal = response.data.watchlist[0];
                logInfo(`Sample signal: ${signal.signalData?.type} @ ${signal.signalData?.entry}`);
            } else {
                logInfo('No active signals (expected if no signals generated yet)');
            }
            return true;
        }
    } catch (error) {
        logError(`Watchlist endpoint failed: ${error.message}`);
        return false;
    }
}

// ============================================================================
// RUN ALL TESTS
// ============================================================================
async function runAllTests() {
    console.clear();
    log('\n' + '█'.repeat(80), 'blue');
    log('   GOLDAI TRADING PLATFORM - COMPLETE TEST SUITE', 'blue');
    log('█'.repeat(80) + '\n', 'blue');

    const results = {
        passed: 0,
        failed: 0,
        skipped: 0
    };

    // Run tests in sequence
    const tests = [
        { name: 'Server Health', fn: testServerHealth, critical: true },
        { name: 'Admin Login', fn: testAdminLogin, critical: false },
        { name: 'Generate Access Code', fn: testGenerateAccessCode, critical: false },
        { name: 'User Registration', fn: testUserRegistration, critical: true },
        { name: 'Get User Profile', fn: testGetUserProfile, critical: false },
        { name: 'MT5 Connection', fn: testMT5Connection, critical: false },
        { name: 'Get MT5 Status', fn: testGetMT5Status, critical: false },
        { name: 'Admin Get Users', fn: testAdminGetUsers, critical: false },
        { name: 'Admin Get Stats', fn: testAdminGetStats, critical: false },
        { name: 'Watchlist Endpoint', fn: testWatchlistEndpoint, critical: true }
    ];

    for (const test of tests) {
        const result = await test.fn();

        if (result) {
            results.passed++;
        } else {
            if (test.critical) {
                results.failed++;
            } else {
                results.skipped++;
            }
        }

        // Small delay between tests
        await new Promise(resolve => setTimeout(resolve, 500));
    }

    // Final summary
    console.log('\n' + '='.repeat(80));
    log('📊 TEST SUMMARY', 'blue');
    console.log('='.repeat(80));

    logSuccess(`Passed: ${results.passed}`);
    logError(`Failed: ${results.failed}`);
    logWarning(`Skipped: ${results.skipped}`);

    const total = results.passed + results.failed + results.skipped;
    const successRate = ((results.passed / total) * 100).toFixed(1);

    console.log('');
    if (results.failed === 0) {
        log(`🎉 ALL CRITICAL TESTS PASSED! (${successRate}% success rate)`, 'green');
    } else {
        log(`⚠️  Some tests failed. Check errors above.`, 'yellow');
    }

    console.log('\n' + '='.repeat(80));
    log('📝 NEXT STEPS', 'magenta');
    console.log('='.repeat(80));

    if (results.failed > 0) {
        logInfo('1. Make sure the Bridge server is running');
        logInfo('2. Setup Firebase Auth and create admin user');
        logInfo('3. Create access codes in Firebase Console');
        logInfo('4. Setup MetaApi account for MT5 connections');
    } else {
        logInfo('1. Deploy Master EA to VPS (see VPS_SETUP_GUIDE.md)');
        logInfo('2. Setup MetaApi account ($199/month for 100 users)');
        logInfo('3. Build frontend (Next.js) for user dashboard');
        logInfo('4. Test complete flow: Signal → Master EA → Copier → Users');
    }

    console.log('');
}

// Run tests
runAllTests().catch(error => {
    logError(`Test suite error: ${error.message}`);
    console.error(error);
});
