/**
 * Signal Quality Scorer
 * Evaluates signal quality based on confluence, confidence, and risk/reward
 */
class SignalScorer {
    /**
     * Calculate overall signal quality score (0-100)
     */
    static calculateScore(signal) {
        let totalScore = 0;
        const weights = {
            confidence: 0.30,      // 30%
            confluenceScore: 0.25, // 25%
            riskReward: 0.20,      // 20%
            rsiAlignment: 0.15,    // 15%
            marketContext: 0.10    // 10%
        };

        // 1. Confidence Score (0-100)
        const confidenceScore = signal.confidence || 0;
        totalScore += confidenceScore * weights.confidence;

        // 2. Confluence Score (from signal)
        const confluenceScore = signal.confluence?.marketContext?.confluenceScore || 0;
        totalScore += confluenceScore * weights.confluenceScore;

        // 3. Risk/Reward Ratio
        const rrRatio = this.calculateRiskReward(signal);
        const rrScore = Math.min(rrRatio * 20, 100); // 5:1 RR = 100 points
        totalScore += rrScore * weights.riskReward;

        // 4. RSI Alignment
        const rsiScore = this.evaluateRSI(signal);
        totalScore += rsiScore * weights.rsiAlignment;

        // 5. Market Context
        const contextScore = this.evaluateMarketContext(signal);
        totalScore += contextScore * weights.marketContext;

        return Math.round(totalScore);
    }

    /**
     * Calculate risk/reward ratio
     */
    static calculateRiskReward(signal) {
        try {
            const entry = signal.entry?.price;
            const sl = signal.stopLoss;
            const tp = signal.takeProfits?.[0]?.price;

            if (!entry || !sl || !tp) return 0;

            const risk = Math.abs(entry - sl);
            const reward = Math.abs(tp - entry);

            return reward / risk;
        } catch {
            return 0;
        }
    }

    /**
     * Evaluate RSI alignment
     */
    static evaluateRSI(signal) {
        try {
            const rsi = signal.confluence?.rsi;
            if (!rsi) return 50; // Neutral if no RSI

            const { currentValue, condition } = rsi;

            // Check if RSI is in optimal range
            if (signal.direction === 'SELL') {
                if (currentValue > 70) return 100; // Overbought - excellent
                if (currentValue > 60) return 80;  // Good
                if (currentValue > 50) return 60;  // Average
                return 30; // Poor
            } else { // BUY
                if (currentValue < 30) return 100; // Oversold - excellent
                if (currentValue < 40) return 80;  // Good
                if (currentValue < 50) return 60;  // Average
                return 30; // Poor
            }
        } catch {
            return 50;
        }
    }

    /**
     * Evaluate market context
     */
    static evaluateMarketContext(signal) {
        try {
            const context = signal.confluence?.marketContext;
            if (!context) return 50;

            let score = 50;

            // Strong level types
            const strongLevels = ['SUPPLY_ZONE', 'DEMAND_ZONE', 'KEY_RESISTANCE', 'KEY_SUPPORT'];
            if (strongLevels.includes(context.level)) {
                score += 30;
            }

            // Description quality (longer = more detailed)
            if (context.description?.length > 50) {
                score += 20;
            }

            return Math.min(score, 100);
        } catch {
            return 50;
        }
    }

    /**
     * Determine if signal should be added to watchlist
     * Changed threshold: >= 65 (not 70)
     */
    static shouldMonitor(signal) {
        const score = this.calculateScore(signal);
        return score >= 65; // Distribute signals with quality >= 65
    }
}

module.exports = SignalScorer;
