const express = require('express');
const copierManager = require('../services/copierManager');
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

// ============================================================================
// MIDDLEWARE
// ============================================================================

// Middleware to force Master VPS identity
const forceMasterUser = (req, res, next) => {
    req.userId = 'MASTER_VPS';
    next();
};

// Middleware to validate Bridge Token
const validateBridgeToken = (req, res, next) => {
    const token = req.headers['x-bridge-token'];
    const MASTER_TOKEN = process.env.BRIDGE_TOKEN || 'MASTER_EA_TOKEN';

    if (token !== MASTER_TOKEN) {
        console.warn(`⚠️ Unauthorized EA Access Attempt: Invalid Token Provided`);
        return res.status(401).json({ error: 'Unauthorized: Invalid Bridge Token' });
    }
    next();
};

// ============================================================================
// SIGNAL PROCESSING
// ============================================================================

/**
 * POST /api/v1/signals
 * Basic signal endpoint (for simple format from scheduler)
 */
router.post('/signals', async (req, res) => {
    try {
        const { symbol, type, entry, sl, tp, tp2, tp3, tp4, timeframe, confidence } = req.body;

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
            symbol, type, entry, sl, tp, tp2, tp3, tp4, timeframe, confidence, qualityScore,
            createdAt: new Date(),
            status: 'active'
        });

        // Distribute to MASTER_VPS only (Single VPS Mode)
        const watchlistRef = db.collection('watchlist').doc();
        await watchlistRef.set({
            userId: 'MASTER_VPS',
            signalId: signalRef.id,
            status: 'monitoring',
            addedAt: new Date(),
            signalData: {
                symbol, type, entry, sl, tp, tp2, tp3, tp4, timeframe, confidence, qualityScore
            }
        });

        const distributedCount = 1;

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
/**
 * GET /api/v1/watchlist
 */
router.get('/watchlist', forceMasterUser, async (req, res) => {
    try {
        const snapshot = await db.collection('watchlist')
            .where('userId', '==', req.userId)
            .where('status', '==', 'monitoring')
            .get();

        const watchlist = snapshot.docs.map(doc => {
            const data = doc.data();
            return {
                signalId: data.signalId,
                symbol: data.signalData.symbol,
                type: data.signalData.type,
                entry: data.signalData.entry,
                sl: data.signalData.sl,
                tp: data.signalData.tp,
                tp2: data.signalData.tp2,
                tp3: data.signalData.tp3,
                tp4: data.signalData.tp4,
                confidence: data.signalData.confidence,
                grade: data.signalData.grade || 'A'
            };
        });

        // The EA expects a single object if signals are available, or a "count: 0" response
        if (watchlist.length > 0) {
            res.json({
                success: true,
                ...watchlist[0] // Send the first active signal for the EA to process
            });
        } else {
            res.json({
                success: true,
                count: 0,
                message: 'No active signals'
            });
        }

    } catch (error) {
        console.error('Watchlist error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/v1/watchlist/update
 */
router.post('/watchlist/update', forceMasterUser, async (req, res) => {
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

        const updateData = {
            status,
            executedAt: new Date()
        };

        if (ticket !== undefined) {
            updateData.ticket = ticket;
        }

        await snapshot.docs[0].ref.update(updateData);

        res.json({ success: true });

    } catch (error) {
        console.error('Watchlist update error:', error);
        res.status(500).json({ error: error.message });
    }
});


// --- CLOUD COPIER ROUTES ---

/**
 * Endpoint for Master EA (VPS) to broadcast trade events
 */
router.post('/copier/master/trade', async (req, res) => {
    try {
        const tradeEvent = req.body;

        if (!tradeEvent || !tradeEvent.symbol || !tradeEvent.operation) {
            return res.status(400).json({ error: 'Missing trade event data' });
        }

        // Handle the trade asynchronously to avoid blocking the Master EA
        copierManager.handleMasterTrade(tradeEvent).catch(err => {
            console.error('Async copier error:', err);
        });

        res.json({ success: true, message: 'Trade event broadcasted' });
    } catch (error) {
        console.error('Copier route error:', error);
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
