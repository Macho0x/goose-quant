// European zero-coupon convertible, Tsiveriotis-Fernandes.
// npv is the closed form. The shares received on conversion are discounted
// at the risk-free rate. The redemption, paid only if the bond is not
// converted, is discounted at the risk-free rate plus the credit spread.
// A zero spread is the straight bond plus a Black call struck at the
// conversion price.
// crr is that bond on the Cox-Ross-Rubinstein tree (no coupons, no
// dividends, conversion only at maturity). binomial is the same
// Tsiveriotis-Fernandes lattice with coupons, escrowed dividends, and
// American exercise, on JR, CRR, additive, Trigeorgis, Tian, Leisen-Reimer,
// and Joshi. Each child is discounted by 1/(1 + blended rate * dt). The
// blend is the risk-free rate where the bond converts, and that rate plus
// the credit spread otherwise. A dividend is taken out of the spot and
// added back to the conversion price until its ex date.
// ponytail: the example's soft call and put are not on this lattice. Add
// them beside the coupon if a row has to include the call schedule.

import math;
import normal;
import rate;
import tree;

namespace convertible;

const CRR: i32 = 0;
const JR: i32 = 1;
const ADDITIVE: i32 = 2;
const TRIGEORGIS: i32 = 3;
const TIAN: i32 = 4;
const LEISEN: i32 = 5;
const JOSHI: i32 = 6;

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

// Discounted dividend kept by DiscretizedConvertible::dividendValues.
// An ex date on or before settlement has already occurred and is stored as 0.
fn stored_dividend(amount: f64, discount: f64, ex: i32, settlement: i32) -> f64, bool {
    if amount < 0.0 || discount < 0.0 { return 0.0, false; }
    if ex <= settlement { return 0.0, true; }
    return amount * discount, true;
}

fn dividend_value(amount: f64, r: f64, when: f64) -> f64, bool {
    if amount < 0.0 || when < 0.0 { return 0.0, false; }
    let df, ok = rate::discount_factor(r, rate::CONTINUOUS, 0, when);
    if !ok { return 0.0, false; }
    return amount * df, true;
}

// Coupons of 5 at each whole year and a dividend of 1 at each half-year
// before maturity. The 3-day settlement lag is not in these year fractions.
fn sample_flows(t: f64, coupon_t: f64[>..] &, coupon_a: f64[>..] &, div_t: f64[>..] &, div_a: f64[>..] &) -> bool {
    if t <= 0.0 { return false; }
    var y = 1.0;
    while y <= t {
        coupon_t.push(y);
        coupon_a.push(5.0);
        y += 1.0;
    }
    var h = 0.5;
    while h < t {
        div_t.push(h);
        div_a.push(1.0);
        h += 0.5;
    }
    return true;
}

fn snap(time: f64, dt: f64, n: i64) -> i64 {
    let x = time / dt;
    let lo = floor(x);
    var step = lo as i64;
    if x - lo > 0.5 { step += 1; }
    if step < 0 { return 0; }
    if step > n { return n; }
    return step;
}

fn parked(step: i64[:], amt: f64[:], i: i64, dt: f64, r: f64) -> f64 {
    var extra = 0.0;
    var k: i64 = 0;
    while k < step.len {
        if step[k] >= i {
            let tau = (step[k] - i) * dt;
            extra += amt[k] * exp(-r * tau);
        }
        k += 1;
    }
    return extra;
}

fn moves(kind: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, steps: i32) -> f64, f64, f64, i32, bool {
    if kind == CRR {
        let up, down, pu, ok = tree::crr_factors(r, q, vol, t, steps);
        return up, down, pu, steps, ok;
    }
    if vol <= 0.0 || t <= 0.0 || steps < 2 { return 0.0, 0.0, 0.0, 0, false; }
    let dt = t / steps;
    let drift = (r - q - 0.5 * vol * vol) * dt;
    if kind == JR {
        let dx = vol * sqrt(dt);
        return exp(drift + dx), exp(drift - dx), 0.5, steps, true;
    }
    if kind == ADDITIVE {
        let radicand = 4.0 * vol * vol * dt - 3.0 * drift * drift;
        if radicand < 0.0 { return 0.0, 0.0, 0.0, 0, false; }
        let jump = -0.5 * drift + 0.5 * sqrt(radicand);
        return exp(drift + jump), exp(drift - jump), 0.5, steps, true;
    }
    if kind == TRIGEORGIS {
        let dx = sqrt(vol * vol * dt + drift * drift);
        if dx == 0.0 { return 0.0, 0.0, 0.0, 0, false; }
        let pu = 0.5 + 0.5 * drift / dx;
        return exp(dx), exp(-dx), pu, steps, true;
    }
    if kind == TIAN {
        let v = exp(vol * vol * dt);
        let growth = exp(drift) * sqrt(v);
        let width = sqrt(v * v + 2.0 * v - 3.0);
        let up = 0.5 * growth * v * (v + 1.0 + width);
        let down = 0.5 * growth * v * (v + 1.0 - width);
        if up == down { return 0.0, 0.0, 0.0, 0, false; }
        return up, down, (growth - down) / (up - down), steps, true;
    }
    if kind != LEISEN && kind != JOSHI { return 0.0, 0.0, 0.0, 0, false; }
    if spot <= 0.0 || strike <= 0.0 { return 0.0, 0.0, 0.0, 0, false; }
    let n = tree::odd(steps);
    let dt_n = t / n;
    let drift_n = (r - q - 0.5 * vol * vol) * dt_n;
    let width = vol * sqrt(t);
    let nf = n;
    let d2 = (log(spot / strike) + drift_n * nf) / width;
    let growth = exp((r - q) * dt_n);
    if kind == LEISEN {
        let pu = tree::peizer(d2, nf);
        if pu <= 0.0 || pu >= 1.0 { return 0.0, 0.0, 0.0, 0, false; }
        let up = growth * tree::peizer(d2 + width, nf) / pu;
        let down = (growth - pu * up) / (1.0 - pu);
        return up, down, pu, n, true;
    }
    let k = (nf - 1.0) / 2.0;
    let pu = tree::joshi_p(k, d2);
    if pu <= 0.0 || pu >= 1.0 { return 0.0, 0.0, 0.0, 0, false; }
    let up = growth * tree::joshi_p(k, d2 + width) / pu;
    let down = (growth - pu * up) / (1.0 - pu);
    return up, down, pu, n, true;
}

