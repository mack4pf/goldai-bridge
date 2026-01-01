/**
 * Firebase Setup Script
 * Creates initial data for testing
 */

require('dotenv').config();
const { db } = require('./src/database/firebase');
const crypto = require('crypto');

async function setupFirebase() {
    console.log('\n' + '='.repeat(80));
    console.log('🔥 FIREBASE SETUP SCRIPT');
    console.log('='.repeat(80) + '\n');

    try {
        // 1. Create test access codes
        console.log('📝 Creating test access codes...');

        const accessCodes = [
            'GOLD-2024-TEST123',
            'GOLD-2024-DEMO456',
            'GOLD-2024-TRIAL789'
        ];

        for (const code of accessCodes) {
            // Check if already exists
            const existing = await db.collection('access_codes')
                .where('code', '==', code)
                .limit(1)
                .get();

            if (existing.empty) {
                await db.collection('access_codes').add({
                    code,
                    status: 'unused',
                    createdBy: 'setup-script',
                    createdAt: new Date(),
                    expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
                    usedBy: null,
                    usedAt: null
                });
                console.log(`   ✅ Created: ${code}`);
            } else {
                console.log(`   ⏭️  Already exists: ${code}`);
            }
        }

        // 2. Create sample watchlist signal (for Master EA testing)
        console.log('\n📡 Creating sample watchlist signal...');

        const sampleSignal = {
            userId: 'MASTER_VPS',
            signalId: `SIG_${Date.now()}`,
            status: 'monitoring',
            addedAt: new Date(),
            signalData: {
                symbol: 'XAUUSD',
                type: 'BUY',
                entry: 2650.50,
                sl: 2645.00,
                tp: 2655.50,
                timeframe: '15m',
                confidence: 85,
                qualityScore: 85
            }
        };

        await db.collection('watchlist').add(sampleSignal);
        console.log('   ✅ Sample signal created for Master EA');

        // 3. Display summary
        console.log('\n' + '='.repeat(80));
        console.log('✅ FIREBASE SETUP COMPLETE');
        console.log('='.repeat(80));

        console.log('\n📋 Access Codes Created:');
        accessCodes.forEach(code => {
            console.log(`   • ${code}`);
        });

        console.log('\n📡 Sample Signal Created:');
        console.log(`   • Type: ${sampleSignal.signalData.type}`);
        console.log(`   • Entry: ${sampleSignal.signalData.entry}`);
        console.log(`   • SL: ${sampleSignal.signalData.sl}`);
        console.log(`   • TP: ${sampleSignal.signalData.tp}`);

        console.log('\n🎯 Next Steps:');
        console.log('   1. Run: node test_complete_platform.js');
        console.log('   2. Use access code: GOLD-2024-TEST123');
        console.log('   3. Test user registration');
        console.log('   4. Setup MetaApi for MT5 connections');

        console.log('');

    } catch (error) {
        console.error('\n❌ Setup failed:', error.message);
        console.error(error);
    }

    process.exit(0);
}

setupFirebase();
