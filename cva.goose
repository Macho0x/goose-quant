// CVA on the CVAIRS payer swaps, 10 March 2004.
// CounterpartyAdjSwapEngine: Black swaption on each fixed-pay window,
// times the hazard curve's default probability, times loss given default.
// The spot swap is quarterly Actual/Actual ISDA. Each swaptionlet is the
// engine's EUR swap: annual 30/360 fixed against Euribor 3M.
// ponytail: investor hazard in the example is 1e-12, so this is the
// counterparty sum. Add the investor put if DVA is priced too.

import math;
import date;
import period;
import daycount;
import calendar;
import markets;
import schedule;
import curve;
import cash;
import black;

namespace cva;

const TENOR: i32[6] = [5, 10, 15, 20, 25, 30];
const RATE: f64[6] = [0.03249, 0.04074, 0.04463, 0.04675, 0.04775, 0.04811];
const LOW: f64[10] = [0.0036, 0.0036, 0.0065, 0.0099, 0.0111, 0.0177, 0.0177, 0.0177, 0.0177, 0.0177];
const MEDIUM: f64[10] = [0.0202, 0.0202, 0.0231, 0.0266, 0.0278, 0.0349, 0.0349, 0.0349, 0.0349, 0.0349];
const HIGH: f64[10] = [0.0534, 0.0534, 0.0564, 0.06, 0.0614, 0.0696, 0.0696, 0.0696, 0.0696, 0.0696];
const GRID: i32[10] = [0, 12, 36, 60, 84, 120, 180, 240, 300, 360];
const RECOVERY_LOW: f64 = 0.4;
const RECOVERY_MEDIUM: f64 = 0.35;
const RECOVERY_HIGH: f64 = 0.3;
const NOTIONAL: f64 = 100.0;
const VOL: f64 = 0.15;

fn asof() -> date::Date, bool {
    let raw, ok = date::from_ymd(10, date::MARCH, 2004);
    if !ok { return date::blank(), false; }
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    return calendar::adjust(markets::TARGET, raw, calendar::FOLLOWING, empty, empty);
}

fn spot_date(today: date::Date) -> date::Date, bool {
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    return calendar::advance(markets::TARGET, today, 2, period::DAYS, calendar::FOLLOWING, false, empty, empty);
}

fn dated(start: date::Date, end: date::Date, months: i32, out: i32[:]) -> i64, bool {
    if start.serial >= end.serial { return 0, false; }
    let n, ok = schedule::build(start, end, months, period::MONTHS, markets::TARGET, calendar::MODIFIED_FOLLOWING, calendar::MODIFIED_FOLLOWING, schedule::BACKWARD, false, out);
    if !ok || n < 2 { return 0, false; }
    return n, true;
}

fn df_at(times: f64[:], dfs: f64[:], t: f64) -> f64, bool {
    if times.len < 2 || times.len != dfs.len { return 0.0, false; }
    if t < times[0] {
        let span = times[1] - times[0];
        if span == 0.0 || dfs[0] <= 0.0 || dfs[1] <= 0.0 { return 0.0, false; }
        let slope = (log(dfs[1]) - log(dfs[0])) / span;
        return dfs[0] * exp(slope * (t - times[0])), true;
    }
    let last = times.len - 1;
    if t > times[last] {
        let span = times[last] - times[last - 1];
        if span == 0.0 || dfs[last] <= 0.0 || dfs[last - 1] <= 0.0 { return 0.0, false; }
        let slope = (log(dfs[last]) - log(dfs[last - 1])) / span;
        return dfs[last] * exp(slope * (t - times[last])), true;
    }
    return curve::log_linear_discount(times, dfs, t);
}

fn discount(ref_d: date::Date, d: date::Date, times: f64[:], dfs: f64[:]) -> f64, bool {
    let t, ok = daycount::year_fraction(daycount::actual_actual_isda(), ref_d, d, date::blank(), date::blank());
    if !ok { return 0.0, false; }
    return df_at(times, dfs, t);
}

fn pillar(spot: date::Date, years: i32, quote: f64, times: f64[:], dfs: f64[:], n: i64) -> i64, bool {
    if n < 1 || n >= times.len || n >= dfs.len { return n, false; }
    let maturity, mok = date::plus_years(spot, years);
    if !mok { return n, false; }
    var dates: i32[160] = [0; 160];
    let count, cok = dated(spot, maturity, 3, dates);
    if !cok { return n, false; }
    var pay: f64[160] = [0.0; 160];
    var taus: f64[160] = [0.0; 160];
    let m = count - 1;
    var i: i64 = 0;
    while i < m {
        let d0, a = date::from_serial(dates[i]);
        let d1, b = date::from_serial(dates[i + 1]);
        if !a || !b { return n, false; }
        let tau, tok = daycount::year_fraction(daycount::actual_actual_isda(), d0, d1, date::blank(), date::blank());
        let t, uok = daycount::year_fraction(daycount::actual_actual_isda(), spot, d1, date::blank(), date::blank());
        if !tok || !uok || tau <= 0.0 { return n, false; }
        pay[i] = t;
        taus[i] = tau;
        i += 1;
    }
    let end_t = pay[m - 1];
    if end_t <= times[n - 1] { return n, false; }
    var guess = dfs[n - 1];
    let den = 1.0 + quote * (end_t - times[n - 1]);
    if den > 0.2 { guess = dfs[n - 1] / den; }
    if guess < 0.02 { guess = 0.02; }
    if guess > 1.4 { guess = 1.4; }
    times[n] = end_t;
    dfs[n] = guess;
    let nn = n + 1;
    let df, fok = cash::fit_par(pay[0..m], taus[0..m], times[0..nn], dfs[0..nn], 0.0, end_t, quote, guess);
    if !fok || df <= 0.0 { return n, false; }
    return nn, true;
}

