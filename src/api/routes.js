const express = require('express');
const router = express.Router();
const { db } = require('../database/firebase');
const riskManager = require('../services/riskManager');

// Middleware to validate EA Token
const requireBridgeToken = async (req, res, next) => {
    const token = req.headers['x-bridge-token'] || req.query.token;

    if (!token) return res.status(401).json({ error: 'Missing Token' });

    // Find user by token
    const snapshot = await db.collection('bridge_users').where('bridgeToken', '==', token).limit(1).get();

    if (snapshot.empty) return res.status(403).json({ error: 'Invalid Token' });

    req.user = { id: snapshot.docs[0].id, ...snapshot.docs[0].data() };
    next();
};

// 1. RECEIVE SIGNAL (From your existing system)
// POST /api/v1/signals
router.post('/signals', async (req, res) => {
    try {
        const { symbol, type, entry, sl, tp, timeframe } = req.body;

        if (!symbol || !type || !entry) {
            return res.status(400).json({ error: 'Missing signal data' });
        }

        console.log(`⚡ New Signal Received: ${type} ${symbol} @ ${entry}`);

        // 1. Save Signal
        const signalRef = await db.collection('bridge_signals').add({
            symbol, type, entry, sl, tp, timeframe,
            createdAt: new Date(),
            status: 'active'
        });

        // 2. Distribute to Active Users
        const usersSnapshot = await db.collection('bridge_users').where('active', '==', true).get();

        let count = 0;
        const batch = db.batch();

        usersSnapshot.forEach(doc => {
            const user = doc.data();

            // Calculate Lot Size
            // Default balance 1000 if not reported yet
            const balance = user.balance || 1000;
            const slPips = Math.abs(entry - sl) * 10; // Approx for Gold

            const { lotSize } = riskManager.calculateLotSize(balance, user.riskMode, slPips);

            // Create Command for this user
            const commandRef = db.collection('bridge_commands').doc();
            batch.set(commandRef, {
                userId: doc.id,
                signalId: signalRef.id,
                type: 'OPEN_TRADE',
                data: {
                    symbol,
                    cmd: type === 'BUY' ? 0 : 1, // MT5: 0=Buy, 1=Sell
                    volume: lotSize,
                    sl,
                    tp
                },
                status: 'pending',
                createdAt: new Date()
            });
            count++;
        });

        await batch.commit();

        res.json({ success: true, distributedTo: count });

    } catch (error) {
        console.error('Signal Error:', error);
        res.status(500).json({ error: error.message });
    }
});

// 2. EA POLLING (EA asks "Do I have work?")
// GET /api/v1/commands?token=XYZ
router.get('/commands', requireBridgeToken, async (req, res) => {
    try {
        // Fetch pending commands for this user
        const snapshot = await db.collection('bridge_commands')
            .where('userId', '==', req.user.id)
            .where('status', '==', 'pending')
            .limit(1) // One at a time
            .get();

        if (snapshot.empty) {
            return res.json({ hasCommand: false });
        }

        const doc = snapshot.docs[0];

        // Mark as 'processing' so we don't send it again immediately
        await doc.ref.update({ status: 'processing', pickedUpAt: new Date() });

        res.json({
            hasCommand: true,
            commandId: doc.id,
            ...doc.data()
        });

    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 3. EA REPORTING (EA says "I did it!")
// POST /api/v1/execution
router.post('/execution', requireBridgeToken, async (req, res) => {
    try {
        const { commandId, success, ticket, error, balance } = req.body;

        if (commandId) {
            await db.collection('bridge_commands').doc(commandId).update({
                status: success ? 'completed' : 'failed',
                ticket: ticket || null,
                error: error || null,
                executedAt: new Date()
            });
        }

        // Update User Balance
        if (balance) {
            await db.collection('bridge_users').doc(req.user.id).update({
                balance: parseFloat(balance),
                lastSeen: new Date()
            });
        }

        res.json({ status: 'ok' });

    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