// A negative dividend time is an ex date before settlement. It is taken out
// of the spot and is not added back.
fn binomial(spot: f64, redemption: f64, ratio: f64, r: f64, q: f64, vol: f64, t: f64, spread: f64, steps: i32, kind: i32, american: bool, coupon_t: f64[:], coupon_a: f64[:], div_t: f64[:], div_a: f64[:]) -> f64, bool {
    if spot <= 0.0 || redemption <= 0.0 || ratio <= 0.0 { return 0.0, false; }
    if coupon_t.len != coupon_a.len || div_t.len != div_a.len { return 0.0, false; }
    var s0 = spot;
    var k: i64 = 0;
    while k < div_a.len {
        if div_a[k] < 0.0 || div_t[k] > t { return 0.0, false; }
        if div_t[k] >= 0.0 {
            let cash, cok = dividend_value(div_a[k], r, div_t[k]);
            if !cok { return 0.0, false; }
            s0 -= cash;
        } else {
            s0 -= div_a[k];
        }
        k += 1;
    }
    if s0 <= 0.0 { return 0.0, false; }
    let up, down, pu, n, ok = moves(kind, s0, redemption / ratio, r, q, vol, t, steps);
    if !ok || pu < 0.0 || pu > 1.0 || up <= 0.0 || down <= 0.0 { return 0.0, false; }
    let pd = 1.0 - pu;
    let n64 = n as i64;
    let dt = t / n;
    let risky = r + spread;
    let climb = up / down;
    var coup: f64[>..] = [];
    var i: i64 = 0;
    while i <= n64 {
        coup.push(0.0);
        i += 1;
    }
    k = 0;
    while k < coupon_t.len {
        if coupon_a[k] < 0.0 || coupon_t[k] < 0.0 || coupon_t[k] > t { return 0.0, false; }
        let at = snap(coupon_t[k], dt, n64);
        coup[at] += coupon_a[k];
        k += 1;
    }
    var div_step: i64[>..] = [];
    var div_amt: f64[>..] = [];
    k = 0;
    while k < div_t.len {
        if div_t[k] >= 0.0 {
            div_step.push(snap(div_t[k], dt, n64));
            div_amt.push(div_a[k]);
        }
        k += 1;
    }
    var value: f64[>..] = [];
    var prob: f64[>..] = [];
    var blended: f64[>..] = [];
    var s = s0 * pow(down, n64);
    let extra_n = parked(div_step, div_amt, n64, dt, r);
    var j: i64 = 0;
    while j <= n64 {
        var held = redemption + coup[n64];
        var p = 0.0;
        let conv = ratio * (s + extra_n);
        if conv >= held {
            held = conv;
            p = 1.0;
        }
        value.push(held);
        prob.push(p);
        blended.push(p * r + (1.0 - p) * risky);
        s *= climb;
        j += 1;
    }
    i = n64;
    while i > 0 {
        i -= 1;
        let extra = parked(div_step, div_amt, i, dt, r);
        s = s0 * pow(down, i);
        j = 0;
        while j <= i {
            value[j] = pd * value[j] / (1.0 + blended[j] * dt) + pu * value[j + 1] / (1.0 + blended[j + 1] * dt);
            prob[j] = pd * prob[j] + pu * prob[j + 1];
            value[j] += coup[i];
            if american {
                let conv = ratio * (s + extra);
                if value[j] <= conv {
                    value[j] = conv;
                    prob[j] = 1.0;
                }
            }
            blended[j] = prob[j] * r + (1.0 - prob[j]) * risky;
            s *= climb;
            j += 1;
        }
    }
    if is_nan(value[0]) || is_inf(value[0]) { return 0.0, false; }
    return value[0], true;
}

fn crr(spot: f64, redemption: f64, ratio: f64, r: f64, q: f64, vol: f64, t: f64, spread: f64, steps: i32) -> f64, bool {
    var hole: f64[1] = [0.0];
    let none = hole[0..0];
    return binomial(spot, redemption, ratio, r, q, vol, t, spread, steps, CRR, false, none, none, none, none);
}
