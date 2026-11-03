// One-step lognormal caplet from the market-model test.
// checkForwardsAndOptionlets prices it with BlackCalculator:
// displaced call, stdDev = vol * sqrt(expiry), discount * accrual.
// Displacement is the test's displacement. Flat vol, so vol is the
// Black volatility and the accrual is the caplet year fraction.

import math;
import black;

namespace lmm;

fn caplet(forward: f64, strike: f64, vol: f64, expiry: f64, discount: f64, accrual: f64, displacement: f64) -> f64, bool {
    if vol < 0.0 || expiry < 0.0 || accrual < 0.0 || discount <= 0.0 { return 0.0, false; }
    let std_dev = vol * sqrt(expiry);
    return black::black(black::CALL, strike, forward, std_dev, discount * accrual, displacement);
}
