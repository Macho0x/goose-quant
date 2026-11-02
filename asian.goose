// Analytic continuous geometric average-price Asian.
// QuantLib's AnalyticContinuousGeometricAveragePriceAsianEngine (Haug, pp. 96-97).
// Flat continuous rates that share one year fraction t from the curve
// reference date to expiry. Seasoned averages are not priced.

import math;
import black;

namespace asian;

fn npv(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64) -> f64, bool {
    if option != black::CALL && option != black::PUT { return 0.0, false; }
    if spot <= 0.0 || strike < 0.0 || vol < 0.0 || t < 0.0 { return 0.0, false; }
    let variance = vol * vol * t;
    let q_adj = 0.5 * (r + q + vol * vol / 6.0);
    let df_r = exp(-r * t);
    if df_r <= 0.0 { return 0.0, false; }
    let forward = spot * exp(-q_adj * t) / df_r;
    return black::black(option, strike, forward, sqrt(variance / 3.0), df_r, 0.0);
}
