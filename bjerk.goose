// Bjerksund-Stensland American approximation.
// The flat trigger is the 1993 boundary. When the value is still rising
// there, a golden-section search on log(trigger) replaces it.

import math;
import black;
import normal;

namespace bjerk;

fn phi(spot: f64, gamma: f64, h: f64, trig: f64, rt: f64, bt: f64, variance: f64) -> f64 {
    let lambda = -rt + gamma * bt + 0.5 * gamma * (gamma - 1.0) * variance;
    let sv = sqrt(variance);
    let d = -(log(spot / h) + (bt + (gamma - 0.5) * variance)) / sv;
    let kappa = 2.0 * bt / variance + (2.0 * gamma - 1.0);
    let tail = d - 2.0 * log(trig / spot) / sv;
    return exp(lambda) * (normal::cdf(d) - pow(trig / spot, kappa) * normal::cdf(tail));
}

fn flat_value(spot: f64, strike: f64, trig: f64, beta: f64, rt: f64, bt: f64, variance: f64) -> f64 {
    if spot >= trig { return spot - strike; }
    let weight = pow(spot / trig, beta);
    return (trig - strike) * weight * (1.0 - phi(spot, beta, trig, trig, rt, bt, variance))
        + spot * phi(spot, 1.0, trig, trig, rt, bt, variance)
        - spot * phi(spot, 1.0, strike, trig, rt, bt, variance)
        - strike * phi(spot, 0.0, trig, trig, rt, bt, variance)
        + strike * phi(spot, 0.0, strike, trig, rt, bt, variance);
}

// Ties keep the lower point. The value peaks near the floor of the bracket
// and then flattens, so a higher tie would walk up the plateau.
fn best_trigger(spot: f64, strike: f64, lower: f64, upper: f64, beta: f64, rt: f64, bt: f64, variance: f64) -> f64 {
    let g = (sqrt(5.0) - 1.0) / 2.0;
    var a = log(lower);
    var b = log(upper);
    var c = b - g * (b - a);
    var d = a + g * (b - a);
    var fc = flat_value(spot, strike, exp(c), beta, rt, bt, variance);
    var fd = flat_value(spot, strike, exp(d), beta, rt, bt, variance);
    while b - a > 1.0e-8 {
        if fc >= fd {
            b = d;
            d = c;
            fd = fc;
            c = b - g * (b - a);
            fc = flat_value(spot, strike, exp(c), beta, rt, bt, variance);
        } else {
            a = c;
            c = d;
            fc = fd;
            d = a + g * (b - a);
            fd = flat_value(spot, strike, exp(d), beta, rt, bt, variance);
        }
    }
    if fc >= fd { return exp(c); }
    return exp(d);
}

fn euro_call(spot: f64, strike: f64, rf_d: f64, d_d: f64, variance: f64) -> f64, bool {
    if rf_d <= 0.0 { return 0.0, false; }
    let forward = spot * d_d / rf_d;
    return black::black(black::CALL, strike, forward, sqrt(variance), rf_d, 0.0);
}

fn call_approx(spot: f64, strike: f64, rf_d: f64, d_d: f64, variance: f64) -> f64, bool {
    let euro, eok = euro_call(spot, strike, rf_d, d_d, variance);
    if !eok { return 0.0, false; }
    let bt = log(d_d / rf_d);
    let rt = log(1.0 / rf_d);
    let sv = sqrt(variance);
    let bv = bt / variance;
    // With q = 0 the radicand is a perfect square, so rounding can take it
    // just below zero where r = -variance / 2.
    var rad = (bv - 0.5) * (bv - 0.5) + 2.0 * rt / variance;
    if rad < 0.0 { rad = 0.0; }
    let beta = 0.5 - bv + sqrt(rad);
    var b0 = strike;
    if bt != rt {
        let ratio = rt / (rt - bt) * strike;
        if ratio > b0 { b0 = ratio; }
    }
    let span = bt + 2.0 * sv;
    var gap = beta - 1.0;
    if gap < 0.0 { gap = -gap; }
    var trigger = b0 + span * b0;
    if gap >= 1.0e-8 {
        let binf = beta / (beta - 1.0) * strike;
        if binf == b0 {
            trigger = b0;
        } else {
            let ht = -span * b0 / (binf - b0);
            trigger = b0 + (binf - b0) * (1.0 - exp(ht));
        }
        var lower = trigger;
        if spot > lower { lower = spot; }
        if lower > 0.0 && lower < binf {
            let up = flat_value(spot, strike, lower * (1.0 + 1.0e-6), beta, rt, bt, variance);
            let at = flat_value(spot, strike, lower, beta, rt, bt, variance);
            if up > at {
                trigger = best_trigger(spot, strike, lower, binf, beta, rt, bt, variance);
            }
        }
    }
    var value = 0.0;
    if spot >= trigger {
        value = spot - strike;
        if value < 0.0 { value = 0.0; }
    } else {
        let forward = spot * d_d / rf_d;
        // Past this many standard deviations the trigger has run away.
        if forward > 0.0 && trigger > 0.0 && log(trigger / forward) / sv > 12.5 {
            value = euro;
        } else {
            value = flat_value(spot, strike, trigger, beta, rt, bt, variance);
        }
    }
    if value < euro { return euro, true; }
    return value, true;
}

fn npv(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64) -> f64, bool {
    if option != black::CALL && option != black::PUT { return 0.0, false; }
    if spot <= 0.0 || strike <= 0.0 || vol < 0.0 || t < 0.0 { return 0.0, false; }
    // A put is the call with spot and strike swapped and the two rates swapped.
    var s = spot;
    var x = strike;
    var rr = r;
    var qq = q;
    if option == black::PUT {
        s = strike;
        x = spot;
        rr = q;
        qq = r;
    }
    let variance = vol * vol * t;
    let rf_d = exp(-rr * t);
    let d_d = exp(-qq * t);
    if rf_d <= 0.0 || d_d <= 0.0 { return 0.0, false; }
    if d_d > 1.0 && rf_d > d_d { return 0.0, false; }
    var value = 0.0;
    if variance < 2.2204460492503131e-16 || (d_d >= 1.0 && d_d >= rf_d) {
        let euro, eok = euro_call(s, x, rf_d, d_d, variance);
        if !eok { return 0.0, false; }
        value = euro;
    } else {
        let amer, aok = call_approx(s, x, rf_d, d_d, variance);
        if !aok { return 0.0, false; }
        value = amer;
    }
    let exercise = (s - x) * (1.0 + 10.0 * 2.2204460492503131e-16);
    if value < exercise {
        value = s - x;
        if value < 0.0 { value = 0.0; }
    }
    if is_nan(value) { return 0.0, false; }
    return value, true;
}
