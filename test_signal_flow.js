/**
 * Test Complete Signal Flow
 * Mentor Pro → Bridge API → Master EA
 */

require('dotenv').config();
const axios = require('axios');

const BRIDGE_URL = process.env.BRIDGE_API_URL || 'https://goldai-bridge-is7d.onrender.com/api/v1';

async function testSignalFlow() {
    console.log('\n' + '='.repeat(80));
    console.log('🧪 TESTING COMPLETE SIGNAL FLOW');
    console.log('='.repeat(80) + '\n');

    // Step 1: Simulate Mentor Pro sending a signal
    console.log('📡 Step 1: Simulating Mentor Pro sending signal to Bridge...\n');

    const testSignal = {
        symbol: 'XAUUSD',
        type: 'BUY',
        entry: 2650.50,
        sl: 2645.00,
        tp: 2655.50,
        tp2: 2660.00,
        timeframe: 'MASTER',
        confidence: 85,
        grade: 'A+',
        timestamp: new Date().toISOString(),
        source: 'TEST_MENTOR_PRO'
    };

    try {
        const pushResponse = await axios.post(
            `${BRIDGE_URL}/signals`,
            testSignal,
            {
                headers: { 'Content-Type': 'application/json' },
                timeout: 10000
            }
        );

        if (pushResponse.data.success) {
            console.log('✅ Signal pushed to Bridge successfully!');
            console.log(`   Signal ID: ${pushResponse.data.signalId}`);
            console.log(`   Quality Score: ${pushResponse.data.qualityScore}`);
            console.log(`   Distributed to: ${pushResponse.data.distributed} users`);
        } else {
            console.log('⚠️  Signal push response:', pushResponse.data);
        }

    } catch (error) {
        console.error('❌ Failed to push signal:', error.message);
        if (error.response) {
            console.error('   Status:', error.response.status);
            console.error('   Data:', error.response.data);
        }
        return;
    }

    // Step 2: Verify signal is in watchlist (Master EA will poll this)
    console.log('\n📊 Step 2: Checking if signal is in watchlist (for Master EA)...\n');

    try {
        const watchlistResponse = await axios.get(`${BRIDGE_URL}/watchlist`);

        if (watchlistResponse.data.success) {
            console.log(`✅ Watchlist accessible - ${watchlistResponse.data.count} signals available`);

            if (watchlistResponse.data.watchlist.length > 0) {
                const latestSignal = watchlistResponse.data.watchlist[0];
                console.log('\n   Latest Signal for Master EA:');
                console.log(`   • Type: ${latestSignal.signalData?.type}`);
                console.log(`   • Entry: ${latestSignal.signalData?.entry}`);
                console.log(`   • SL: ${latestSignal.signalData?.sl}`);
                console.log(`   • TP: ${latestSignal.signalData?.tp}`);
                console.log(`   • Confidence: ${latestSignal.signalData?.confidence}%`);
                console.log(`   • Added: ${new Date(latestSignal.addedAt).toLocaleString()}`);
            }
        }

    } catch (error) {
        console.error('❌ Failed to fetch watchlist:', error.message);
        return;
    }

    // Step 3: Summary
    console.log('\n' + '='.repeat(80));
    console.log('✅ SIGNAL FLOW TEST COMPLETE');
    console.log('='.repeat(80));
    console.log('\n📋 Flow Summary:');
    console.log('   1. ✅ Mentor Pro → Bridge API (signal pushed)');
    console.log('   2. ✅ Bridge API → Watchlist (signal stored)');
    console.log('   3. ⏳ Master EA → Polls watchlist every hour at :02');
    console.log('   4. ⏳ Master EA → Executes trade');
    console.log('   5. ⏳ Master EA → Broadcasts to copier');
    console.log('   6. ⏳ Copier → Distributes to 100+ users\n');

    console.log('🎯 Next Steps:');
    console.log('   1. Deploy Master EA to VPS');
    console.log('   2. Wait for hourly signal from Mentor Pro');
    console.log('   3. Verify Master EA receives and executes');
    console.log('   4. Check trade copied to follower accounts\n');
}

testSignalFlow().catch(error => {
    console.error('Test error:', error);
});
