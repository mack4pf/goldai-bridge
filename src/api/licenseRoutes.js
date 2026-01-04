const express = require('express');
const router = express.Router();
const licenseService = require('../services/licenseService');
const { db } = require('../database/firebase');

/**
 * GET /api/v1/license/check
 * Verify a license key for the EA
 */
router.get('/check', async (req, res) => {
    try {
        const { key, account } = req.query;

        if (!key) {
            return res.status(400).json({ error: 'License key is required' });
        }

        console.log(`🔍 EA License Check: ${key} (Account: ${account || 'Unknown'})`);

        const result = await licenseService.checkLicense(key);

        if (!result.valid) {
            return res.json({
                success: false,
                message: result.reason
            });
        }

        // If an account is provided, we can optionally link it or restrict it
        // For now, we trust the license key validity

        res.json({
            success: true,
            message: 'License is valid',
            expiresAt: result.expiresAt,
            daysRemaining: result.daysRemaining,
            isTest: result.isTestLicense
        });

    } catch (error) {
        console.error('API License check error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /api/v1/license/generate
 * Generate a new license key (Internal/Admin only)
 * Since this is called by the Bot Server, it should be protected or internal
 */
router.post('/generate', async (req, res) => {
    try {
        const { type } = req.body; // 'test' or 'regular'
        const isTest = type === 'test';

        // Generate a key
        let licenseKey;
        if (isTest) {
            const randomPart = Math.random().toString(36).substring(2, 8).toUpperCase();
            licenseKey = `GOLDAI-TEST-${randomPart}`;
        } else {
            licenseKey = licenseService.generateLicenseKey();
        }

        // We create an entry in the 'licenses' collection as 'inactive' or 'unused'
        // Actually, the current licenseService expects a userId to activate.
        // Let's modify the service or just handle it here for "Pre-generated" keys.

        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + (isTest ? 7 : 30));

        const licenseData = {
            licenseKey,
            status: 'active', // Direct activation for now as per user requirement
            isTestLicense: isTest,
            createdAt: new Date(),
            activatedAt: new Date(),
            expiresAt,
            lastChecked: new Date(),
            userId: 'PRE-GENERATED' // Placeholder until a user activates it in Bot
        };

        await db.collection('licenses').add(licenseData);

        // Also add to access_codes for the Telegram bot
        await db.collection('access_codes').add({
            code: licenseKey,
            status: 'unused',
            type: isTest ? 'test' : 'regular',
            createdAt: new Date(),
            expiresAt: expiresAt
        });

        res.json({
            success: true,
            licenseKey,
            expiresAt: expiresAt.toISOString(),
            type: isTest ? 'test' : 'regular'
        });

    } catch (error) {
        console.error('API License generation error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
