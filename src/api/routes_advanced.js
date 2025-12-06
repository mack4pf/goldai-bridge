const express = require('express');
const router = express.Router();
const { db } = require('../database/firebase');
const licenseService = require('../services/licenseService'); // Already an instance!
const SignalScorer = require('../services/signalScorer');
const DailyStatsManager = require('../services/dailyStatsManager');

// Initialize services that need db
const statsManager = new DailyStatsManager(db);

// ============================================================================
// MIDDLEWARE
// ============================================================================

// Validate EA License
const requireLicense = async (req, res, next) => {
    const licenseKey = req.headers['x-license-key'] || req.query.license;

    if (!licenseKey) {
        return res.status(401).json({ error: 'Missing License Key' });
    }

    const licenseCheck = await licenseService.checkLicense(licenseKey);

    if (!licenseCheck.valid) {
        return res.status(403).json({
            error: 'Invalid or Expired License',
            reason: licenseCheck.reason
        });
    }

    req.license = licenseCheck;
    req.userId = licenseCheck.userId;
    next();
};

// ============================================================================
// LICENSING ENDPOINTS
// ============================================================================

/**
 * POST /api/v1/license/activate
 */
router.post('/license/activate', async (req, res) => {
    try {
        const { userId, licenseKey } = req.body;

        if (!userId || !licenseKey) {
            return res.status(400).json({ error: 'Missing userId or licenseKey' });
        }

        const result = await licenseService.activateLicense(userId, licenseKey);

        res.json({
            success: true,
            ...result,
            message: result.isTestLicense
                ? '🧪 Test license activated (5 days)'
                : '✅ License activated (30 days)'
        });

    } catch (error) {
        console.error('Activate license error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * GET /api/v1/license/check
 */
router.get('/license/check', async (req, res) => {
    try {
        const licenseKey = req.query.license;

        if (!licenseKey) {
            return res.status(400).json({ error: 'Missing license key' });
        }

        const result = await licenseService.checkLicense(licenseKey);
        res.json(result);

    } catch (error) {
        console.error('Check license error:', error);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================================
// SIGNAL PROCESSING
// ============================================================================

/**
 * POST /api/v1/signals
 * Basic signal endpoint (for simple format from scheduler)
 */
router.post('/signals', async (req, res) => {
    try {
        const { symbol, type, entry, sl, tp, timeframe, confidence } = req.body;

        if (!symbol || !type || !entry) {
            return res.status(400).json({ error: 'Missing signal data' });
        }

        console.log(`⚡ Signal Received: ${type} ${symbol} @ ${entry} (${confidence}%)`);

        // Calculate simple quality score based on confidence
        const qualityScore = confidence || 50;
        const shouldMonitor = qualityScore >= 65;

        console.log(`   Quality: ${qualityScore}/100 | Monitor: ${shouldMonitor ? 'YES' : 'NO'}`);

        if (!shouldMonitor) {
            console.log(`   ⛔ Quality too low (< 65). Skipping.`);
            return res.json({
                success: true,
                message: 'Signal quality below threshold',
                qualityScore,
                distributed: 0
            });
        }

        // Save signal
        const signalRef = await db.collection('signals').add({
            symbol, type, entry, sl, tp, timeframe, confidence, qualityScore,
            createdAt: new Date(),
            status: 'active'
        });

        // Distribute to active users
        const licensesSnapshot = await db.collection('licenses')
            .where('status', '==', 'active')
            .get();

        let distributedCount = 0;
        const batch = db.batch();

        for (const licenseDoc of licensesSnapshot.docs) {
            const license = licenseDoc.data();

            // Check if license expired
            if (new Date() > license.expiresAt.toDate()) {
                batch.update(licenseDoc.ref, {
                    status: 'expired',
                    expiredAt: new Date()
                });
                continue;
            }

            // Add to watchlist
            const watchlistRef = db.collection('watchlist').doc();
            batch.set(watchlistRef, {
                userId: license.userId,
                signalId: signalRef.id,
                status: 'monitoring',
                addedAt: new Date(),
                signalData: {
                    symbol, type, entry, sl, tp, timeframe, confidence, qualityScore
                }
            });

            distributedCount++;
        }

        await batch.commit();

        console.log(`   ✅ Distributed to ${distributedCount} users`);

        res.json({
            success: true,
            signalId: signalRef.id,
            qualityScore,
            distributed: distributedCount
        });

    } catch (error) {
        console.error('Signal processing error:', error);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================================
// WATCHLIST
// ============================================================================

/**
 * GET /api/v1/watchlist
 */
router.get('/watchlist', requireLicense, async (req, res) => {
    try {
        const snapshot = await db.collection('watchlist')
            .where('userId', '==', req.userId)
            .where('status', '==', 'monitoring')
            .get();

        const watchlist = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));

        res.json({
            success: true,
            count: watchlist.length,
            watchlist
        });

    } catch (error) {
        console.error('Watchlist error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/v1/watchlist/update
 */
router.post('/watchlist/update', requireLicense, async (req, res) => {
    try {
        const { signalId, status, ticket } = req.body;

        const snapshot = await db.collection('watchlist')
            .where('userId', '==', req.userId)
            .where('signalId', '==', signalId)
            .limit(1)
            .get();

        if (snapshot.empty) {
            return res.status(404).json({ error: 'Setup not found' });
        }

        await snapshot.docs[0].ref.update({
            status,
            ticket,
            executedAt: new Date()
        });

        res.json({ success: true });

    } catch (error) {
        console.error('Watchlist update error:', error);
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
