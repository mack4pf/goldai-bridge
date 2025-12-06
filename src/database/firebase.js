const admin = require('firebase-admin');
const serviceAccount = require('../../serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

console.log('🔥 Firebase Initialized for Auto-Bridge');

module.exports = { db };
