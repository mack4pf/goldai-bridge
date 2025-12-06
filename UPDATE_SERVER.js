// ===================================================================
// INSTRUCTIONS: Add these lines to src/server.js in Bridge API
// ===================================================================

// After the line "require('./bot/bot');" (around line 45), add:

// Start Hourly Signal Scheduler
const signalScheduler = require('./schedulers/signalScheduler');
signalScheduler.start();

// ===================================================================
// That's it! Save and restart the server.
// ===================================================================
