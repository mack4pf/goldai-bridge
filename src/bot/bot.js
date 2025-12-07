const { Telegraf, Markup } = require('telegraf');
const { db } = require('../database/firebase');
const licenseService = require('../services/licenseService');

const token = process.env.BRIDGE_BOT_TOKEN;
if (!token) {
    console.error('❌ BRIDGE_BOT_TOKEN not set in .env');
    process.exit(1); // Exit if no token
}

const bot = new Telegraf(token);

// Admin ID from environment
const ADMIN_ID = process.env.ADMIN_TELEGRAM_ID;

// Keyboards
const mainMenu = Markup.keyboard([
    ['📊 My Stats', '📡 My Watchlist'],
    ['🔑 My License', '❓ Help']
]).resize();

const adminMenu = Markup.keyboard([
    ['👑 Create License', '📋 List Licenses'],
    ['📊 User Stats', '⬅️ Main Menu']
]).resize();

// Middleware - Track user sessions
bot.use(async (ctx, next) => {
    if (!ctx.from) return next();
    ctx.userId = ctx.from.id.toString();
    return next();
});

// --- ADMIN AUTHENTICATION ---
function isAdmin(ctx) {
    return ctx.from.id.toString() === ADMIN_ID;
}

// --- START COMMAND ---
bot.start(async (ctx) => {
    const isAdminUser = isAdmin(ctx);

    if (isAdminUser) {
        ctx.reply(
            `👑 **Gold AI Bridge - ADMIN PANEL**\n\n` +
            `Welcome Admin! You can create and manage licenses.\n\n` +
            `Use the admin menu below:`,
            { parse_mode: 'Markdown', ...adminMenu }
        );
    } else {
        ctx.reply(
            `🤖 **Gold AI Auto-Trading Bridge**\n\n` +
            `Welcome! Connect your MT5 EA with your license key.\n\n` +
            `**First time?**\n` +
            `Use /activate YOUR_LICENSE_KEY\n\n` +
            `Example: /activate GOLDAI-TEST-XXXX`,
            { parse_mode: 'Markdown', ...mainMenu }
        );
    }
});

// --- ACTIVATION COMMAND ---
bot.command('activate', async (ctx) => {
    const args = ctx.message.text.split(' ');

    if (args.length < 2) {
        return ctx.reply(
            `⚠️ **Usage:**\n` +
            `/activate YOUR_LICENSE_KEY\n\n` +
            `Example: /activate GOLDAI-TEST-XXXX`,
            { parse_mode: 'Markdown' }
        );
    }

    const licenseKey = args[1];
    const userId = ctx.userId;

    try {
        // Save telegram username for admin reference
        const username = ctx.from.username || null;

        // Activate license
        const result = await licenseService.activateLicense(userId, licenseKey);

        // Update with telegram info
        await db.collection('licenses').doc(result.licenseId).update({
            telegramUsername: username,
            telegramId: userId
        });

        ctx.reply(
            `✅ **License Activated!**\n\n` +
            `License: \`${licenseKey}\`\n` +
            `Expires: ${new Date(result.expiresAt).toLocaleDateString()}\n` +
            `Days Remaining: **${result.daysRemaining}**\n\n` +
            `🎯 **Next Steps:**\n` +
            `1. Open MT5\n` +
            `2. Attach GoldAI EA to XAUUSD chart\n` +
            `3. Settings:\n` +
            `   • API_URL = YOUR_BRIDGE_URL\n` +
            `   • License_Key = \`${licenseKey}\`\n\n` +
            `Your EA will now receive signals!`,
            { parse_mode: 'Markdown', ...mainMenu }
        );

    } catch (error) {
        ctx.reply(
            `❌ **Activation Failed**\n\n` +
            `${error.message}\n\n` +
            `Please check your license key.`,
            { parse_mode: 'Markdown' }
        );
    }
});

// --- USER: MY LICENSE ---
bot.hears('🔑 My License', async (ctx) => {
    try {
        const status = await licenseService.checkLicenseByUserId(ctx.userId);

        if (!status.active) {
            return ctx.reply(
                `❌ **No Active License**\n\n` +
                `Use /activate YOUR_LICENSE_KEY to activate.`,
                { parse_mode: 'Markdown' }
            );
        }

        ctx.reply(
            `🔑 **Your License**\n\n` +
            `License: \`${status.licenseKey}\`\n` +
            `Type: ${status.isTestLicense ? 'Test (5 days)' : 'Monthly (30 days)'}\n` +
            `Expires: ${new Date(status.expiresAt).toLocaleDateString()}\n` +
            `Days Remaining: **${status.daysRemaining}**\n` +
            `Status: ${status.daysRemaining > 0 ? '✅ Active' : '❌ Expired'}`,
            { parse_mode: 'Markdown' }
        );

    } catch (error) {
        ctx.reply('❌ Error checking license. Use /activate first.');
    }
});

