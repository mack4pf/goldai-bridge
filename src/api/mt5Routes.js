const express = require('express');
const router = express.Router();
const { db } = require('../database/firebase');
const admin = require('firebase-admin');
const MetaApi = require('metaapi.cloud-sdk').default;

// Initialize MetaApi
const metaApiToken = process.env.META_API_TOKEN;
let metaApi = null;

if (metaApiToken) {
    metaApi = new MetaApi(metaApiToken);
    console.log('✅ MetaApi initialized');
} else {
    console.warn('⚠️  META_API_TOKEN not set - MT5 connection will not work');
}

// ============================================================================
// MT5 ACCOUNT CONNECTION
// ============================================================================

/**
 * POST /api/v1/mt5/connect
 * Connect user's MT5 account via MetaApi
 */
router.post('/connect', verifyToken, async (req, res) => {
    try {
        const { brokerServer, mt5Login, mt5Password } = req.body;

        if (!brokerServer || !mt5Login || !mt5Password) {
            return res.status(400).json({ error: 'Missing MT5 credentials' });
        }

        if (!metaApi) {
            return res.status(500).json({ error: 'MetaApi not configured. Contact admin.' });
        }

        console.log(`📡 Connecting MT5 account for user ${req.user.uid}...`);
        console.log(`   Broker: ${brokerServer}`);
        console.log(`   Login: ${mt5Login}`);

        // Check if user already has a connected account
        const existingSnapshot = await db.collection('copier_accounts')
            .where('userId', '==', req.user.uid)
            .where('status', '==', 'active')
            .limit(1)
            .get();

        if (!existingSnapshot.empty) {
            return res.status(400).json({
                error: 'You already have a connected MT5 account. Disconnect it first.'
            });
        }

        // Create MetaApi account
        const account = await metaApi.metatraderAccountApi.createAccount({
            name: `User-${req.user.uid}-${mt5Login}`,
            type: 'cloud',
            login: mt5Login,
            password: mt5Password,
            server: brokerServer,
            platform: 'mt5',
            magic: 999888,
            application: 'MetaApi',
            tags: ['goldai', 'copier', req.user.uid]
        });

        console.log(`   MetaApi Account Created: ${account.id}`);

        // Deploy account
        console.log(`   Deploying account...`);
        await account.deploy();

        try {
            console.log(`   Waiting for account deployment...`);
            await account.waitDeployed(60000);

            // Wait for connection (with timeout)
            const connectionTimeout = 60000; // 60 seconds
            console.log(`   Waiting for broker connection...`);
            await account.waitConnected(1, connectionTimeout);
            console.log(`   ✅ Account connected successfully`);

            // Get account information
            try {
                const connection = account.getRPCConnection();
                await connection.connect();
                await connection.waitSynchronized();
                accountInfo = await connection.getAccountInformation();
                console.log(`   Balance: $${accountInfo.balance}`);
                console.log(`   Equity: $${accountInfo.equity}`);
            } catch (error) {
                console.warn(`   Could not fetch account info via RPC:`, error.message);
            }
        } catch (error) {
            console.error(`   ⚠️  Deployment or Connection failed:`, error.message);
            // We still store it in Firestore as 'pending' or 'failed' if needed, 
            // but for now let's stop the process for this request so the user knows it failed.
            return res.status(400).json({
                error: `Connection failed: ${error.message}. Please check your credentials and broker server.`
            });
        }

        // Store in Firestore
        const copierAccountRef = await db.collection('copier_accounts').add({
            userId: req.user.uid,
            metaApiId: account.id,
            brokerServer,
            mt5Login,
            status: 'active',
            balance: accountInfo?.balance || 0,
            equity: accountInfo?.equity || 0,
            connectedAt: new Date(),
            lastSyncAt: new Date(),
            autoTradingEnabled: true
        });

        // Update user document
        await db.collection('users').doc(req.user.uid).update({
            mt5Connected: true,
            mt5ConnectedAt: new Date()
        });

        res.json({
            success: true,
            message: 'MT5 account connected successfully',
            account: {
                id: copierAccountRef.id,
                metaApiId: account.id,
                brokerServer,
                mt5Login,
                balance: accountInfo?.balance || 0,
                equity: accountInfo?.equity || 0,
                status: 'active'
            }
        });

    } catch (error) {
        console.error('MT5 connection error:', error);

        // Handle specific MetaApi errors
        if (error.message.includes('E_AUTH')) {
            return res.status(400).json({ error: 'Invalid MT5 credentials. Please check your login and password.' });
        }

        if (error.message.includes('E_SERVER_TIMEZONE')) {
            return res.status(400).json({ error: 'Invalid broker server. Please check the server name.' });
        }

        res.status(500).json({ error: error.message });
    }
});

