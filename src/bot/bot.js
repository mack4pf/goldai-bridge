const { Telegraf } = require('telegraf');
const { db } = require('../database/firebase');

// You need to set BRIDGE_BOT_TOKEN in .env
const token = process.env.BRIDGE_BOT_TOKEN;
console.log('DEBUG: Loaded Bot Token:', token ? token.substring(0, 10) + '...' : 'UNDEFINED');
const bot = new Telegraf(token || 'YOUR_NEW_BOT_TOKEN');

// Middleware to get user from DB
bot.use(async (ctx, next) => {
    if (!ctx.from) return next();

    const userId = ctx.from.id.toString();
    // TODO: Fetch user from 'bridge_users' collection
    // ctx.user = ...
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

bot.launch();

console.log('🤖 Bridge Bot Started');

module.exports = bot;
