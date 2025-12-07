const admin = require('firebase-admin');

// Use environment variables for production (Render) or local file for development
let serviceAccount;

if (process.env.FIREBASE_PROJECT_ID) {
    // Production: Use environment variables
    serviceAccount = {
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n')
    };
} else {
    // Development: Use local file
    serviceAccount = require('../../serviceAccountKey.json');
}

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

console.log('🔥 Firebase Initialized for Auto-Bridge');

module.exports = { db };