// --- USER: MY STATS ---
bot.hears('📊 My Stats', async (ctx) => {
    try {
        // Check if user has license
        const licenseStatus = await licenseService.checkLicenseByUserId(ctx.userId);

        if (!licenseStatus.active) {
            return ctx.reply('❌ Please activate your license first with /activate');
        }

        // Get daily stats
        const statsSnapshot = await db.collection('daily_stats')
            .where('userId', '==', ctx.userId)
            .orderBy('date', 'desc')
            .limit(1)
            .get();

        if (statsSnapshot.empty) {
            return ctx.reply(
                `📊 **No Trading Activity Yet**\n\n` +
                `Your EA will update stats when it starts trading.`,
                { parse_mode: 'Markdown' }
            );
        }

        const stats = statsSnapshot.docs[0].data();

        ctx.reply(
            `📊 **Today's Stats**\n\n` +
            `Balance: $${stats.balance?.toFixed(2) || '0.00'}\n` +
            `Profit: $${stats.totalProfit?.toFixed(2) || '0.00'}\n` +
            `Loss: $${stats.totalLoss?.toFixed(2) || '0.00'}\n` +
            `Net P/L: $${((stats.totalProfit || 0) - (stats.totalLoss || 0)).toFixed(2)}\n\n` +
            `Trades: ${stats.totalTrades || 0}\n` +
            `Win Rate: ${stats.totalTrades > 0 ? ((stats.winningTrades / stats.totalTrades) * 100).toFixed(1) : 0}%\n\n` +
            `Status: ${stats.status || 'active'}`,
            { parse_mode: 'Markdown' }
        );

    } catch (error) {
        console.error('Stats error:', error);
        ctx.reply('❌ Error fetching stats. Make sure your EA is running.');
    }
});

// --- USER: MY WATCHLIST ---
bot.hears('📡 My Watchlist', async (ctx) => {
    try {
        const licenseStatus = await licenseService.checkLicenseByUserId(ctx.userId);

        if (!licenseStatus.active) {
            return ctx.reply('❌ Please activate your license first with /activate');
        }

        const watchlistSnapshot = await db.collection('watchlist')
            .where('userId', '==', ctx.userId)
            .where('status', '==', 'monitoring')
            .get();

        if (watchlistSnapshot.empty) {
            return ctx.reply(
                `📭 **No Active Signals**\n\n` +
                `Your EA is waiting for high-quality signals.\n` +
                `Signals are distributed every hour.`,
                { parse_mode: 'Markdown' }
            );
        }

        let message = `📡 **Active Watchlist** (${watchlistSnapshot.size})\n\n`;

        watchlistSnapshot.forEach(doc => {
            const signal = doc.data();
            message += `🔹 **${signal.direction} @ ${signal.entry?.price}**\n`;
            message += `   SL: ${signal.stopLoss} | TP1: ${signal.takeProfits?.[0]?.price}\n`;
            message += `   Timeframe: ${signal.timeframe}\n`;
            message += `   Added: ${new Date(signal.addedAt).toLocaleTimeString()}\n\n`;
        });

        ctx.reply(message, { parse_mode: 'Markdown' });

    } catch (error) {
        console.error('Watchlist error:', error);
        ctx.reply('❌ Error fetching watchlist.');
    }
});

// --- ADMIN: LIST LICENSES ---
bot.hears('📋 List Licenses', async (ctx) => {
    if (!isAdmin(ctx)) {
        return ctx.reply('❌ Admin access required');
    }

    try {
        const licensesSnapshot = await db.collection('licenses')
            .orderBy('activatedAt', 'desc')
            .limit(20)
            .get();

        if (licensesSnapshot.empty) {
            return ctx.reply('📋 No licenses found.');
        }

        let message = `📋 **Active Licenses** (${licensesSnapshot.size})\n\n`;

        licensesSnapshot.forEach(doc => {
            const lic = doc.data();
            const daysLeft = Math.ceil((new Date(lic.expiresAt) - new Date()) / (1000 * 60 * 60 * 24));
            const status = daysLeft > 0 ? '✅' : '❌';

            message += `${status} \`${lic.licenseKey}\`\n`;
            message += `   User: ${lic.userId}\n`;
            message += `   Expires: ${new Date(lic.expiresAt).toLocaleDateString()}\n`;
            message += `   Days Left: ${daysLeft}\n\n`;
        });

        ctx.reply(message, { parse_mode: 'Markdown' });

    } catch (error) {
        console.error('List licenses error:', error);
        ctx.reply('❌ Error listing licenses');
    }
});

