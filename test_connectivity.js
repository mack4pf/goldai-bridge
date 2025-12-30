const axios = require('axios');

const API_URL = 'https://goldai-mentor-pro-rrue.onrender.com';

async function testConnectivity() {
    console.log(`🔍 Testing connectivity to: ${API_URL}`);

    // 1. Health Check
    try {
        console.log('1️⃣ Pinging Health Endpoint (/health)...');
        const start = Date.now();
        const health = await axios.get(`${API_URL}/health`, { timeout: 10000 });
        const latency = Date.now() - start;
        console.log(`   ✅ Health OK (${latency}ms):`, health.data);
    } catch (error) {
        console.error('   ❌ Health Check Failed:', error.message);
        if (error.response) console.error('   Status:', error.response.status);
    }

    // 2. Signal Request (Heavy)
    try {
        console.log('\n2️⃣ Testing Signal Request (/api/signal/generate)...');
        console.log('   (This is the heavy request that was failing with 503)');

        const start = Date.now();
        const response = await axios.post(
            `${API_URL}/api/signal/generate`,
            { timeframe: '5m', balanceCategory: '10_50' },
            {
                headers: { 'x-api-key': 'development' }, // Using default development key
                timeout: 60000
            }
        );
        const duration = (Date.now() - start) / 1000;

        console.log(`   ✅ Signal Received in ${duration.toFixed(2)}s!`);
        console.log(`   Confidence: ${response.data.confidence}%`);
        console.log(`   Signal: ${response.data.signal}`);
    } catch (error) {
        console.error('   ❌ Signal Request Failed:', error.message);
        if (error.response) {
            console.error('   Status:', error.response.status);
            console.error('   Data:', error.response.data);
        }
    }
}

testConnectivity();
