// Yield curves. A flat curve is one continuously or discretely compounded
// rate. A discount curve stores dates and discount factors.

import date;
import rate;
import math;

namespace curve;

fn flat_discount(r: f64, compounding: i32, freq: i32, t: f64) -> f64, bool {
    return rate::discount_factor(r, compounding, freq, t);
}

fn linear_discount(times: f64[:], discounts: f64[:], t: f64) -> f64, bool {
    if times.len != discounts.len || times.len == 0 { return 0.0, false; }
    if t <= times[0] { return discounts[0], true; }
    let last = times.len - 1;
    if t >= times[last] { return discounts[last], true; }
    var i: i64 = 1;
    while i < times.len {
        if t <= times[i] {
            let span = times[i] - times[i - 1];
            if span == 0.0 { return discounts[i], true; }
            let w = (t - times[i - 1]) / span;
            return discounts[i - 1] + w * (discounts[i] - discounts[i - 1]), true;
        }
        i += 1;
    }
    return discounts[last], true;
}

fn log_linear_discount(times: f64[:], discounts: f64[:], t: f64) -> f64, bool {
    if times.len != discounts.len || times.len == 0 { return 0.0, false; }
    if t <= times[0] { return discounts[0], true; }
    let last = times.len - 1;
    if t >= times[last] { return discounts[last], true; }
    var i: i64 = 1;
    while i < times.len {
        if t <= times[i] {
            let span = times[i] - times[i - 1];
            if span == 0.0 || discounts[i - 1] <= 0.0 || discounts[i] <= 0.0 { return 0.0, false; }
            let w = (t - times[i - 1]) / span;
            let log_d = (1.0 - w) * log(discounts[i - 1]) + w * log(discounts[i]);
            return exp(log_d), true;
        }
        i += 1;
    }
    return discounts[last], true;
}

fn simple_pillars(times: f64[:], rates: f64[:], discounts: f64[:]) -> bool {
    if times.len != rates.len || times.len != discounts.len || times.len == 0 { return false; }
    var i: i64 = 0;
    while i < times.len {
        let df, ok = rate::discount_factor(rates[i], rate::SIMPLE, 0, times[i]);
        if !ok { return false; }
        discounts[i] = df;
        i += 1;
    }
    return true;
}

fn implied_discount(r: f64, compounding: i32, freq: i32, t_base: f64, t: f64) -> f64, bool {
    let base, bok = flat_discount(r, compounding, freq, t_base);
    let full, fok = flat_discount(r, compounding, freq, t);
    if !bok || !fok || base == 0.0 { return 0.0, false; }
    return full / base, true;
}

fn zero_spreaded_discount(r: f64, spread: f64, t: f64) -> f64, bool {
    let df, ok = flat_discount(r, rate::CONTINUOUS, 0, t);
    if !ok { return 0.0, false; }
    return df * exp(-spread * t), true;
}
