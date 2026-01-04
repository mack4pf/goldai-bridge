require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { db } = require('./database/firebase');

const app = express();
const PORT = process.env.PORT || 3001;

// Force Master Mode
console.log('👑 Single VPS Master Mode Active');
console.log('   Identity: MASTER_VPS');

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Health Check
app.get('/', (req, res) => {
    res.json({
        status: 'online',
        system: 'Gold AI Auto-Trading Bridge',
        version: '2.0',
        timestamp: new Date().toISOString()
    });
});

// Debug Endpoint
app.get('/debug', (req, res) => {
    res.json({
        env: {
            port: process.env.PORT,
            renderUrl: process.env.RENDER_EXTERNAL_URL ? 'SET' : 'MISSING',
            botToken: process.env.BRIDGE_BOT_TOKEN ? 'SET' : 'MISSING',
            firebase: process.env.FIREBASE_PROJECT_ID ? 'SET' : 'MISSING'
        },
        bot: {
            webhookPath: require('./bot/bot').webhookPath || 'POLLING',
            connected: !!require('./bot/bot').bot
        }
    });
});

// Import Routes
const apiRoutes = require('./api/routes_advanced');
const userRoutes = require('./api/userRoutes');
const mt5Routes = require('./api/mt5Routes');
const adminRoutes = require('./api/adminRoutes');
const licenseRoutes = require('./api/licenseRoutes');

app.use('/api/v1', apiRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1/mt5', mt5Routes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/license', licenseRoutes);

// Initialize Bot
const botModule = require('./bot/bot');

// Add webhook endpoint if in production (Render)
if (process.env.RENDER_EXTERNAL_URL && botModule.webhookPath) {
    app.use(botModule.webhookPath, botModule.bot.webhookCallback());
    console.log(`📱 Telegram webhook registered at: ${botModule.webhookPath}`);
}

// Start Server
app.listen(PORT, () => {
    console.log(`🚀 Auto-Bridge Server running on port ${PORT}`);
    console.log(`📊 API Documentation: /docs/API.md`);
    console.log(`📡 Waiting for signals from Gold Mentor Pro...`);
});

// NOTE: Signal Scheduler removed - Mentor Pro PUSHES signals to Bridge
// The Bridge no longer pulls/requests signals

