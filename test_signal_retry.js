const signalRequester = require('./src/services/signalRequester');

// Mock environment variable for the test
process.env.GOLD_MENTOR_API_URL = 'https://goldai-mentor-pro-rrue.onrender.com';

async function testRetryLogic() {
    console.log('🧪 Starting Local Test: Signal Retry Logic');
    console.log('------------------------------------------------');

    try {
        // We will try to fetch just one signal to see the retry behavior
        // The real server is currently throwing 503s, so this should trigger our catch block
        const result = await signalRequester.requestSignal('15m', '200_500');

        if (result) {
            console.log('✅ Test Passed: Signal fetched successfully!');
        } else {
            console.log('⚠️ Test Result: Signal filtered or null (Expected if confidence < 70)');
        }

    } catch (error) {
        console.log('------------------------------------------------');
        console.log('🔴 Final Result after Retries:');
        console.log(`   Error: ${error.message}`);
        console.log('   (If you saw "Retrying in 15 seconds..." above, the logic is WORKING)');
    }
}

testRetryLogic();
