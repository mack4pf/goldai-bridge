const signalRequester = require('./src/services/signalRequester');

// Mock environment variable
process.env.GOLD_MENTOR_API_URL = 'https://goldai-mentor-pro-rrue.onrender.com';

async function testMultipleSignals() {
    console.log('🧪 Starting MULTIPLE Signal Stress Test (4 Requests)');
    console.log('------------------------------------------------');
    console.log('Target: https://goldai-mentor-pro-rrue.onrender.com');
    console.log('Logic: 5m/15m for $50 and $200 tiers (with delays)');
    console.log('------------------------------------------------');

    try {
        const start = Date.now();

        // This runs the production loop: 4 requests with 12s delays
        const report = await signalRequester.requestAllSignals();

        const duration = (Date.now() - start) / 1000;

        console.log('\n------------------------------------------------');
        console.log(`✅ Stress Test Completed in ${duration.toFixed(1)}s`);
        console.log(`📊 Summary: ${report.successCount} Success / ${report.errorCount} Failed`);
        console.log('------------------------------------------------');

        if (report.errors.length > 0) {
            console.log('❌ Errors:');
            report.errors.forEach(e => console.log(`   - ${e.timeframe} ${e.balanceCategory}: ${e.error}`));
        }

        if (report.results.length > 0) {
            console.log('✅ Successes:');
            report.results.forEach(r => {
                const conf = r.signal.confidence || 0;
                console.log(`   - ${r.timeframe} ${r.balanceCategory}: ${r.signal.signal} (${conf}%)`);
            });
        }

    } catch (error) {
        console.error('❌ Test Failed Critically:', error);
    }
}

testMultipleSignals();
