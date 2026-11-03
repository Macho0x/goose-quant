// European zero-coupon convertible, Tsiveriotis-Fernandes.
// npv is the closed form. The shares received on conversion are discounted
// at the risk-free rate. The redemption, paid only if the bond is not
// converted, is discounted at the risk-free rate plus the credit spread.
// A zero spread is the straight bond plus a Black call struck at the
// conversion price.
// crr is that bond on the Cox-Ross-Rubinstein tree (no coupons, no
// dividends, conversion only at maturity). The rollback is the
// Tsiveriotis-Fernandes lattice: each child is discounted by
// 1/(1 + blended rate * dt). The blend is the risk-free rate where the
// bond converts, and that rate plus the credit spread otherwise.

import math;
import normal;
import rate;
import tree;

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

fn crr(spot: f64, redemption: f64, ratio: f64, r: f64, q: f64, vol: f64, t: f64, spread: f64, steps: i32) -> f64, bool {
    if spot <= 0.0 || redemption <= 0.0 || ratio <= 0.0 { return 0.0, false; }
    let up, down, pu, ok = tree::crr_factors(r, q, vol, t, steps);
    if !ok || pu < 0.0 || pu > 1.0 || down <= 0.0 { return 0.0, false; }
    let pd = 1.0 - pu;
    let n = steps as i64;
    let dt = t / n;
    let risky = r + spread;
    var value: f64[>..] = [];
    var prob: f64[>..] = [];
    var s = spot * pow(down, n);
    let climb = up / down;
    var j: i64 = 0;
    while j <= n {
        var payoff = ratio * s;
        var p = 0.0;
        if payoff >= redemption { p = 1.0; } else { payoff = redemption; }
        value.push(payoff);
        prob.push(p);
        s *= climb;
        j += 1;
    }
    var i = n;
    while i > 0 {
        i -= 1;
        j = 0;
        while j <= i {
            let down_rate = prob[j] * r + (1.0 - prob[j]) * risky;
            let up_rate = prob[j + 1] * r + (1.0 - prob[j + 1]) * risky;
            value[j] = pd * value[j] / (1.0 + down_rate * dt) + pu * value[j + 1] / (1.0 + up_rate * dt);
            prob[j] = pd * prob[j] + pu * prob[j + 1];
            j += 1;
        }
    }
    return value[0], true;
}
