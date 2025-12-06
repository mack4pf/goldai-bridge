/**
 * Hourly Signal Scheduler
 * Requests signals from Gold Mentor Pro every hour
 * Fetches 5min and 15min signals for $50 and $200 balance tiers
 */
const cron = require('node-cron');
const axios = require('axios');
const signalRequester = require('../services/signalRequester');

class SignalScheduler {
    constructor() {
        // IMPORTANT: This URL will be replaced when deploying to Render
        // NOTE: Don't add /api/v1 - we add it in the post URL
        this.bridgeAPIUrl = process.env.BRIDGE_API_URL || 'http://localhost:3001';

        this.isRunning = false;
    }

    start() {
        console.log('\n⏰ Signal Scheduler Started');
        console.log('📡 Will request signals every 1 hour');
        console.log('🎯 Timeframes: 5min, 15min');
        console.log('💰 Balance Tiers: $50, $200');

        // Run every hour at minute 0
        cron.schedule('0 */1 * * *', async () => {
            await this.runSignalCycle();
        });

        // Also run immediately on startup
        console.log('🔄 Running initial signal cycle...\n');
        setTimeout(() => this.runSignalCycle(), 5000); // 5 second delay
    }

    async runSignalCycle() {
        if (this.isRunning) {
            console.log('⚠️  Signal cycle already running, skipping...');
            return;
        }

        this.isRunning = true;
        const timestamp = new Date().toISOString();

        try {
            console.log('\n' + '='.repeat(80));
            console.log(`⏰ HOURLY SIGNAL CYCLE - ${timestamp}`);
            console.log('='.repeat(80));

            // Request all configured signals from Gold Mentor Pro
            const requestResults = await signalRequester.requestAllSignals();

            console.log(`\n📊 Request Summary:`);
            console.log(`   Total Requested: ${requestResults.totalRequested}`);
            console.log(`   Successful: ${requestResults.successCount}`);
            console.log(`   Failed: ${requestResults.errorCount}`);

            if (requestResults.successCount === 0) {
                console.log('\n❌ No signals received. Check Gold Mentor Pro server.\n');
                console.log('='.repeat(80));
                this.isRunning = false;
                return;
            }

            // Process and broadcast each successful signal
            console.log(`\n📡 Broadcasting ${requestResults.successCount} signals to Bridge API...\n`);

            for (const result of requestResults.results) {
                await this.broadcastSignal(result);
                await this.delay(1000); // 1 second between broadcasts
            }

            console.log('\n✅ SIGNAL CYCLE COMPLETE');
            console.log('='.repeat(80));

        } catch (error) {
            console.error('\n❌ SIGNAL CYCLE ERROR:', error.message);
            console.log('='.repeat(80));
        } finally {
            this.isRunning = false;
        }
    }

    async broadcastSignal(result) {
        try {
            const { timeframe, balanceCategory, signal } = result;

            console.log(`\n   Processing: ${timeframe} ${balanceCategory}`);

            // Convert to SIMPLE format for old routes.js
            const simpleSignal = {
                type: signal.signal, // BUY or SELL
                symbol: signal.symbol || 'XAUUSD',
                entry: signal.entry,
                sl: signal.stopLoss,
                tp: signal.takeProfit1,
                timeframe: timeframe,
                balanceCategory: balanceCategory,
                confidence: signal.confidence,
                timestamp: new Date().toISOString()
            };

            // Send to Bridge API - basic /signals endpoint
            const response = await axios.post(
                `${this.bridgeAPIUrl}/api/v1/signals`,
                simpleSignal,
                {
                    headers: { 'Content-Type': 'application/json' },
                    timeout: 10000
                }
            );

            console.log(`   ✅ ${signal.signal} @ ${signal.entry} sent successfully`);
            if (response.data) {
                console.log(`      Broadcast confirmed`);
            }

        } catch (error) {
            console.error(`   ❌ Broadcast failed: ${error.message}`);
            if (error.response) {
                console.error(`      Status: ${error.response.status}`);
                console.error(`      Data:`, error.response.data);
            } else if (error.request) {
                console.error(`      No response received from server`);
                console.error(`      Check Bridge API is running at: ${this.bridgeAPIUrl}`);
            } else {
                console.error(`      Error:`, error.message);
            }
        }
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

module.exports = new SignalScheduler();
