const MetaApi = require('metaapi.cloud-sdk');
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

            // Execute trade based on operation (ORDER_TYPE_BUY or ORDER_TYPE_SELL)
            // Use symbol and calculated lot size based on riskManager if needed
            // For now, we use a simple proportion or fixed lot
            const lotSize = tradeEvent.lotSize || 0.01;

            if (tradeEvent.operation === 'ORDER_TYPE_BUY') {
                await connection.createMarketBuyOrder(tradeEvent.symbol, lotSize, tradeEvent.sl, tradeEvent.tp);
            } else if (tradeEvent.operation === 'ORDER_TYPE_SELL') {
                await connection.createMarketSellOrder(tradeEvent.symbol, lotSize, tradeEvent.sl, tradeEvent.tp);
            } else if (tradeEvent.operation === 'ORDER_TYPE_CLOSE') {
                // Implement close logic (need to find ticket mapping)
                await connection.closePositionsBySymbol(tradeEvent.symbol);
            }

            console.log(`   ✅ Trade copied successfully to ${mt5Login}`);

            // Log to copier_stats
            await db.collection('copier_stats').add({
                userId: accountData.userId,
                mt5Login: mt5Login,
                symbol: tradeEvent.symbol,
                operation: tradeEvent.operation,
                status: 'success',
                timestamp: new Date()
            });

        } catch (error) {
            throw error;
        }
    }
}

module.exports = new CopierManager();
