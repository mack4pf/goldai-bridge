require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { db } = require('./database/firebase');

const app = express();
const PORT = process.env.PORT || 3001; // Different port from main app (3000)

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Enhanced Health Check
app.get('/', (req, res) => {
    res.json({
        status: 'online',
        system: 'Gold AI Auto-Trading Bridge',
        version: '2.0',
        features: [
            'Monthly Licensing (30 days)',
            'Test License (5 days) - Key: GOLDAI-TEST-2024',
            'Advanced Signal Processing',
            'Watchlist Management',
            'Daily Profit/Loss Tracking',
            'Signal Quality Scoring'
        ],
        endpoints: {
            licensing: '/api/v1/license/*',
            signals: '/api/v1/signals/advanced',
            watchlist: '/api/v1/watchlist',
            stats: '/api/v1/stats/daily'
        },
        timestamp: new Date().toISOString()
    });
});

// Import Routes
const apiRoutes = require('./api/routes_advanced'); // Use advanced routes with license system
app.use('/api/v1', apiRoutes);

// Start Server
app.listen(PORT, () => {
    console.log(`🚀 Auto-Bridge Server running on port ${PORT}`);
    console.log(`📋 Test License: GOLDAI-TEST-2024 (5 days validity)`);
    console.log(`📊 API Documentation: /docs/API.md`);
});

// Initialize Bot
require('./bot/bot');

// Start Hourly Signal Scheduler
const signalScheduler = require('./schedulers/signalScheduler');
signalScheduler.start();
