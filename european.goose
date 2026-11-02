// Analytic European price on a Black-Scholes-Merton forward.
// t is the year fraction from the curve's reference date to expiry.
// The discount and the dividend discount are continuous.

import math;
import rate;
import black;

namespace european;

fn npv(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64) -> f64, bool {
    if t < 0.0 || vol < 0.0 || spot <= 0.0 { return 0.0, false; }
    let df_r, rok = rate::discount_factor(r, rate::CONTINUOUS, 0, t);
    let df_q, qok = rate::discount_factor(q, rate::CONTINUOUS, 0, t);
    if !rok || !qok || df_r == 0.0 { return 0.0, false; }
    let forward = spot * df_q / df_r;
    return black::black(option, strike, forward, vol * sqrt(t), df_r, 0.0);
}
