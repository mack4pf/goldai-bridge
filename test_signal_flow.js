/**
 * Test Complete Signal Flow
 * Mentor Pro → Bridge API → Master EA
 */

require('dotenv').config();
const axios = require('axios');

const BRIDGE_URL = process.env.BRIDGE_API_URL || 'https://goldai-bridge-is7d.onrender.com/api/v1';

async function testSignalFlow() {
    console.log('\n' + '='.repeat(80));
    console.log('🧪 TESTING COMPLETE SIGNAL FLOW (Multi-TP Support)');
    console.log('='.repeat(80) + '\n');

    // Step 0: Clear current monitoring signals to ensure we get the fresh one
    console.log('🧹 Step 0: Archiving existing monitoring signals...\n');
    try {
        let hasMore = true;
        while (hasMore) {
            const currentWatchlist = await axios.get(`${BRIDGE_URL}/watchlist`);
            if (currentWatchlist.data.success && currentWatchlist.data.signalId) {
                console.log(`   Found old signal ${currentWatchlist.data.signalId}. Archiving...`);
                try {
                    await axios.post(`${BRIDGE_URL}/watchlist/update`, {
                        signalId: currentWatchlist.data.signalId,
                        status: 'archived_by_test'
                    });
                    console.log(`   ✅ Archived ${currentWatchlist.data.signalId}`);
                } catch (updateError) {
                    console.error(`   ❌ Failed to archive ${currentWatchlist.data.signalId}:`,
                        updateError.response?.data || updateError.message);
                    hasMore = false;
                }
            } else {
                hasMore = false;
            }
        }
        console.log('   ✅ Watchlist check complete.');
    } catch (e) {
        console.log('   (Error during watchlist fetch):', e.message);
    }

    // Step 1: Simulate Mentor Pro sending a signal
    console.log('\n📡 Step 1: Simulating Mentor Pro sending signal to Bridge...\n');

    const testSignal = {
        symbol: 'XAUUSD',
        type: 'BUY',
        entry: 2650.50,
        sl: 2646.50, // 40 pips
        tp: 2653.50,  // 30 pips
        tp2: 2655.50, // 50 pips
        tp3: 2660.50, // 100 pips
        tp4: 2665.50, // 150 pips
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

            // Wait for DB consistency
            await new Promise(resolve => setTimeout(resolve, 1500));

            // Step 2: Verify signal is in watchlist
            console.log('\n📊 Step 2: Checking watchlist for the new signal...\n');
            const watchlistResponse = await axios.get(`${BRIDGE_URL}/watchlist`);

            if (watchlistResponse.data.success && watchlistResponse.data.signalId === pushResponse.data.signalId) {
                const latestSignal = watchlistResponse.data;
                console.log('✅ Correct signal found in watchlist.');
                console.log(`   • TP1: ${latestSignal.tp}`);
                console.log(`   • TP2: ${latestSignal.tp2}`);
                console.log(`   • TP3: ${latestSignal.tp3}`);
                console.log(`   • TP4: ${latestSignal.tp4}`);

                const allTpsPresent = latestSignal.tp && latestSignal.tp2 && latestSignal.tp3 && latestSignal.tp4;
                if (allTpsPresent) {
                    console.log('\n🏆 SUCCESS: All 4 TP levels correctly stored and served!');
                } else {
                    console.error('\n❌ FAILURE: Missing TP levels in watchlist response.');
                }
            } else {
                console.error('\n❌ FAILURE: Could not find the pushed signal in watchlist.');
                console.log('   Response ID:', watchlistResponse.data.signalId);
                console.log('   Pushed ID:', pushResponse.data.signalId);
            }
        }

    } catch (error) {
        console.error('❌ Test failed:', error.message);
    }

    console.log('\n' + '='.repeat(80));
    console.log('✅ SIGNAL FLOW TEST COMPLETE');
    console.log('='.repeat(80));
}

testSignalFlow().catch(error => {
    console.error('Test error:', error);
});
