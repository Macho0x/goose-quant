// Midpoint CDS bootstrap for the QuantLib CDS example.
// Quarterly TwentiethIMM schedules, spread quotes, backward-flat hazard.
// Node 0 is the reference date. Its hazard is copied from the first pillar.
// ponytail: one solve per pillar. The pillar is the last coupon payment, so a
// later quote does not move an earlier hazard.

import math;
import date;
import calendar;
import markets;
import schedule;
import solver;

namespace credit;

const RECOVERY: f64 = 0.5;
const SPREAD: f64 = 0.015;
const MONTHS: i32[4] = [3, 6, 12, 24];

struct Curve {
    n: i64,
    asof: i32,
    dates: i32[8],
    times: f64[8],
    hazard: f64[8],
}

fn blank_curve() -> Curve {
    Curve {
        n: 0,
        asof: 0,
        dates: [0; 8],
        times: [0.0; 8],
        hazard: [0.0; 8],
    }
}

fn market_date() -> date::Date, bool {
    let raw, ok = date::from_ymd(15, date::MAY, 2007);
    if !ok { return date::blank(), false; }
    return schedule::adjusted(markets::TARGET, raw, calendar::FOLLOWING);
}

fn act365(a: i32, b: i32) -> f64 {
    return (b - a) / 365.0;
}

fn imm_schedule(effective: date::Date, termination: date::Date, out: i32[:]) -> i64, bool {
    if date::is_blank(effective) || date::is_blank(termination) { return 0, false; }
    if effective.serial >= termination.serial || out.len < 2 { return 0, false; }

    var dates: i32[24] = [0; 24];
    dates[0] = effective.serial;
    var n: i64 = 1;
    let next20, nok = schedule::next_twentieth(effective);
    if !nok { return 0, false; }
    var seed = effective;
    if next20.serial != effective.serial {
        dates[n] = next20.serial;
        n += 1;
        seed = next20;
    }

    var periods: i32 = 1;
    while periods < 40 {
        let temp, tok = date::plus_months(seed, periods * 3);
        if !tok { return 0, false; }
        if temp.serial > termination.serial { break; }
        let back, bok = date::from_serial(dates[n - 1]);
        if !bok { return 0, false; }
        let adj_back, abok = schedule::adjusted(markets::TARGET, back, calendar::FOLLOWING);
        let adj_temp, atok = schedule::adjusted(markets::TARGET, temp, calendar::FOLLOWING);
        if !abok || !atok { return 0, false; }
        if adj_back.serial != adj_temp.serial {
            if n >= 24 { return 0, false; }
            dates[n] = temp.serial;
            n += 1;
        }
        periods += 1;
    }

    let last, lok = date::from_serial(dates[n - 1]);
    if !lok { return 0, false; }
    if last.serial != termination.serial {
        let extra, eok = schedule::next_twentieth(termination);
        if !eok || n >= 24 { return 0, false; }
        dates[n] = extra.serial;
        n += 1;
    }

    let front, fok = date::from_serial(dates[0]);
    let adj0, a0 = schedule::adjusted(markets::TARGET, front, calendar::FOLLOWING);
    if !fok || !a0 { return 0, false; }
    dates[0] = adj0.serial;

    var k: i64 = 1;
    while k < n - 1 {
        let cur, cok = date::from_serial(dates[k]);
        let adj, aok = schedule::adjusted(markets::TARGET, cur, calendar::FOLLOWING);
        if !cok || !aok { return 0, false; }
        dates[k] = adj.serial;
        k += 1;
    }

    if n >= 2 && dates[n - 2] >= dates[n - 1] {
        dates[n - 2] = dates[n - 1];
        n -= 1;
    }
    if n >= 2 && dates[1] <= dates[0] {
        var t: i64 = 0;
        while t < n - 1 {
            dates[t] = dates[t + 1];
            t += 1;
        }
        n -= 1;
    }
    if n < 2 || n > out.len { return 0, false; }
    var c: i64 = 0;
    while c < n {
        out[c] = dates[c];
        c += 1;
    }
    return n, true;
}

fn deal_dates(asof: date::Date, months: i32) -> date::Date, date::Date, date::Date, bool {
    let protection, pok = date::plus_days(asof, 1);
    if !pok { return date::blank(), date::blank(), date::blank(), false; }
    let start, sok = schedule::adjusted(markets::TARGET, protection, calendar::FOLLOWING);
    if !sok { return date::blank(), date::blank(), date::blank(), false; }
    let termination, tok = date::plus_months(protection, months);
    if !tok { return date::blank(), date::blank(), date::blank(), false; }
    return protection, start, termination, true;
}

fn pillar_of(start: date::Date, termination: date::Date) -> date::Date, bool {
    var sched: i32[24] = [0; 24];
    let n, ok = imm_schedule(start, termination, sched);
    if !ok || n < 2 { return date::blank(), false; }
    let last, lok = date::from_serial(sched[n - 1]);
    if !lok { return date::blank(), false; }
    return schedule::adjusted(markets::TARGET, last, calendar::FOLLOWING);
}

