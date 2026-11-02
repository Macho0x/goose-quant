// SegmentIntegral(5000) over drift ± 10 sqrt(variance), then the
// discount / sqrt(2 pi variance) factor from IntegralEngine.

import math;
import black;
import rate;

namespace vanilla_integral;

fn density(x: f64, option: i32, spot: f64, strike: f64, drift: f64, variance: f64) -> f64 {
    let s = spot * exp(x);
    var payoff = (s - strike) * option;
    if payoff < 0.0 { payoff = 0.0; }
    let z = x - drift;
    return payoff * exp(-(z * z) / (2.0 * variance));
}

fn panels(option: i32, spot: f64, strike: f64, drift: f64, variance: f64, a: f64, b: f64) -> f64 {
    let dx = (b - a) / 5000.0;
    var sum = 0.5 * (density(a, option, spot, strike, drift, variance) + density(b, option, spot, strike, drift, variance));
    var i: i32 = 1;
    while i < 5000 {
        sum += density(a + i * dx, option, spot, strike, drift, variance);
        i += 1;
    }
    return sum * dx;
}

fn npv(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64) -> f64, bool {
    if option != black::CALL && option != black::PUT { return 0.0, false; }
    if spot <= 0.0 || vol <= 0.0 || t <= 0.0 { return 0.0, false; }
    let df_r, rok = rate::discount_factor(r, rate::CONTINUOUS, 0, t);
    let df_q, qok = rate::discount_factor(q, rate::CONTINUOUS, 0, t);
    if !rok || !qok || df_r <= 0.0 || df_q <= 0.0 { return 0.0, false; }
    let variance = vol * vol * t;
    let drift = log(df_q / df_r) - 0.5 * variance;
    let span = 10.0 * sqrt(variance);
    let mass = panels(option, spot, strike, drift, variance, drift - span, drift + span);
    let value = df_r / sqrt(2.0 * PI * variance) * mass;
    if is_nan(value) { return 0.0, false; }
    return value, true;
}
