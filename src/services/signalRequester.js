/**
 * Signal Requester Service
 * Fetches signals FROM the Gold Mentor Pro main server
 * Requests 5min and 15min signals with $50 and $200 balance categories
 */
const axios = require('axios');

class SignalRequester {
    constructor() {
        // IMPORTANT: This URL will be replaced with your Render URL when deployed
        this.goldMentorAPIUrl = process.env.GOLD_MENTOR_API_URL || 'https://goldai-mentor-pro-4.onrender.com';

        // Configuration for what signals to request
        this.signalConfig = {
            timeframes: ['5m', '15m'],
            balanceCategories: ['10_50', '200_500'], // $50 and $200 tiers
            requestInterval: 60 * 60 * 1000 // 1 hour in milliseconds
        };

        console.log('📡 Signal Requester Initialized');
        console.log(`   Gold Mentor API: ${this.goldMentorAPIUrl}`);
        console.log(`   Timeframes: ${this.signalConfig.timeframes.join(', ')}`);
        console.log(`   Balance Tiers: $50 (10_50), $200 (200_500)`);
    }

    /**
     * Request a signal from Gold Mentor Pro
     */
    async requestSignal(timeframe, balanceCategory) {
        try {
            console.log(`📡 Requesting ${timeframe} signal for ${balanceCategory} balance tier...`);

            // Build endpoint URL
            const endpoint = `${this.goldMentorAPIUrl}/api/signal/generate`;

            const response = await axios.post(
                endpoint,
                {
                    timeframe: timeframe,
                    balanceCategory: balanceCategory
                },
                {
                    headers: {
                        'Content-Type': 'application/json',
                        // Add API key if you implement authentication
                        'x-api-key': process.env.BRIDGE_API_KEY || 'development'
                    },
                    timeout: 60000 // 60 seconds
                }
            );

            if (!response.data || !response.data.signal) {
                throw new Error('Invalid signal data received from Gold Mentor Pro');
            }

            console.log(`✅ Signal received: ${response.data.signal} (${response.data.confidence}%)`);

            return response.data;

        } catch (error) {
            console.error(`❌ Signal request failed for ${timeframe}:`, error.message);

            if (error.code === 'ECONNREFUSED') {
                throw new Error('Cannot connect to Gold Mentor Pro server. Is it running?');
            }

            throw error;
        }
    }

    /**
     * Request all configured signals (5min and 15min for $50 and $200)
     */
    async requestAllSignals() {
        const results = [];
        const errors = [];

        for (const timeframe of this.signalConfig.timeframes) {
            for (const balanceCategory of this.signalConfig.balanceCategories) {
                try {
                    const signal = await this.requestSignal(timeframe, balanceCategory);
                    results.push({
                        timeframe,
                        balanceCategory,
                        signal,
                        success: true
                    });

                    // Small delay between requests
                    await this.delay(2000);

                } catch (error) {
                    console.error(`Failed: ${timeframe} - ${balanceCategory}`, error.message);
                    errors.push({
                        timeframe,
                        balanceCategory,
                        error: error.message,
                        success: false
                    });
                }
            }
        }

        return {
            results,
            errors,
            totalRequested: this.signalConfig.timeframes.length * this.signalConfig.balanceCategories.length,
            successCount: results.length,
            errorCount: errors.length
        };
    }

