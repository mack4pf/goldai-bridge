/**
 * Test Master EA Trade Broadcast
 * Master EA (VPS) → Bridge API → Copier Manager
 */

require('dotenv').config();
const axios = require('axios');

const BRIDGE_URL = process.env.BRIDGE_API_URL || 'http://localhost:3001/api/v1';

async function testTradeBroadcast() {
    console.log('\n' + '='.repeat(80));
    console.log('🧪 TESTING MASTER EA TRADE BROADCAST');
    console.log('='.repeat(80) + '\n');

    // Step 1: Simulate Master EA OPENING a trade
    console.log('🚀 Step 1: Simulating Master EA OPENING a BUY trade...\n');

    const openEvent = {
        symbol: 'XAUUSD',
        type: 'BUY',
        operation: 'OPEN',
        price: 2650.00,
        sl: 2645.00,
        tp: 2655.00,
        ticket: 1234567,
        lotSize: 0.10
    };

    try {
        const response = await axios.post(
            `${BRIDGE_URL}/copier/master/trade`,
            openEvent,
            {
                headers: { 'Content-Type': 'application/json' },
                timeout: 10000
            }
        );

        if (response.data.success) {
            console.log('✅ Trade event received by Bridge!');
            console.log(`   Message: ${response.data.message}`);
        } else {
            console.log('⚠️  Bridge response:', response.data);
        }

    } catch (error) {
        console.error('❌ Failed to broadcast open event:', error.message);
    }

    // Step 2: Simulate Master EA PARTIAL CLOSE (TP1)
    console.log('\n🎯 Step 2: Simulating Master EA PARTIAL CLOSE (TP1)...\n');

    const partialEvent = {
        symbol: 'XAUUSD',
        type: 'BUY',
        operation: 'PARTIAL_CLOSE_TP1',
        price: 2655.00,
        sl: 2650.00, // Moved to BE
        tp: 2660.00,
        ticket: 1234567,
        lotSize: 0.03 // Closing 33%
    };

    try {
        const response = await axios.post(
            `${BRIDGE_URL}/copier/master/trade`,
            partialEvent,
            {
                headers: { 'Content-Type': 'application/json' },
                timeout: 10000
            }
        );

        if (response.data.success) {
            console.log('✅ Partial close event received by Bridge!');
        }
    } catch (error) {
        console.error('❌ Failed to broadcast partial close:', error.message);
    }

    // Step 3: Summary
    console.log('\n' + '='.repeat(80));
    console.log('✅ TRADE BROADCAST TEST COMPLETE');
    console.log('='.repeat(80));
    console.log('\n📋 Verification Details:');
    console.log('   - Check Bridge server logs for "MASTER TRADE DETECTED"');
    console.log('   - Verify logic handled "OPEN" and "PARTIAL_CLOSE_TP1"');
    console.log('   - Trade distribution happens async in backend\n');
}

testTradeBroadcast().catch(error => {
    console.error('Test error:', error);
});