/**
 * GET /api/v1/mt5/status
 * Get MT5 account status and balance
 */
router.get('/status', verifyToken, async (req, res) => {
    try {
        const snapshot = await db.collection('copier_accounts')
            .where('userId', '==', req.user.uid)
            .where('status', '==', 'active')
            .limit(1)
            .get();

        if (snapshot.empty) {
            return res.json({
                success: true,
                connected: false,
                message: 'No MT5 account connected'
            });
        }

        const accountData = snapshot.docs[0].data();

        // Try to get live account info from MetaApi
        let liveInfo = null;
        if (metaApi && accountData.metaApiId) {
            try {
                const account = await metaApi.metatraderAccountApi.getAccount(accountData.metaApiId);
                const connection = account.getRPCConnection();

                if (connection.healthStatus.synchronized) {
                    const accountInfo = await connection.getAccountInformation();
                    const positions = await connection.getPositions();

                    liveInfo = {
                        balance: accountInfo.balance,
                        equity: accountInfo.equity,
                        margin: accountInfo.margin,
                        freeMargin: accountInfo.freeMargin,
                        openPositions: positions.length,
                        profit: accountInfo.profit
                    };

                    // Update Firestore with latest info
                    await snapshot.docs[0].ref.update({
                        balance: accountInfo.balance,
                        equity: accountInfo.equity,
                        lastSyncAt: new Date()
                    });
                }
            } catch (error) {
                console.warn('Could not fetch live MT5 data:', error.message);
            }
        }

        res.json({
            success: true,
            connected: true,
            account: {
                brokerServer: accountData.brokerServer,
                mt5Login: accountData.mt5Login,
                balance: liveInfo?.balance || accountData.balance,
                equity: liveInfo?.equity || accountData.equity,
                openPositions: liveInfo?.openPositions || 0,
                profit: liveInfo?.profit || 0,
                connectedAt: accountData.connectedAt,
                lastSyncAt: accountData.lastSyncAt,
                autoTradingEnabled: accountData.autoTradingEnabled
            }
        });

    } catch (error) {
        console.error('MT5 status error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/v1/mt5/disconnect
 * Disconnect MT5 account
 */
router.post('/disconnect', verifyToken, async (req, res) => {
    try {
        const snapshot = await db.collection('copier_accounts')
            .where('userId', '==', req.user.uid)
            .where('status', '==', 'active')
            .limit(1)
            .get();

        if (snapshot.empty) {
            return res.status(404).json({ error: 'No active MT5 account found' });
        }

        const accountDoc = snapshot.docs[0];
        const accountData = accountDoc.data();

        // Undeploy MetaApi account
        if (metaApi && accountData.metaApiId) {
            try {
                const account = await metaApi.metatraderAccountApi.getAccount(accountData.metaApiId);
                await account.undeploy();
                console.log(`✅ MetaApi account ${accountData.metaApiId} undeployed`);
            } catch (error) {
                console.warn('Could not undeploy MetaApi account:', error.message);
            }
        }

        // Update status in Firestore
        await accountDoc.ref.update({
            status: 'disconnected',
            disconnectedAt: new Date()
        });

        // Update user document
        await db.collection('users').doc(req.user.uid).update({
            mt5Connected: false
        });

        res.json({
            success: true,
            message: 'MT5 account disconnected successfully'
        });

    } catch (error) {
        console.error('MT5 disconnect error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * GET /api/v1/mt5/trades
 * Get trade history for user's MT5 account
 */
router.get('/trades', verifyToken, async (req, res) => {
    try {
        const { limit = 30 } = req.query;

        // Get copier stats for this user
        const statsSnapshot = await db.collection('copier_stats')
            .where('userId', '==', req.user.uid)
            .orderBy('copiedAt', 'desc')
            .limit(parseInt(limit))
            .get();

        const trades = statsSnapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));

        res.json({
            success: true,
            count: trades.length,
            trades
        });

    } catch (error) {
        console.error('MT5 trades error:', error);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================================
// MIDDLEWARE
// ============================================================================

/**
 * Verify Firebase Auth token
 */
async function verifyToken(req, res, next) {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Missing or invalid authorization header' });
        }

        const token = authHeader.split('Bearer ')[1];
        const decodedToken = await admin.auth().verifyIdToken(token);

        req.user = decodedToken;
        next();

    } catch (error) {
        console.error('Token verification error:', error);
        res.status(401).json({ error: 'Invalid or expired token' });
    }
}

module.exports = router;
