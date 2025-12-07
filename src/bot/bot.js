const { Telegraf } = require('telegraf');
const { db } = require('../database/firebase');

// You need to set BRIDGE_BOT_TOKEN in .env
const token = process.env.BRIDGE_BOT_TOKEN;
if (!token || token === 'YOUR_NEW_BOT_TOKEN') {
    console.error('❌ CRITICAL: BRIDGE_BOT_TOKEN is missing or invalid!');
    console.error('   Please set BRIDGE_BOT_TOKEN in Render Environment Variables.');
}

console.log('DEBUG: Loaded Bot Token:', token ? token.substring(0, 10) + '...' : 'UNDEFINED');
const bot = new Telegraf(token || 'YOUR_NEW_BOT_TOKEN');

// Middleware to get user from DB
bot.use(async (ctx, next) => {
    if (!ctx.from) return next();
    return next();
});

bot.start((ctx) => {
    ctx.reply(
        `🤖 **Gold AI Auto-Bridge Setup**\n\n` +
        `Welcome! This bot connects your MT5 terminal to our signal system.\n\n` +
        `1. Type /connect to get your Bridge Token.\n` +
        `2. Install the EA on your MT5.\n` +
        `3. Paste the Token into the EA inputs.`
    );
});

bot.command('connect', async (ctx) => {
    try {
        const userId = ctx.from.id.toString();
        // Generate a simple token
        const bridgeToken = `BRIDGE-${userId}-${Date.now().toString(36)}`;

        // Save to DB
        await db.collection('bridge_users').doc(userId).set({
            telegramId: userId,
            username: ctx.from.username || 'User',
            bridgeToken: bridgeToken,
            riskMode: 'conservative', // Default
            balance: 0, // Will be updated by EA
            active: true,
            createdAt: new Date()
        }, { merge: true });

        ctx.reply(
            `🔑 **Your Bridge Token**\n\n` +
            `<code>${bridgeToken}</code>\n\n` +
            `⚠️ Keep this private! Paste it into the GoldAI Bridge EA settings.`,
            { parse_mode: 'HTML' }
        );
    } catch (error) {
        console.error('❌ Error in /connect command:', error);
        ctx.reply('❌ Error generating token. Please try again later.');
    }
});

bot.command('risk', (ctx) => {
    ctx.reply('🛡️ Choose your Risk Mode:', {
        reply_markup: {
            inline_keyboard: [
                [{ text: '🐢 Conservative (1%)', callback_data: 'risk_conservative' }],
                [{ text: '🚀 Aggressive (3%)', callback_data: 'risk_aggressive' }]
            ]
        }
    });
});

bot.action('risk_conservative', async (ctx) => {
    const userId = ctx.from.id.toString();
    await db.collection('bridge_users').doc(userId).update({ riskMode: 'conservative' });
    ctx.editMessageText('✅ Risk Mode set to: **Conservative** (1% per trade)', { parse_mode: 'Markdown' });
});

bot.action('risk_aggressive', async (ctx) => {
    const userId = ctx.from.id.toString();
    await db.collection('bridge_users').doc(userId).update({ riskMode: 'aggressive' });
    ctx.editMessageText('✅ Risk Mode set to: **Aggressive** (3% per trade)', { parse_mode: 'Markdown' });
});

// Use webhooks in production (Render), polling in development
if (process.env.RENDER_EXTERNAL_URL) {
    // Production: Use webhooks
    const webhookPath = '/telegram-webhook';
    const webhookUrl = `${process.env.RENDER_EXTERNAL_URL}${webhookPath}`;

    bot.telegram.setWebhook(webhookUrl).then(() => {
        console.log('🤖 Bridge Bot Started (Webhook Mode)');
        console.log(`   Webhook URL: ${webhookUrl}`);
    }).catch(err => {
        console.error('❌ Failed to set webhook:', err.message);
    });

    // Export webhook handler for server.js
    module.exports = { bot, webhookPath };
} else {
    // Development: Use polling
    bot.launch().then(() => {
        console.log('🤖 Bridge Bot Started (Polling Mode - Development)');
    }).catch(err => {
        console.error('❌ Bot launch failed:', err.message);
        console.log('⚠️  Continuing without bot...');
    });

    module.exports = { bot };
}
