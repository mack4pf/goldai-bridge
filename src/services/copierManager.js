const MetaApi = require('metaapi.cloud-sdk').default;
const { db } = require('../database/firebase');

class CopierManager {
    constructor() {
        this.token = process.env.META_API_TOKEN;
        this.api = null;
        if (this.token) {
            this.api = new MetaApi(this.token);
        }
    }

    /**
     * Handle incoming trade event from Master EA (VPS)
     * @param {Object} tradeEvent { symbol, type, operation, price, sl, tp, ticket }
     */
    async handleMasterTrade(tradeEvent) {
        console.log(`📡 MASTER TRADE DETECTED: ${tradeEvent.operation} ${tradeEvent.symbol} @ ${tradeEvent.price}`);

        // 1. Fetch all active users who have connected their MT5 account
        const userAccounts = await this.getActiveCopierAccounts();
        console.log(`   Found ${userAccounts.length} active copier accounts.`);

        // 2. Broadcast to each account
        for (const account of userAccounts) {
            try {
                await this.copyToAccount(account, tradeEvent);
            } catch (error) {
                console.error(`   ❌ Failed to copy to account ${account.mt5Login}:`, error.message);
            }
        }
    }

    /**
     * Fetch active copier accounts from Firestore
     */
    async getActiveCopierAccounts() {
        try {
            const snapshot = await db.collection('copier_accounts')
                .where('status', '==', 'active')
                .where('autoTradingEnabled', '==', true)
                .get();

            return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        } catch (error) {
            console.error('Error fetching copier accounts:', error);
            return [];
        }
    }

    /**
     * Copy a specific trade to a MetaApi account
     */
    async copyToAccount(accountData, tradeEvent) {
        if (!this.api) {
            console.warn('   ⚠️ MetaApi Token missing. Skipping execution.');
            return;
        }

        const { metaApiId, mt5Login } = accountData;
        console.log(`   🚀 Copying to ${mt5Login} (MetaApi ID: ${metaApiId})...`);

        try {
            const connection = await this.api.metatraderAccountApi.getAccount(metaApiId);

            // Wait for connection to be ready (simplified for now)
            await connection.waitConnected();

            // Determine if we are opening or closing
            if (tradeEvent.operation === 'OPEN') {
                const lotSize = tradeEvent.lotSize || 0.01;

                if (tradeEvent.type === 'BUY') {
                    await connection.createMarketBuyOrder(tradeEvent.symbol, lotSize, tradeEvent.sl, tradeEvent.tp);
                } else if (tradeEvent.type === 'SELL') {
                    await connection.createMarketSellOrder(tradeEvent.symbol, lotSize, tradeEvent.sl, tradeEvent.tp);
                }
                console.log(`   ✅ Trade OPENED successfully on ${mt5Login}`);
            }
            else if (tradeEvent.operation.includes('CLOSE')) {
                // For partial or full close, we close by symbol for now 
                // In a multi-trade scenario, we would need to map tickets
                if (tradeEvent.operation.includes('PARTIAL')) {
                    // MetaApi partial close: find the position and close a portion
                    // For now, closing by symbol handles the most common case
                    await connection.closePositionsBySymbol(tradeEvent.symbol);
                } else {
                    await connection.closePositionsBySymbol(tradeEvent.symbol);
                }
                console.log(`   ✅ Trade CLOSED successfully on ${mt5Login}`);
            }

            // Log to copier_stats
            await db.collection('copier_stats').add({
                userId: accountData.userId,
                mt5Login: mt5Login,
                symbol: tradeEvent.symbol,
                operation: tradeEvent.operation,
                type: tradeEvent.type,
                lotSize: tradeEvent.lotSize,
                status: 'success',
                timestamp: new Date()
            });

        } catch (error) {
            throw error;
        }
    }
}

module.exports = new CopierManager();
