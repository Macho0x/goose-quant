// One-step lognormal caplet from the market-model test.
// checkForwardsAndOptionlets prices it with BlackCalculator:
// displaced call, stdDev = vol * sqrt(expiry), discount * accrual.
// Displacement is the test's displacement. Flat vol, so vol is the
// Black volatility and the accrual is the caplet year fraction.
//
// one_step is LogNormalFwdRatePc on that first rate alone, in the
// terminal measure. The payment bond is the numeraire, so the drift
// calculator's sum is an empty range and both predictor-corrector
// drifts are zero. The step is log(F+d) plus -1/2 variance plus one
// inverse-normal draw. Accounting then multiplies the cash amount by
// today's payment discount: the numeraire bond count is 1.

import math;
import black;
import normal;
import mt;

namespace lmm;

fn caplet(forward: f64, strike: f64, vol: f64, expiry: f64, discount: f64, accrual: f64, displacement: f64) -> f64, bool {
    if vol < 0.0 || expiry < 0.0 || accrual < 0.0 || discount <= 0.0 { return 0.0, false; }
    let std_dev = vol * sqrt(expiry);
    return black::black(black::CALL, strike, forward, std_dev, discount * accrual, displacement);
}

fn error_estimate(sx: f64, sxx: f64, n: i64) -> f64 {
    var v = (sxx - sx * sx / n) / (n - 1.0);
    if v < 0.0 { v = 0.0; }
    return sqrt(v / n);
}

fn one_step(forward: f64, forward_strike: f64, vol: f64, expiry: f64, discount: f64, accrual: f64, displacement: f64, seed: i64, paths: i64) -> f64, f64, f64, f64, bool {
    if vol < 0.0 || expiry < 0.0 || accrual < 0.0 || discount <= 0.0 { return 0.0, 0.0, 0.0, 0.0, false; }
    if forward + displacement <= 0.0 { return 0.0, 0.0, 0.0, 0.0, false; }
    if seed <= 0 || seed > 4294967295 || paths < 2 { return 0.0, 0.0, 0.0, 0.0, false; }
    let variance = vol * vol * expiry;
    let shock = sqrt(variance);
    let fixed = -0.5 * variance;
    let log0 = log(forward + displacement);
    let scale = accrual * discount;
    var g = default<mt::Twister>();
    mt::seed(g, seed as u32);
    var sum_fwd = 0.0;
    var sumsq_fwd = 0.0;
    var sum_call = 0.0;
    var sumsq_call = 0.0;
    var i: i64 = 0;
    while i < paths {
        let z, ok = normal::inv_cdf(mt::next_real(g));
        if !ok { return 0.0, 0.0, 0.0, 0.0, false; }
        let rate = exp(log0 + fixed + shock * z) - displacement;
        let fwd = (rate - forward_strike) * scale;
        var call = rate - forward;
        if call < 0.0 { call = 0.0; }
        call = call * scale;
        sum_fwd += fwd;
        sumsq_fwd += fwd * fwd;
        sum_call += call;
        sumsq_call += call * call;
        i += 1;
    }
    let mean_fwd = sum_fwd / paths;
    let err_fwd = error_estimate(sum_fwd, sumsq_fwd, paths);
    let mean_call = sum_call / paths;
    let err_call = error_estimate(sum_call, sumsq_call, paths);
    if is_nan(mean_fwd) || is_inf(mean_fwd) || is_nan(err_fwd) || is_inf(err_fwd) { return 0.0, 0.0, 0.0, 0.0, false; }
    if is_nan(mean_call) || is_inf(mean_call) || is_nan(err_call) || is_inf(err_call) { return 0.0, 0.0, 0.0, 0.0, false; }
    return mean_fwd, err_fwd, mean_call, err_call, true;
}