    /**
     * Convert Gold Mentor Pro signal to advanced format with confluence
     */
    convertToAdvancedFormat(aiSignal, timeframe, balanceCategory) {
        const direction = aiSignal.signal.replace('STRONG_', ''); // BUY or SELL

        // Map balance category to risk
        const riskMap = {
            '10_50': 6,    // $50 balance = 6% risk
            '51_100': 6,   // $100 balance = 6% risk
            '200_500': 5,  // $200 balance = 5% risk
            '1k_plus': 4   // $1000+ = 4% risk
        };

        const recommendedRisk = riskMap[balanceCategory] || 6;

        return {
            signalId: `SIG_${Date.now()}_${timeframe}_${balanceCategory}`,
            timestamp: new Date().toISOString(),
            timeframe: timeframe,
            symbol: 'XAUUSD',
            direction: direction,
            confidence: aiSignal.confidence || 70,

            entry: {
                price: aiSignal.entry,
                zone: {
                    min: aiSignal.entry - 3, // Tighter zone for scalping
                    max: aiSignal.entry + 3
                }
            },

            stopLoss: aiSignal.stopLoss,
            takeProfits: [
                { level: 1, price: aiSignal.takeProfit1, percentage: 50 },
                { level: 2, price: aiSignal.takeProfit2, percentage: 50 }
            ],

            confluence: this.extractConfluence(aiSignal, timeframe),

            riskManagement: {
                recommendedRisk: recommendedRisk,
                maxRisk: 8,
                slPips: Math.abs(aiSignal.entry - aiSignal.stopLoss) * 10,
                tpPips: [
                    Math.abs(aiSignal.takeProfit1 - aiSignal.entry) * 10,
                    Math.abs(aiSignal.takeProfit2 - aiSignal.entry) * 10
                ],
                balanceCategory: balanceCategory
            },

            validity: {
                expiresAt: new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString(),
                maxWaitTime: 120
            },

            // Keep original AI analysis
            originalAnalysis: {
                technicalAnalysis: aiSignal.technicalAnalysis,
                levelExplanation: aiSignal.levelExplanation,
                marketContext: aiSignal.marketContext,
                professionalRecommendation: aiSignal.professionalRecommendation
            }
        };
    }

    /**
     * Extract confluence data from AI signal
     */
    extractConfluence(aiSignal, timeframe) {
        const direction = aiSignal.signal.replace('STRONG_', '');

        // Extract RSI from technical analysis if available
        let rsiValue = 50;
        let rsiCondition = direction === 'SELL' ? 'ABOVE_60_TURNING_DOWN' : 'BELOW_40_TURNING_UP';

        if (aiSignal.technicalAnalysis) {
            const rsiMatch = aiSignal.technicalAnalysis.match(/RSI[:\s]+(\d+)/i);
            if (rsiMatch) {
                rsiValue = parseInt(rsiMatch[1]);
            }

            // Detect RSI condition from text
            if (aiSignal.technicalAnalysis.toLowerCase().includes('overbought')) {
                rsiCondition = 'ABOVE_70_OVERBOUGHT';
            } else if (aiSignal.technicalAnalysis.toLowerCase().includes('oversold')) {
                rsiCondition = 'BELOW_30_OVERSOLD';
            }
        }

        return {
            rsi: {
                period: 14,
                currentValue: rsiValue,
                condition: rsiCondition,
                description: aiSignal.technicalAnalysis || 'AI analysis provided'
            },
            candlestick: {
                required: direction === 'SELL' ? 'SHOOTING_STAR_OR_ENGULFING' : 'HAMMER_OR_BULLISH_ENGULFING',
                description: `Wait for ${direction === 'SELL' ? 'bearish' : 'bullish'} reversal candle at entry zone`
            },
            wickRejection: {
                required: true,
                direction: direction === 'SELL' ? 'UPPER_WICK' : 'LOWER_WICK',
                minSize: timeframe === '5m' ? 10 : 15, // Smaller for 5min
                description: `Strong ${direction === 'SELL' ? 'upper' : 'lower'} wick rejection required`
            },
            marketContext: {
                level: direction === 'SELL' ? 'SUPPLY_ZONE' : 'DEMAND_ZONE',
                levelPrice: aiSignal.entry,
                description: aiSignal.levelExplanation || aiSignal.marketContext || aiSignal.technicalAnalysis || 'Key level identified by AI',
                confluenceScore: aiSignal.confidence
            }
        };
    }

    /**
     * Helper: Delay function
     */
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

module.exports = new SignalRequester();
