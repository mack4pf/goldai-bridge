/**
 * Risk Management Service
 * Calculates position sizes based on user risk profile and account balance.
 */
class RiskManager {
    constructor() {
        this.RISK_PROFILES = {
            conservative: {
                riskPerTrade: 0.01, // 1%
                maxLotSize: 0.5,
                pyramiding: false
            },
            aggressive: {
                riskPerTrade: 0.03, // 3%
                maxLotSize: 5.0,
                pyramiding: true
            }
        };
    }

    /**
     * Calculate Lot Size
     * @param {number} balance - User's account balance
     * @param {string} mode - 'conservative' or 'aggressive'
     * @param {number} stopLossPips - Distance to SL in pips (approx)
     */
    calculateLotSize(balance, mode = 'conservative', stopLossPips = 50) {
        const profile = this.RISK_PROFILES[mode] || this.RISK_PROFILES.conservative;

        // Risk Amount in USD
        const riskAmount = balance * profile.riskPerTrade;

        // Standard Lot Value per Pip (approx $10 for XAUUSD)
        // Formula: Lot = Risk / (SL_Pips * Pip_Value)
        // Assuming 1 pip = $1 for 0.1 lot? No.
        // XAUUSD: 1 pip (0.10 move) = $10 on 1.0 lot.
        // So 1 pip = $10 * LotSize
        // Risk = SL_Pips * (10 * LotSize)
        // LotSize = Risk / (SL_Pips * 10)

        let lotSize = riskAmount / (stopLossPips * 10);

        // Round to 2 decimal places
        lotSize = Math.round(lotSize * 100) / 100;

        // Min/Max limits
        if (lotSize < 0.01) lotSize = 0.01;
        if (lotSize > profile.maxLotSize) lotSize = profile.maxLotSize;

        return {
            lotSize,
            riskAmount,
            mode
        };
    }
}

module.exports = new RiskManager();
