// Fixed coupons, a yield NPV, an FRA amount, and a par swap rate.
// A cash flow on the settlement date has already occurred.

import date;
import daycount;
import rate;
import curve;
import solver;

namespace cash;

fn coupon(start: date::Date, end: date::Date, notional: f64, coupon_rate: f64, dc: daycount::Count) -> f64, bool {
    let yf, ok = daycount::year_fraction(dc, start, end, date::blank(), date::blank());
    if !ok { return 0.0, false; }
    return notional * coupon_rate * yf, true;
}

fn accrued(start: date::Date, settlement: date::Date, end: date::Date, notional: f64, coupon_rate: f64, dc: daycount::Count) -> f64, bool {
    if settlement.serial <= start.serial || settlement.serial >= end.serial { return 0.0, true; }
    return coupon(start, settlement, notional, coupon_rate, dc);
}

fn yield_npv(pay: i32[:], amounts: f64[:], settlement: i32, y: f64, compounding: i32, freq: i32, dc: daycount::Count) -> f64, bool {
    if pay.len != amounts.len { return 0.0, false; }
    var npv = 0.0;
    var discount = 1.0;
    var last = settlement;
    var i: i64 = 0;
    while i < pay.len {
        if pay[i] > settlement {
            let d1, ok1 = date::from_serial(last);
            let d2, ok2 = date::from_serial(pay[i]);
            if !ok1 || !ok2 { return 0.0, false; }
            let t, tok = daycount::year_fraction(dc, d1, d2, date::blank(), date::blank());
            if !tok { return 0.0, false; }
            let step, sok = rate::discount_factor(y, compounding, freq, t);
            if !sok { return 0.0, false; }
            discount *= step;
            npv += amounts[i] * discount;
            last = pay[i];
        }
        i += 1;
    }
    return npv, true;
}

fn curve_npv(pay: i32[:], amounts: f64[:], times: f64[:], discounts: f64[:], settlement: i32, ref: i32, dc: daycount::Count) -> f64, bool {
    if pay.len != amounts.len { return 0.0, false; }
    let ref_d, rok = date::from_serial(ref);
    if !rok { return 0.0, false; }
    var npv = 0.0;
    var i: i64 = 0;
    while i < pay.len {
        if pay[i] > settlement {
            let d, ok = date::from_serial(pay[i]);
            if !ok { return 0.0, false; }
            let t, tok = daycount::year_fraction(dc, ref_d, d, date::blank(), date::blank());
            if !tok { return 0.0, false; }
            let df, dok = curve::log_linear_discount(times, discounts, t);
            if !dok { return 0.0, false; }
            npv += amounts[i] * df;
        }
        i += 1;
    }
    return npv, true;
}

fn fit_clean(pay: i32[:], amounts: f64[:], times: f64[:], discounts: f64[:], settlement: i32, ref: i32, dc: daycount::Count, clean: f64, accrued: f64, guess: f64) -> f64, bool {
    if discounts.len == 0 || times.len != discounts.len { return 0.0, false; }
    let ref_d, rok = date::from_serial(ref);
    let set_d, sok = date::from_serial(settlement);
    if !rok || !sok { return 0.0, false; }
    let t_set, tok = daycount::year_fraction(dc, ref_d, set_d, date::blank(), date::blank());
    if !tok { return 0.0, false; }
    let last = discounts.len - 1;
    let df, ok = solver::brent(guess, 1.0e-4, 1.5, 1.0e-10, 100) {
        discounts[last] = it;
        let npv, nok = curve_npv(pay, amounts, times, discounts, settlement, ref, dc);
        let df_s, dok = curve::log_linear_discount(times, discounts, t_set);
        if nok && dok && df_s != 0.0 { npv / df_s - accrued - clean } else { 1.0 }
    };
    if ok { discounts[last] = df; }
    return df, ok;
}

fn fit_discount(pay: i32[:], amounts: f64[:], times: f64[:], discounts: f64[:], settlement: i32, ref: i32, dc: daycount::Count, price: f64, guess: f64) -> f64, bool {
    if discounts.len == 0 || times.len != discounts.len { return 0.0, false; }
    let last = discounts.len - 1;
    let df, ok = solver::brent(guess, 1.0e-4, 1.5, 1.0e-12, 80) {
        discounts[last] = it;
        let npv, nok = curve_npv(pay, amounts, times, discounts, settlement, ref, dc);
        if nok { npv - price } else { 1.0 }
    };
    if ok { discounts[last] = df; }
    return df, ok;
}

fn fra_amount(notional: f64, forward: f64, strike: f64, tau: f64, long_side: bool) -> f64, bool {
    let den = 1.0 + forward * tau;
    if tau < 0.0 || den == 0.0 { return 0.0, false; }
    var sign = 1.0;
    if !long_side { sign = -1.0; }
    return notional * sign * (forward - strike) * tau / den, true;
}

fn par_rate(taus: f64[:], dfs: f64[:]) -> f64, bool {
    if taus.len + 1 != dfs.len || taus.len == 0 { return 0.0, false; }
    var level = 0.0;
    var i: i64 = 0;
    while i < taus.len {
        level += taus[i] * dfs[i + 1];
        i += 1;
    }
    if level == 0.0 { return 0.0, false; }
    return (dfs[0] - dfs[dfs.len - 1]) / level, true;
}