fn hazard_integral(times: f64[:], hazard: f64[:], nodes: i64, t: f64) -> f64 {
    if nodes <= 0 { return 0.0; }
    if nodes == 1 { return (t - times[0]) * hazard[0]; }
    if t <= times[0] { return 0.0; }
    let last = nodes - 1;
    if t >= times[last] {
        var prim = 0.0;
        var i: i64 = 1;
        while i <= last {
            prim += (times[i] - times[i - 1]) * hazard[i];
            i += 1;
        }
        return prim + hazard[last] * (t - times[last]);
    }
    var i: i64 = 0;
    while i < last && times[i + 1] <= t { i += 1; }
    var prim = 0.0;
    var k: i64 = 1;
    while k <= i {
        prim += (times[k] - times[k - 1]) * hazard[k];
        k += 1;
    }
    prim += (t - times[i]) * hazard[i + 1];
    return prim;
}

fn survival_time(asof: i32, serial: i32, times: f64[:], hazard: f64[:], nodes: i64) -> f64, bool {
    if nodes <= 0 || serial < asof { return 0.0, false; }
    let t = act365(asof, serial);
    return exp(-hazard_integral(times, hazard, nodes, t)), true;
}

fn survival(curve: Curve, d: date::Date) -> f64, bool {
    if date::is_blank(d) { return 0.0, false; }
    return survival_time(curve.asof, d.serial, curve.times, curve.hazard, curve.n);
}

fn par_spread(curve: Curve&, protection: date::Date, start: date::Date, termination: date::Date, discount: f64) -> f64, bool {
    let today, tok = date::from_serial(curve.asof);
    if !tok || curve.n < 1 { return 0.0, false; }
    var sched: i32[24] = [0; 24];
    let n, ok = imm_schedule(start, termination, sched);
    if !ok || n < 2 { return 0.0, false; }

    var premium = 0.0;
    var protect = 0.0;
    var i: i64 = 0;
    while i < n - 1 {
        let accrual_start = sched[i];
        let accrual_end = sched[i + 1];
        let end_d, eok = date::from_serial(accrual_end);
        if !eok { return 0.0, false; }
        let pay, pok = schedule::adjusted(markets::TARGET, end_d, calendar::FOLLOWING);
        if !pok { return 0.0, false; }
        if pay.serial > today.serial {
            var prot = accrual_start;
            if i == 0 { prot = protection.serial; }
            var eff = prot;
            if prot <= today.serial && today.serial <= accrual_end { eff = today.serial; }
            let mid = eff + (accrual_end - eff) / 2;
            let s_pay, spok = survival_time(curve.asof, pay.serial, curve.times, curve.hazard, curve.n);
            let s_eff, seok = survival_time(curve.asof, eff, curve.times, curve.hazard, curve.n);
            let s_end, snok = survival_time(curve.asof, accrual_end, curve.times, curve.hazard, curve.n);
            if !spok || !seok || !snok { return 0.0, false; }
            let p = s_eff - s_end;
            let y = act365(accrual_start, accrual_end);
            premium += s_pay * y * exp(-discount * act365(curve.asof, pay.serial));
            var accrued = 0.0;
            if mid > accrual_start && mid <= pay.serial {
                var stop = mid;
                if stop > accrual_end { stop = accrual_end; }
                accrued = act365(accrual_start, stop);
            }
            let df_mid = exp(-discount * act365(curve.asof, mid));
            premium += p * accrued * df_mid;
            protect += p * (1.0 - RECOVERY) * df_mid;
        }
        i += 1;
    }
    if premium <= 0.0 { return 0.0, false; }
    return protect / premium, true;
}

fn solve_pillar(curve: Curve&, idx: i64, protection: date::Date, start: date::Date, termination: date::Date, discount: f64) -> bool {
    let guess = curve.hazard[idx - 1];
    if guess <= 1.0e-4 || guess >= 0.5 { return false; }
    let root, ok = solver::brent(guess, 1.0e-4, 0.5, 1.0e-12, 80) {
        curve.hazard[idx] = it;
        let fair, fok = par_spread(curve, protection, start, termination, discount);
        if fok { fair - SPREAD } else { 1.0 }
    };
    if !ok { return false; }
    curve.hazard[idx] = root;
    if idx == 1 { curve.hazard[0] = root; }
    return true;
}

fn calibrate(discount: f64) -> Curve, bool {
    let today, tok = market_date();
    if !tok || discount < 0.0 { return blank_curve(), false; }
    var curve = blank_curve();
    curve.n = 1;
    curve.asof = today.serial;
    curve.dates[0] = today.serial;
    curve.times[0] = 0.0;
    curve.hazard[0] = 0.01;

    var i: i64 = 0;
    while i < 4 {
        let protection, start, termination, dok = deal_dates(today, MONTHS[i]);
        if !dok { return blank_curve(), false; }
        let pillar, pok = pillar_of(start, termination);
        if !pok || pillar.serial <= curve.dates[curve.n - 1] { return blank_curve(), false; }
        let idx = curve.n;
        if idx >= 8 { return blank_curve(), false; }
        curve.dates[idx] = pillar.serial;
        curve.times[idx] = act365(curve.asof, pillar.serial);
        curve.hazard[idx] = curve.hazard[idx - 1];
        curve.n = idx + 1;
        if !solve_pillar(curve, idx, protection, start, termination, discount) {
            return blank_curve(), false;
        }
        i += 1;
    }
    return curve, true;
}
