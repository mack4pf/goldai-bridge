/**
 * Daily Stats Manager
 * Manages daily profit/loss tracking and limits
 */
class DailyStatsManager {
    constructor(db) {
        this.db = db;
    }

    /**
     * Get or create daily stats for a user
     */
    async getDailyStats(userId) {
        try {
            const today = this.getTodayString();

            const snapshot = await this.db.collection('daily_stats')
                .where('userId', '==', userId)
                .where('date', '==', today)
                .limit(1)
                .get();

            if (!snapshot.empty) {
                return {
                    id: snapshot.docs[0].id,
                    ...snapshot.docs[0].data()
                };
            }

            // Create new daily stats
            // Get user's current balance
            const userDoc = await this.db.collection('bridge_users').doc(userId).get();
            const balance = userDoc.data()?.balance || 1000;

            const newStats = {
                userId,
                date: today,
                startBalance: balance,
                currentBalance: balance,

                profitToday: 0,
                lossToday: 0,
                profitTarget: balance * 0.15, // 15% default
                maxLoss: balance * 0.08,      // 8% default

                tradesExecuted: 0,
                tradesWon: 0,
                tradesLost: 0,

                status: 'active',
                createdAt: new Date(),
                lastUpdated: new Date()
            };

            const statsRef = await this.db.collection('daily_stats').add(newStats);

            return {
                id: statsRef.id,
                ...newStats
            };

        } catch (error) {
            console.error('Get daily stats error:', error);
            throw error;
        }
    }

    /**
     * Update daily stats with trade result
     */
    async updateStats(userId, tradeProfit, newBalance) {
        try {
            const stats = await this.getDailyStats(userId);

            const updates = {
                currentBalance: newBalance,
                lastUpdated: new Date(),
                tradesExecuted: stats.tradesExecuted + 1
            };

            if (tradeProfit > 0) {
                updates.profitToday = stats.profitToday + tradeProfit;
                updates.tradesWon = stats.tradesWon + 1;
            } else {
                updates.lossToday = stats.lossToday + Math.abs(tradeProfit);
                updates.tradesLost = stats.tradesLost + 1;
            }

            // Check limits
            if (updates.profitToday >= stats.profitTarget) {
                updates.status = 'profit_hit';
                console.log(`🎯 Profit target hit for user ${userId}! ${updates.profitToday.toFixed(2)}`);
            } else if (updates.lossToday >= stats.maxLoss) {
                updates.status = 'loss_hit';
                console.log(`🛑 Max loss hit for user ${userId}! ${updates.lossToday.toFixed(2)}`);
            }

            await this.db.collection('daily_stats').doc(stats.id).update(updates);

            return {
                ...stats,
                ...updates
            };

        } catch (error) {
            console.error('Update stats error:', error);
            throw error;
        }
    }

    /**
     * Check if user can trade today
     */
    async canTrade(userId) {
        try {
            const stats = await this.getDailyStats(userId);

            return {
                canTrade: stats.status === 'active',
                status: stats.status,
                profitToday: stats.profitToday,
                lossToday: stats.lossToday,
                profitTarget: stats.profitTarget,
                maxLoss: stats.maxLoss,
                remainingProfit: Math.max(0, stats.profitTarget - stats.profitToday),
                remainingLoss: Math.max(0, stats.maxLoss - stats.lossToday)
            };

        } catch (error) {
            console.error('Can trade check error:', error);
            throw error;
        }
    }

    /**
     * Reset daily stats (called at start of new day)
     */
    async resetDailyStats(userId) {
        try {
            const yesterday = this.getYesterdayString();

            // Archive yesterday's stats
            const yesterdaySnapshot = await this.db.collection('daily_stats')
                .where('userId', '==', userId)
                .where('date', '==', yesterday)
                .limit(1)
                .get();

            if (!yesterdaySnapshot.empty) {
                const yesterdayStats = yesterdaySnapshot.docs[0].data();

                // Update user's balance for compound growth
                await this.db.collection('bridge_users').doc(userId).update({
                    balance: yesterdayStats.currentBalance,
                    lastBalanceUpdate: new Date()
                });

                console.log(`📊 Reset daily stats for ${userId}. New balance: ${yesterdayStats.currentBalance}`);
            }

            // Create new stats for today (will be created on next getDailyStats call)
            return { success: true };

        } catch (error) {
            console.error('Reset daily stats error:', error);
            throw error;
        }
    }

    /**
     * Helper: Get today's date string (YYYY-MM-DD)
     */
    getTodayString() {
        const now = new Date();
        return now.toISOString().split('T')[0];
    }

    /**
     * Helper: Get yesterday's date string (YYYY-MM-DD)
     */
    getYesterdayString() {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        return yesterday.toISOString().split('T')[0];
    }
}

module.exports = DailyStatsManager;
