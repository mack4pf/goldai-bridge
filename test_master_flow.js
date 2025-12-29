const axios = require('axios');
require('dotenv').config();

const API_URL = 'http://localhost:3001/api/v1';

async function testMasterFlow() {
    console.log('🚀 Testing Single VPS Master Mode Flow\n');

    try {
        // 1. Simulate Incoming Signal (from signal scheduler)
        console.log('1. Posting Test Signal...');
        const signalData = {
            symbol: 'XAUUSD',
            type: 'BUY',
            entry: 2050.50,
            sl: 2045.00,
            tp: 2060.00,
            timeframe: '5m',
            confidence: 95
        };

        const postRes = await axios.post(`${API_URL}/signals`, signalData);
        if (postRes.data.success) {
            console.log('   ✅ Signal Posted Successfully');
            console.log(`      ID: ${postRes.data.signalId}`);
        } else {
            console.error('   ❌ Signal Post Failed:', postRes.data);
            return;
        }

        // 2. Simulate EA Polling (No Auth)
        console.log('\n2. Simulating EA Watchlist Poll (No Auth)...');
        // Note: We are sending a regular GET request without any x-license-key header
        const pollRes = await axios.get(`${API_URL}/watchlist`);

        if (pollRes.data.success) {
            console.log(`   ✅ Poll Successful`);
            console.log(`   Items in Watchlist: ${pollRes.data.count}`);

            const lastSignal = pollRes.data.watchlist.find(s => s.signalId === postRes.data.signalId);

            if (lastSignal) {
                console.log('   ✅ Found our test signal in watchlist!');
                console.log(`      User ID: ${lastSignal.userId} (Expected: MASTER_VPS)`);
                console.log(`      Status: ${lastSignal.status}`);
            } else {
                console.error('   ❌ Test signal NOT found in watchlist');
            }
        } else {
            console.error('   ❌ Poll Failed:', pollRes.data);
        }

    } catch (error) {
        console.error('\n❌ TEST FAILED with Error:');
        if (error.response) {
            console.error(`   Status: ${error.response.status}`);
            console.error(`   Data:`, error.response.data);
        } else {
            console.error(`   ${error.message}`);
        }
    }
}

testMasterFlow();