fn market(spot: date::Date, times: f64[:], dfs: f64[:]) -> i64, bool {
    if times.len < 7 || dfs.len < 7 { return 0, false; }
    times[0] = 0.0;
    dfs[0] = 1.0;
    var n: i64 = 1;
    var i: i64 = 0;
    while i < 6 {
        let nn, ok = pillar(spot, TENOR[i], RATE[i], times, dfs, n);
        if !ok { return 0, false; }
        n = nn;
        i += 1;
    }
    return n, true;
}

fn forward_annuity(spot: date::Date, fixed: i32[:], n_fixed: i64, floating: i32[:], n_float: i64, times: f64[:], dfs: f64[:], dc: daycount::Count) -> f64, f64, bool {
    if n_fixed < 2 || n_float < 2 { return 0.0, 0.0, false; }
    if fixed[n_fixed - 1] != floating[n_float - 1] { return 0.0, 0.0, false; }
    let m = n_fixed - 1;
    var taus: f64[160] = [0.0; 160];
    var leg: f64[161] = [0.0; 161];
    var i: i64 = 0;
    while i < m {
        let d0, a = date::from_serial(fixed[i]);
        let d1, b = date::from_serial(fixed[i + 1]);
        if !a || !b { return 0.0, 0.0, false; }
        let tau, tok = daycount::year_fraction(dc, d0, d1, date::blank(), date::blank());
        let df, dok = discount(spot, d1, times, dfs);
        if !tok || !dok || tau <= 0.0 { return 0.0, 0.0, false; }
        taus[i] = tau;
        leg[i + 1] = df;
        i += 1;
    }
    let float_start, sok = date::from_serial(floating[0]);
    if !sok { return 0.0, 0.0, false; }
    let df0, d0 = discount(spot, float_start, times, dfs);
    if !d0 { return 0.0, 0.0, false; }
    leg[0] = df0;
    let fwd, fok = cash::par_rate(taus[0..m], leg[0..m + 1]);
    if !fok || fwd == 0.0 { return 0.0, 0.0, false; }
    var level = (leg[0] - leg[m]) / fwd;
    if level < 0.0 { level = -level; }
    return fwd, NOTIONAL * level, true;
}

fn fair(years: i32) -> f64, bool {
    let today, tok = asof();
    if !tok { return 0.0, false; }
    let spot, sok = spot_date(today);
    if !sok { return 0.0, false; }
    var times: f64[8] = [0.0; 8];
    var dfs: f64[8] = [0.0; 8];
    let nodes, nok = market(spot, times, dfs);
    if !nok { return 0.0, false; }
    let maturity, mok = date::plus_years(spot, years);
    if !mok { return 0.0, false; }
    var dates: i32[160] = [0; 160];
    let n, dok = dated(spot, maturity, 3, dates);
    if !dok { return 0.0, false; }
    let rate, ann, rok = forward_annuity(spot, dates, n, dates, n, times[0..nodes], dfs[0..nodes], daycount::actual_actual_isda());
    if !rok || ann <= 0.0 { return 0.0, false; }
    return rate, true;
}

fn swaption(today: date::Date, spot: date::Date, start: date::Date, end: date::Date, strike: f64, times: f64[:], dfs: f64[:]) -> f64, bool {
    var fixed: i32[160] = [0; 160];
    var floating: i32[160] = [0; 160];
    let n_fixed, fok = dated(start, end, 12, fixed);
    let n_float, qok = dated(start, end, 3, floating);
    if !fok || !qok { return 0.0, false; }
    let fwd, ann, rok = forward_annuity(spot, fixed, n_fixed, floating, n_float, times, dfs, daycount::thirty360_bond());
    if !rok || ann <= 0.0 || fwd <= 0.0 || strike <= 0.0 { return 0.0, false; }
    let t, tok = daycount::year_fraction(daycount::actual365_fixed(), today, start, date::blank(), date::blank());
    if !tok || t < 0.0 { return 0.0, false; }
    var std = 0.0;
    if t > 0.0 { std = VOL * sqrt(t); }
    return black::black(black::CALL, strike, fwd, std, ann, 0.0);
}

