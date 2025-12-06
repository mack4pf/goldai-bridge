/**
 * License Management Service
 * Handles monthly licenses and 5-day test licenses
 */
const crypto = require('crypto');

class LicenseService {
    constructor(db) {
        this.db = db;

        // Test license key (always valid for 5 days from activation)
        this.TEST_LICENSE_KEY = 'GOLDAI-TEST-2024';
    }

    /**
     * Generate a unique license key
     */
    generateLicenseKey() {
        const prefix = 'GOLDAI';
        const segments = [];

        for (let i = 0; i < 3; i++) {
            const segment = crypto.randomBytes(2).toString('hex').toUpperCase();
            segments.push(segment);
        }

        return `${prefix}-${segments.join('-')}`;
    }

    /**
     * Activate a license for a user
     */
    async activateLicense(userId, licenseKey) {
        try {
            const isTestLicense = licenseKey === this.TEST_LICENSE_KEY;
            const daysValid = isTestLicense ? 5 : 30;

            const activatedAt = new Date();
            const expiresAt = new Date();
            expiresAt.setDate(expiresAt.getDate() + daysValid);

            // Check if license already exists
            const licenseSnapshot = await this.db.collection('licenses')
                .where('userId', '==', userId)
                .where('status', '==', 'active')
                .get();

            if (!licenseSnapshot.empty) {
                // Update existing license
                const licenseDoc = licenseSnapshot.docs[0];
                await licenseDoc.ref.update({
                    licenseKey,
                    activatedAt,
                    expiresAt,
                    isTestLicense,
                    lastChecked: activatedAt
                });

                return {
                    success: true,
                    licenseId: licenseDoc.id,
                    expiresAt: expiresAt.toISOString(),
                    daysRemaining: daysValid,
                    isTestLicense
                };
            }

            // Create new license
            const licenseRef = await this.db.collection('licenses').add({
                userId,
                licenseKey,
                activatedAt,
                expiresAt,
                status: 'active',
                isTestLicense,
                lastChecked: activatedAt
            });

            console.log(`✅ License activated for user ${userId}: ${licenseKey} (${daysValid} days)`);

            return {
                success: true,
                licenseId: licenseRef.id,
                expiresAt: expiresAt.toISOString(),
                daysRemaining: daysValid,
                isTestLicense
            };

        } catch (error) {
            console.error('License activation error:', error);
            throw error;
        }
    }

    /**
     * Check if a license is valid
     */
    async checkLicense(licenseKey) {
        try {
            const snapshot = await this.db.collection('licenses')
                .where('licenseKey', '==', licenseKey)
                .where('status', '==', 'active')
                .limit(1)
                .get();

            if (snapshot.empty) {
                return {
                    valid: false,
                    reason: 'License not found or inactive'
                };
            }

            const licenseData = snapshot.docs[0].data();
            const now = new Date();
            const expiresAt = licenseData.expiresAt.toDate();

            // Check expiration
            if (now > expiresAt) {
                // Expire the license
                await snapshot.docs[0].ref.update({
                    status: 'expired',
                    expiredAt: now
                });

                return {
                    valid: false,
                    reason: 'License expired',
                    expiredAt: expiresAt.toISOString()
                };
            }

            // Update last checked
            await snapshot.docs[0].ref.update({
                lastChecked: now
            });

            // Calculate days remaining
            const daysRemaining = Math.ceil((expiresAt - now) / (1000 * 60 * 60 * 24));

            return {
                valid: true,
                userId: licenseData.userId,
                expiresAt: expiresAt.toISOString(),
                daysRemaining,
                isTestLicense: licenseData.isTestLicense || false
            };

        } catch (error) {
            console.error('License check error:', error);
            throw error;
        }
    }

    /**
     * Get license status for a user
     */
    async getUserLicense(userId) {
        try {
            const snapshot = await this.db.collection('licenses')
                .where('userId', '==', userId)
                .where('status', '==', 'active')
                .limit(1)
                .get();

            if (snapshot.empty) {
                return { hasLicense: false };
            }

            const licenseData = snapshot.docs[0].data();
            const now = new Date();
            const expiresAt = licenseData.expiresAt.toDate();

            // Check if expired
            if (now > expiresAt) {
                await snapshot.docs[0].ref.update({
                    status: 'expired',
                    expiredAt: now
                });

                return { hasLicense: false, reason: 'expired' };
            }

            const daysRemaining = Math.ceil((expiresAt - now) / (1000 * 60 * 60 * 24));

            return {
                hasLicense: true,
                licenseKey: licenseData.licenseKey,
                expiresAt: expiresAt.toISOString(),
                daysRemaining,
                isTestLicense: licenseData.isTestLicense || false
            };

        } catch (error) {
            console.error('Get user license error:', error);
            throw error;
        }
    }

    /**
     * Deactivate a license
     */
    async deactivateLicense(userId) {
        try {
            const snapshot = await this.db.collection('licenses')
                .where('userId', '==', userId)
                .where('status', '==', 'active')
                .get();

            const batch = this.db.batch();
            snapshot.forEach(doc => {
                batch.update(doc.ref, {
                    status: 'deactivated',
                    deactivatedAt: new Date()
                });
            });

            await batch.commit();

            console.log(`🛑 License deactivated for user ${userId}`);

            return { success: true };

        } catch (error) {
            console.error('License deactivation error:', error);
            throw error;
        }
    }
}

const { db } = require('../database/firebase');
module.exports = new LicenseService(db);

