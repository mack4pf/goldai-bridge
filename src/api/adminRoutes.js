const express = require('express');
const router = express.Router();
const { db } = require('../database/firebase');
const admin = require('firebase-admin');
const crypto = require('crypto');

// Admin credentials
const ADMIN_EMAIL = 'mackiyeritufu@gmail.com';

// ============================================================================
// ADMIN ACCESS CODE MANAGEMENT
// ============================================================================

/**
 * POST /api/v1/admin/access-codes/generate
 * Generate new access code
 */
router.post('/access-codes/generate', verifyAdminToken, async (req, res) => {
    try {
        const { count = 1, expiryDays = 30 } = req.body;

        const codes = [];

        for (let i = 0; i < count; i++) {
            // Generate unique code: GOLD-YYYY-XXXXXX
            const year = new Date().getFullYear();
            const randomPart = crypto.randomBytes(3).toString('hex').toUpperCase();
            const code = `GOLD-${year}-${randomPart}`;

            // Store in Firestore
            await db.collection('access_codes').add({
                code,
                status: 'unused',
                createdBy: req.user.email,
                createdAt: new Date(),
                expiresAt: new Date(Date.now() + expiryDays * 24 * 60 * 60 * 1000),
                usedBy: null,
                usedAt: null
            });

            codes.push(code);
        }

        console.log(`✅ Admin ${req.user.email} generated ${count} access code(s)`);

        res.json({
            success: true,
            message: `Generated ${count} access code(s)`,
            codes
        });

    } catch (error) {
        console.error('Generate access code error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * GET /api/v1/admin/access-codes
 * Get all access codes
 */
router.get('/access-codes', verifyAdminToken, async (req, res) => {
    try {
        const { status, limit = 100 } = req.query;

        let query = db.collection('access_codes')
            .orderBy('createdAt', 'desc')
            .limit(parseInt(limit));

        if (status) {
            query = query.where('status', '==', status);
        }

        const snapshot = await query.get();

        const codes = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
            createdAt: doc.data().createdAt?.toDate(),
            expiresAt: doc.data().expiresAt?.toDate(),
            usedAt: doc.data().usedAt?.toDate()
        }));

        res.json({
            success: true,
            count: codes.length,
            codes
        });

    } catch (error) {
        console.error('Get access codes error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/v1/admin/access-codes/:code/deactivate
 * Deactivate an access code
 */
router.post('/access-codes/:code/deactivate', verifyAdminToken, async (req, res) => {
    try {
        const { code } = req.params;

        const snapshot = await db.collection('access_codes')
            .where('code', '==', code)
            .limit(1)
            .get();

        if (snapshot.empty) {
            return res.status(404).json({ error: 'Access code not found' });
        }

        await snapshot.docs[0].ref.update({
            status: 'deactivated',
            deactivatedBy: req.user.email,
            deactivatedAt: new Date()
        });

        console.log(`✅ Admin ${req.user.email} deactivated code: ${code}`);

        res.json({
            success: true,
            message: 'Access code deactivated'
        });

    } catch (error) {
        console.error('Deactivate access code error:', error);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================================
// ADMIN USER MANAGEMENT
// ============================================================================

/**
 * GET /api/v1/admin/users
 * Get all users with stats
 */
router.get('/users', verifyAdminToken, async (req, res) => {
    try {
        const { limit = 100, status } = req.query;

        let query = db.collection('users')
            .orderBy('createdAt', 'desc')
            .limit(parseInt(limit));

        if (status) {
            query = query.where('status', '==', status);
        }

        const snapshot = await query.get();

        const users = [];

        for (const doc of snapshot.docs) {
            const userData = doc.data();

            // Get MT5 connection status
            const mt5Snapshot = await db.collection('copier_accounts')
                .where('userId', '==', doc.id)
                .where('status', '==', 'active')
                .limit(1)
                .get();

            const mt5Connected = !mt5Snapshot.empty;
            let mt5Data = null;

            if (mt5Connected) {
                const mt5Doc = mt5Snapshot.docs[0].data();
                mt5Data = {
                    brokerServer: mt5Doc.brokerServer,
                    mt5Login: mt5Doc.mt5Login,
                    balance: mt5Doc.balance,
                    equity: mt5Doc.equity
                };
            }

            // Get trade stats
            const statsSnapshot = await db.collection('copier_stats')
                .where('userId', '==', doc.id)
                .get();

            const totalTrades = statsSnapshot.size;
            const successfulTrades = statsSnapshot.docs.filter(d => d.data().status === 'success').length;

            users.push({
                userId: doc.id,
                email: userData.email,
                username: userData.username,
                status: userData.status,
                accessCode: userData.accessCode,
                createdAt: userData.createdAt?.toDate(),
                subscription: userData.subscription,
                mt5Connected,
                mt5Data,
                stats: {
                    totalTrades,
                    successfulTrades,
                    failedTrades: totalTrades - successfulTrades
                }
            });
        }

        res.json({
            success: true,
            count: users.length,
            users
        });

    } catch (error) {
        console.error('Get users error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/v1/admin/users/:userId/suspend
 * Suspend a user
 */
router.post('/users/:userId/suspend', verifyAdminToken, async (req, res) => {
    try {
        const { userId } = req.params;
        const { reason } = req.body;

        const userDoc = await db.collection('users').doc(userId).get();

        if (!userDoc.exists) {
            return res.status(404).json({ error: 'User not found' });
        }

        await userDoc.ref.update({
            status: 'suspended',
            suspendedBy: req.user.email,
            suspendedAt: new Date(),
            suspensionReason: reason || 'No reason provided'
        });

        // Disable MT5 auto-trading
        const mt5Snapshot = await db.collection('copier_accounts')
            .where('userId', '==', userId)
            .where('status', '==', 'active')
            .get();

        for (const doc of mt5Snapshot.docs) {
            await doc.ref.update({
                autoTradingEnabled: false
            });
        }

        console.log(`✅ Admin ${req.user.email} suspended user: ${userId}`);

        res.json({
            success: true,
            message: 'User suspended successfully'
        });

    } catch (error) {
        console.error('Suspend user error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/v1/admin/users/:userId/activate
 * Activate a suspended user
 */
router.post('/users/:userId/activate', verifyAdminToken, async (req, res) => {
    try {
        const { userId } = req.params;

        const userDoc = await db.collection('users').doc(userId).get();

        if (!userDoc.exists) {
            return res.status(404).json({ error: 'User not found' });
        }

        await userDoc.ref.update({
            status: 'active',
            activatedBy: req.user.email,
            activatedAt: new Date()
        });

        // Re-enable MT5 auto-trading
        const mt5Snapshot = await db.collection('copier_accounts')
            .where('userId', '==', userId)
            .where('status', '==', 'active')
            .get();

        for (const doc of mt5Snapshot.docs) {
            await doc.ref.update({
                autoTradingEnabled: true
            });
        }

        console.log(`✅ Admin ${req.user.email} activated user: ${userId}`);

        res.json({
            success: true,
            message: 'User activated successfully'
        });

    } catch (error) {
        console.error('Activate user error:', error);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================================
// ADMIN SYSTEM STATS
// ============================================================================

/**
 * GET /api/v1/admin/stats
 * Get system-wide statistics
 */
router.get('/stats', verifyAdminToken, async (req, res) => {
    try {
        // Total users
        const usersSnapshot = await db.collection('users').get();
        const totalUsers = usersSnapshot.size;
        const activeUsers = usersSnapshot.docs.filter(d => d.data().status === 'active').length;

        // Total MT5 connections
        const mt5Snapshot = await db.collection('copier_accounts')
            .where('status', '==', 'active')
            .get();
        const totalMT5Connections = mt5Snapshot.size;

        // Total trades copied today
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const todayTradesSnapshot = await db.collection('copier_stats')
            .where('copiedAt', '>=', today)
            .get();
        const tradesToday = todayTradesSnapshot.size;
        const successfulTradesToday = todayTradesSnapshot.docs.filter(d => d.data().status === 'success').length;

        // Access codes
        const codesSnapshot = await db.collection('access_codes').get();
        const totalCodes = codesSnapshot.size;
        const unusedCodes = codesSnapshot.docs.filter(d => d.data().status === 'unused').length;

        res.json({
            success: true,
            stats: {
                users: {
                    total: totalUsers,
                    active: activeUsers,
                    suspended: totalUsers - activeUsers
                },
                mt5: {
                    totalConnections: totalMT5Connections
                },
                trades: {
                    today: tradesToday,
                    successfulToday: successfulTradesToday,
                    failedToday: tradesToday - successfulTradesToday
                },
                accessCodes: {
                    total: totalCodes,
                    unused: unusedCodes,
                    used: totalCodes - unusedCodes
                }
            }
        });

    } catch (error) {
        console.error('Get stats error:', error);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================================
// ADMIN SYSTEM CONFIG
// ============================================================================

/**
 * GET /api/v1/admin/config
 * Get system configuration
 */
router.get('/config', verifyAdminToken, async (req, res) => {
    try {
        const doc = await db.collection('system_settings').doc('global_config').get();
        if (!doc.exists) {
            const defaultConfig = {
                broadcastEnabled: true,
                updatedAt: new Date()
            };
            await db.collection('system_settings').doc('global_config').set(defaultConfig);
            return res.json({ success: true, config: defaultConfig });
        }

        const data = doc.data();
        res.json({
            success: true,
            config: {
                ...data,
                updatedAt: data.updatedAt?.toDate()
            }
        });
    } catch (error) {
        console.error('Get config error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/v1/admin/config
 * Update system configuration
 */
router.post('/config', verifyAdminToken, async (req, res) => {
    try {
        const { broadcastEnabled } = req.body;

        await db.collection('system_settings').doc('global_config').set({
            broadcastEnabled,
            updatedAt: new Date()
        }, { merge: true });

        console.log(`✅ Admin ${req.user.email} updated config: broadcastEnabled=${broadcastEnabled}`);

        res.json({ success: true, message: 'Configuration updated' });
    } catch (error) {
        console.error('Update config error:', error);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================================
// MIDDLEWARE
// ============================================================================

/**
 * Verify admin token
 */
async function verifyAdminToken(req, res, next) {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Missing or invalid authorization header' });
        }

        const token = authHeader.split('Bearer ')[1];
        const decodedToken = await admin.auth().verifyIdToken(token);

        // Check if user is admin
        if (decodedToken.email !== ADMIN_EMAIL) {
            return res.status(403).json({ error: 'Admin access required' });
        }

        req.user = decodedToken;
        next();

    } catch (error) {
        console.error('Admin token verification error:', error);
        res.status(401).json({ error: 'Invalid or expired token' });
    }
}

module.exports = router;