fn exposure(years: i32, epe: f64[:], t_lo: f64[:], t_hi: f64[:]) -> i64, bool {
    if years <= 0 { return 0, false; }
    let today, tok = asof();
    if !tok { return 0, false; }
    let spot, sok = spot_date(today);
    if !sok { return 0, false; }
    var times: f64[8] = [0.0; 8];
    var dfs: f64[8] = [0.0; 8];
    let nodes, nok = market(spot, times, dfs);
    if !nok { return 0, false; }
    let maturity, mok = date::plus_years(spot, years);
    if !mok { return 0, false; }
    var dates: i32[160] = [0; 160];
    let n, dok = dated(spot, maturity, 3, dates);
    if !dok { return 0, false; }
    let strike, kok = fair(years);
    if !kok || strike <= 0.0 { return 0, false; }
    let end, eok = date::from_serial(dates[n - 1]);
    if !eok { return 0, false; }
    var k: i64 = 0;
    var start = today;
    var i: i64 = 1;
    while i < n {
        let pay, pok = date::from_serial(dates[i]);
        if !pok { return 0, false; }
        if pay.serial >= today.serial {
            let px, xok = swaption(today, spot, start, end, strike, times[0..nodes], dfs[0..nodes]);
            if !xok { return 0, false; }
            if k >= epe.len || k >= t_lo.len || k >= t_hi.len { return 0, false; }
            let lo, lok = daycount::year_fraction(daycount::actual360(), today, start, date::blank(), date::blank());
            let hi, hok = daycount::year_fraction(daycount::actual360(), today, pay, date::blank(), date::blank());
            if !lok || !hok { return 0, false; }
            epe[k] = px;
            t_lo[k] = lo;
            t_hi[k] = hi;
            k += 1;
            start = pay;
        }
        i += 1;
    }
    if k == 0 { return 0, false; }
    return k, true;
}

fn node_time(today: date::Date, months: i32) -> f64, bool {
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    let d, ok = calendar::advance(markets::TARGET, today, months, period::MONTHS, calendar::FOLLOWING, false, empty, empty);
    if !ok { return 0.0, false; }
    return daycount::year_fraction(daycount::actual360(), today, d, date::blank(), date::blank());
}

fn survival(hazard: f64[:], t: f64) -> f64, bool {
    if hazard.len != 10 { return 0.0, false; }
    if t <= 0.0 { return 1.0, true; }
    let today, tok = asof();
    if !tok { return 0.0, false; }
    var nodes: f64[10] = [0.0; 10];
    var i: i64 = 0;
    while i < 10 {
        let nt, nok = node_time(today, GRID[i]);
        if !nok { return 0.0, false; }
        nodes[i] = nt;
        i += 1;
    }
    var integral = 0.0;
    i = 0;
    while i < 9 {
        if t <= nodes[i + 1] {
            integral += (t - nodes[i]) * hazard[i + 1];
            return exp(-integral), true;
        }
        integral += (nodes[i + 1] - nodes[i]) * hazard[i + 1];
        i += 1;
    }
    integral += (t - nodes[9]) * hazard[9];
    return exp(-integral), true;
}

fn default_between(hazard: f64[:], t1: f64, t2: f64) -> f64, bool {
    if t1 > t2 { return 0.0, false; }
    var left = t1;
    if left < 0.0 { left = 0.0; }
    let s1, a = survival(hazard, left);
    let s2, b = survival(hazard, t2);
    if !a || !b { return 0.0, false; }
    return s1 - s2, true;
}

fn flat_of(hazard: f64[:]) -> f64, bool {
    if hazard.len == 0 { return 0.0, false; }
    let h = hazard[0];
    var i: i64 = 1;
    while i < hazard.len {
        if hazard[i] != h { return 0.0, false; }
        i += 1;
    }
    return h, true;
}

fn amount(years: i32, hazard: f64[:], recovery: f64) -> f64, bool {
    if hazard.len != 10 || recovery < 0.0 || recovery > 1.0 { return 0.0, false; }
    var i: i64 = 0;
    while i < hazard.len {
        if hazard[i] < 0.0 { return 0.0, false; }
        i += 1;
    }
    var epe: f64[160] = [0.0; 160];
    var t_lo: f64[160] = [0.0; 160];
    var t_hi: f64[160] = [0.0; 160];
    let n, nok = exposure(years, epe, t_lo, t_hi);
    if !nok { return 0.0, false; }
    let lgd = 1.0 - recovery;
    let h, flat = flat_of(hazard);
    var sum = 0.0;
    i = 0;
    while i < n {
        var p = 0.0;
        var pok = true;
        if flat {
            p = exp(-h * t_lo[i]) - exp(-h * t_hi[i]);
        } else {
            let q, qok = default_between(hazard, t_lo[i], t_hi[i]);
            p = q;
            pok = qok;
        }
        if !pok { return 0.0, false; }
        sum += epe[i] * p * lgd;
        i += 1;
    }
    return sum, true;
}
