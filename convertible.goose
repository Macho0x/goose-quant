// European zero-coupon convertible, Tsiveriotis-Fernandes closed form.
// The shares received on conversion are discounted at the risk-free rate.
// The redemption, paid only if the bond is not converted, is discounted at
// the risk-free rate plus the credit spread. A zero spread is the straight
// bond plus a Black call struck at the conversion price.

import math;
import normal;
import rate;

namespace convertible;

fn npv(spot: f64, redemption: f64, ratio: f64, r: f64, q: f64, vol: f64, t: f64, spread: f64) -> f64, bool {
    if spot <= 0.0 || redemption <= 0.0 || ratio <= 0.0 || vol < 0.0 || t < 0.0 { return 0.0, false; }
    let df_r, rok = rate::discount_factor(r, rate::CONTINUOUS, 0, t);
    let df_q, qok = rate::discount_factor(q, rate::CONTINUOUS, 0, t);
    let df_s, sok = rate::discount_factor(r + spread, rate::CONTINUOUS, 0, t);
    if !rok || !qok || !sok || df_r == 0.0 { return 0.0, false; }
    let strike = redemption / ratio;
    let forward = spot * df_q / df_r;
    if forward <= 0.0 || t == 0.0 || vol == 0.0 {
        if forward >= strike { return ratio * spot * df_q, true; }
        return redemption * df_s, true;
    }
    let std = vol * sqrt(t);
    let d1 = log(forward / strike) / std + 0.5 * std;
    let d2 = d1 - std;
    let equity = ratio * spot * df_q * normal::cdf(d1);
    let cash = redemption * df_s * normal::cdf(-d2);
    return equity + cash, true;
}
