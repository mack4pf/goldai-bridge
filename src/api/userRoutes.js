const express = require('express');
const router = express.Router();
const { db } = require('../database/firebase');
const admin = require('firebase-admin');

// ============================================================================
// USER REGISTRATION & AUTHENTICATION
// ============================================================================

/**
 * POST /api/v1/users/register
 * Register new user with access code
 */
router.post('/register', async (req, res) => {
    try {
        const { accessCode, email, password, username } = req.body;

        if (!accessCode || !email || !password) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        // Validate access code
        const codeSnapshot = await db.collection('access_codes')
            .where('code', '==', accessCode)
            .where('status', '==', 'unused')
            .limit(1)
            .get();

        if (codeSnapshot.empty) {
            return res.status(400).json({ error: 'Invalid or already used access code' });
        }

        const codeDoc = codeSnapshot.docs[0];
        const codeData = codeDoc.data();

        // Check if code is expired (30 days from creation)
        const codeAge = (new Date() - codeData.createdAt.toDate()) / (1000 * 60 * 60 * 24);
        if (codeAge > 30) {
            return res.status(400).json({ error: 'Access code has expired' });
        }

        // Create Firebase Auth user
        const userRecord = await admin.auth().createUser({
            email,
            password,
            displayName: username || email.split('@')[0]
        });

        // Create user document in Firestore
        await db.collection('users').doc(userRecord.uid).set({
            userId: userRecord.uid,
            email,
            username: username || email.split('@')[0],
            accessCode,
            createdAt: new Date(),
            status: 'active',
            subscription: {
                plan: 'monthly',
                startedAt: new Date(),
                expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
            },
            mt5Connected: false
        });

        // Mark access code as used
        await codeDoc.ref.update({
            status: 'used',
            usedBy: email,
            usedAt: new Date()
        });

        // Generate custom token for immediate login
        const customToken = await admin.auth().createCustomToken(userRecord.uid);

        res.json({
            success: true,
            message: 'Registration successful',
            userId: userRecord.uid,
            token: customToken
        });

    } catch (error) {
        console.error('Registration error:', error);

        if (error.code === 'auth/email-already-exists') {
            return res.status(400).json({ error: 'Email already registered' });
        }

        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/v1/users/login
 * Login user (handled by Firebase Auth on frontend)
 * This endpoint is for custom token generation if needed
 */
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ error: 'Missing email or password' });
        }

        // Note: Password verification is handled by Firebase Auth on frontend
        // This endpoint can be used for additional server-side logic if needed

        res.json({
            success: true,
            message: 'Use Firebase Auth signInWithEmailAndPassword on frontend'
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * GET /api/v1/users/profile
 * Get user profile
 */
router.get('/profile', verifyToken, async (req, res) => {
    try {
        const userDoc = await db.collection('users').doc(req.user.uid).get();

        if (!userDoc.exists) {
            return res.status(404).json({ error: 'User not found' });
        }

        const userData = userDoc.data();

        // Check if user has connected MT5 account
        const mt5Snapshot = await db.collection('copier_accounts')
            .where('userId', '==', req.user.uid)
            .where('status', '==', 'active')
            .limit(1)
            .get();

        const mt5Connected = !mt5Snapshot.empty;
        let mt5Account = null;

        if (mt5Connected) {
            const mt5Data = mt5Snapshot.docs[0].data();
            mt5Account = {
                brokerServer: mt5Data.brokerServer,
                mt5Login: mt5Data.mt5Login,
                balance: mt5Data.balance || 0,
                equity: mt5Data.equity || 0,
                connectedAt: mt5Data.connectedAt
            };
        }

        res.json({
            success: true,
            user: {
                userId: userData.userId,
                email: userData.email,
                username: userData.username,
                status: userData.status,
                subscription: userData.subscription,
                mt5Connected,
                mt5Account,
                createdAt: userData.createdAt
            }
        });

    } catch (error) {
        console.error('Profile error:', error);
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
