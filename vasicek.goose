// European equity option under Black equity volatility and Vasicek rates.
// AnalyticBlackVasicekEngine. The total variance is the closed form of the
// engine's integrand, the one the stochastic-rate test compares against.
// The discount is the Vasicek zero bond P(0, t, r0).

import math;
import black;

namespace vasicek;

fn phi_and_h(x: f64) -> f64, f64 {
    var ax = x;
    if ax < 0.0 { ax = -ax; }
    if ax < 1.0 {
        var p = 1.0 / 6.0;
        var two_power = 8.0;
        var phi = 0.0;
        var h = 0.0;
        var k: i64 = 0;
        while k < 40 {
            let h_term = (two_power - 4.0) * p;
            phi += (k + 3.0) * p;
            h += h_term;
            var abs_term = h_term;
            if abs_term < 0.0 { abs_term = -abs_term; }
            var abs_h = h;
            if abs_h < 0.0 { abs_h = -abs_h; }
            if abs_term <= 2.2204460492503131e-16 * abs_h { return phi, h; }
            p *= -x / (k + 4.0);
            two_power *= 2.0;
            k += 1;
        }
        return phi, h;
    }
    let e1 = exp(-x) - 1.0;
    let e2 = exp(-2.0 * x) - 1.0;
    let phi = (e1 + x) / (x * x);
    let h = (4.0 * e1 - e2 + 2.0 * x) / (x * x * x);
    return phi, h;
}

fn zero_bond(t: f64, r0: f64, a: f64, b: f64, sigma: f64, lam: f64) -> f64 {
    let phi, h = phi_and_h(a * t);
    let sigma2 = sigma * sigma;
    let aa = exp(-(a * b + lam * sigma) * t * t * phi + 0.25 * sigma2 * t * t * t * h);
    let x = a * t;
    var bb = t;
    if x != 0.0 { bb = t * (1.0 - exp(-x)) / x; }
    return aa * exp(-bb * r0);
}

fn npv(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, a: f64, b: f64, sigma_r: f64, risk_premium: f64, correlation: f64) -> f64, bool {
    if option != black::CALL && option != black::PUT { return 0.0, false; }
    if spot <= 0.0 || strike < 0.0 || vol < 0.0 || t < 0.0 { return 0.0, false; }
    if a <= 0.0 || sigma_r < 0.0 { return 0.0, false; }
    if correlation < -1.0 || correlation > 1.0 { return 0.0, false; }
    let z = zero_bond(t, r, a, b, sigma_r, risk_premium);
    if is_nan(z) || is_inf(z) || !(z > 0.0) { return 0.0, false; }
    let s_t = spot * exp(-q * t);
    if is_nan(s_t) || is_inf(s_t) || !(s_t > 0.0) { return 0.0, false; }
    let g = (1.0 - exp(-a * t)) / a;
    let variance = vol * vol * t + 2.0 * correlation * vol * sigma_r * (t - g) / a + sigma_r * sigma_r * (t - 2.0 * g + (1.0 - exp(-2.0 * a * t)) / (2.0 * a)) / (a * a);
    if is_nan(variance) || is_inf(variance) || variance < 0.0 { return 0.0, false; }
    return black::black(option, strike, s_t / z, sqrt(variance), z, 0.0);
}