// --- ADMIN: USER STATS ---
bot.hears('📊 User Stats', async (ctx) => {
    if (!isAdmin(ctx)) {
        return ctx.reply('❌ Admin access required');
    }

    try {
        // Get all users with licenses
        const licensesSnapshot = await db.collection('licenses')
            .where('active', '==', true)
            .get();

        if (licensesSnapshot.empty) {
            return ctx.reply('📊 No active users found.');
        }

        let message = `📊 **User Statistics**\n\n`;

        for (const doc of licensesSnapshot.docs) {
            const lic = doc.data();

            // Get user's daily stats
            const statsSnapshot = await db.collection('daily_stats')
                .where('userId', '==', lic.userId)
                .orderBy('date', 'desc')
                .limit(1)
                .get();

            const stats = statsSnapshot.empty ? null : statsSnapshot.docs[0].data();

            message += `👤 **User:** \`${lic.userId}\`\n`;
            if (lic.telegramUsername) {
                message += `   @${lic.telegramUsername}\n`;
            }
            message += `   License: \`${lic.licenseKey}\`\n`;

            if (stats) {
                message += `   Balance: $${stats.balance?.toFixed(2) || '0.00'}\n`;
                message += `   P/L: $${((stats.totalProfit || 0) - (stats.totalLoss || 0)).toFixed(2)}\n`;
                message += `   Trades: ${stats.totalTrades || 0}\n`;
            } else {
                message += `   No trading activity yet\n`;
            }
            message += `\n`;
        }

        ctx.reply(message, { parse_mode: 'Markdown' });

    } catch (error) {
        console.error('User stats error:', error);
        ctx.reply('❌ Error fetching user stats');
    }
});

// --- ADMIN: CREATE LICENSE ---
bot.hears('👑 Create License', async (ctx) => {
    if (!isAdmin(ctx)) {
        return ctx.reply('❌ Admin access required');
    }

    ctx.reply(
        `👑 **Create License**\n\n` +
        `Choose license type:`,
        {
            parse_mode: 'Markdown',
            reply_markup: {
                inline_keyboard: [
                    [{ text: '🧪 Test License (5 days)', callback_data: 'admin_create_test' }],
                    [{ text: '💎 Monthly License (30 days)', callback_data: 'admin_create_monthly' }]
                ]
            }
        }
    );
});

bot.action('admin_create_test', async (ctx) => {
    if (!isAdmin(ctx)) return;

    // Generate unique test key: GOLDAI-TEST-<RANDOM>
    const randomPart = Math.random().toString(36).substr(2, 6).toUpperCase();
    const licenseKey = `GOLDAI-TEST-${randomPart}`;

    ctx.editMessageText(
        `✅ **Test License Created**\n\n` +
        `License Key: \`${licenseKey}\`\n` +
        `Validity: 5 days\n` +
        `Reactivation: Unlimited\n\n` +
        `Give this key to users for testing.`,
        { parse_mode: 'Markdown' }
    );
});

bot.action('admin_create_monthly', async (ctx) => {
    if (!isAdmin(ctx)) return;

    // Generate unique monthly license
    const licenseKey = `GOLDAI-${Date.now().toString(36).toUpperCase()}`;

    ctx.editMessageText(
        `✅ **Monthly License Created**\n\n` +
        `License Key: \`${licenseKey}\`\n` +
        `Validity: 30 days from activation\n\n` +
        `⚠️ **Important:**\n` +
        `User must activate with: /activate ${licenseKey}`,
        { parse_mode: 'Markdown' }
    );
});

// --- HELP ---
bot.hears('❓ Help', (ctx) => {
    ctx.reply(
        `📚 **Gold AI Bridge Help**\n\n` +
        `**For Users:**\n` +
        `/activate KEY - Activate your license\n` +
        `📊 My Stats - View trading stats\n` +
        `📡 My Watchlist - See active signals\n` +
        `🔑 My License - Check license status\n\n` +
        `**Setup EA:**\n` +
        `1. Get license key from admin\n` +
        `2. /activate YOUR_KEY in this bot\n` +
        `3. Configure EA with same key\n` +
        `4. EA will auto-trade signals\n\n` +
        `Support: @GoldAISupport`,
        { parse_mode: 'Markdown' }
    );
});

bot.hears('⬅️ Main Menu', (ctx) => {
    if (isAdmin(ctx)) {
        ctx.reply('👑 Admin Menu', adminMenu);
    } else {
        ctx.reply('🤖 Main Menu', mainMenu);
    }
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
        console.log(`   Admin ID: ${ADMIN_ID || 'NOT SET'}`);
    }).catch(err => {
        console.error('❌ Bot launch failed:', err.message);
        console.log('⚠️  Continuing without bot...');
    });

    module.exports = { bot };
}

// Graceful stop
process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));
