// Exponential-splines discount fitted to clean bond prices.
// QuantLib ExponentialSplinesFitting, constrained so d(0) = 1, with nine
// coefficients: eight betas and kappa. Betas are linear in the price error,
// so each kappa is one weighted least-squares solve.
// ponytail: simplex is the upgrade if a constraint makes the cost nonlinear.

import math;
import date;
import period;
import daycount;
import calendar;
import markets;
import schedule;
import cash;
import rate;
import solver;

namespace fitted;

const LENGTH: i32[15] = [2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30];
const COUPON: f64[15] = [
    0.0200, 0.0225, 0.0250, 0.0275, 0.0300,
    0.0325, 0.0350, 0.0375, 0.0400, 0.0425,
    0.0450, 0.0475, 0.0500, 0.0525, 0.0550,
];

struct Report {
    settlement: date::Date,
    reference: date::Date,
    evals: i32,
    tenor: f64[15],
    coupon: f64[15],
    par: f64[15],
    clean: f64[15],
    quote: f64[15],
}

struct Best {
    sse: f64,
    kappa: f64,
    c: f64[8],
    evals: i32,
}

fn absf(x: f64) -> f64 {
    if x < 0.0 { return -x; }
    return x;
}

fn blank_report() -> Report {
    Report {
        settlement: date::blank(),
        reference: date::blank(),
        evals: 0,
        tenor: [0.0; 15],
        coupon: [0.0; 15],
        par: [0.0; 15],
        clean: [0.0; 15],
        quote: [0.0; 15],
    }
}

// The C++ example adjusts today's date. 2 November 2026 is a TARGET business
// day, and pinning it keeps the printed par rates from moving with the clock.
fn example_date() -> date::Date, bool {
    let raw, ok = date::from_ymd(2, date::NOVEMBER, 2026);
    if !ok { return date::blank(), false; }
    var hole: i32[1] = [0];
    return calendar::adjust(markets::TARGET, raw, calendar::FOLLOWING, hole[0..0], hole[0..0]);
}

fn bond_schedule(settlement: date::Date, years: i32, sched: i32[:]) -> i32, bool {
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    let maturity, mok = calendar::advance(markets::TARGET, settlement, years, period::YEARS, calendar::FOLLOWING, false, empty, empty);
    if !mok { return 0, false; }
    return schedule::build(settlement, maturity, 1, period::YEARS, markets::TARGET, calendar::MODIFIED_FOLLOWING, calendar::MODIFIED_FOLLOWING, schedule::BACKWARD, false, sched);
}

fn push_bond(settlement: date::Date, years: i32, coupon: f64, dc: daycount::Count, pay: i32[>..]&, amounts: f64[>..]&, times: f64[>..]&, counts: i32[>..]&) -> bool {
    var sched: i32[40] = [0; 40];
    let n, ok = bond_schedule(settlement, years, sched);
    if !ok || n < 2 || sched[0] != settlement.serial { return false; }
    var added: i32 = 0;
    var k: i32 = 1;
    while k < n {
        let start, sok = date::from_serial(sched[(k - 1) as i64]);
        let end, eok = date::from_serial(sched[k as i64]);
        if !sok || !eok { return false; }
        let frac, fok = daycount::year_fraction(dc, start, end, date::blank(), date::blank());
        let t, tok = daycount::year_fraction(dc, settlement, end, date::blank(), date::blank());
        if !fok || !tok || t <= 0.0 { return false; }
        var amount = 100.0 * coupon * frac;
        if k == n - 1 { amount += 100.0; }
        pay.push(end.serial);
        amounts.push(amount);
        times.push(t);
        added += 1;
        k += 1;
    }
    counts.push(added);
    return added > 0;
}

fn bond_yield(pay: i32[:], amounts: f64[:], settlement: i32, dc: daycount::Count, guess: f64) -> f64, bool {
    return solver::brent(guess, 0.0001, 0.75, 1.0e-11, 80) {
        let npv, nok = cash::yield_npv(pay, amounts, settlement, it, rate::COMPOUNDED, period::ANNUAL, dc);
        if nok { npv - 100.0 } else { 1.0 }
    };
}

fn mod_duration(pay: i32[:], amounts: f64[:], settlement: i32, y: f64, dc: daycount::Count) -> f64, bool {
    let price, ok = cash::yield_npv(pay, amounts, settlement, y, rate::COMPOUNDED, period::ANNUAL, dc);
    let up, uok = cash::yield_npv(pay, amounts, settlement, y + 1.0e-5, rate::COMPOUNDED, period::ANNUAL, dc);
    let dn, dok = cash::yield_npv(pay, amounts, settlement, y - 1.0e-5, rate::COMPOUNDED, period::ANNUAL, dc);
    if !ok || !uok || !dok || price == 0.0 { return 0.0, false; }
    return (dn - up) / (2.0e-5 * price), true;
}

fn discount(kappa: f64, c: f64[:], t: f64) -> f64 {
    var sum_c = 0.0;
    var d = 0.0;
    var i: i64 = 0;
    while i < 8 {
        d += c[i] * exp(-kappa * (i + 2) * t);
        sum_c += c[i];
        i += 1;
    }
    return d + (1.0 - sum_c) * exp(-kappa * t);
}

fn basis(kappa: f64, times: f64[:], amounts: f64[:], feat: f64[:]) -> f64, bool {
    if times.len != amounts.len || feat.len < 8 { return 0.0, false; }
    var p0 = 0.0;
    var j: i64 = 0;
    while j < 8 {
        feat[j] = 0.0;
        j += 1;
    }
    var k: i64 = 0;
    while k < times.len {
        let t = times[k];
        let amt = amounts[k];
        let decay = exp(-kappa * t);
        p0 += amt * decay;
        j = 0;
        while j < 8 {
            feat[j] += amt * (exp(-kappa * (j + 2) * t) - decay);
            j += 1;
        }
        k += 1;
    }
    return p0, true;
}

fn solve8(ata: f64[:], atb: f64[:]) -> bool {
    var m: f64[72] = [0.0; 72];
    var row: i64 = 0;
    while row < 8 {
        var col: i64 = 0;
        while col < 8 {
            m[row * 9 + col] = ata[row * 8 + col];
            col += 1;
        }
        m[row * 9 + 8] = atb[row];
        row += 1;
    }
    row = 0;
    while row < 8 {
        var piv = row;
        var rr = row + 1;
        while rr < 8 {
            if absf(m[rr * 9 + row]) > absf(m[piv * 9 + row]) { piv = rr; }
            rr += 1;
        }
        if absf(m[piv * 9 + row]) < 1.0e-18 { return false; }
        if piv != row {
            var col: i64 = 0;
            while col < 9 {
                let tmp = m[row * 9 + col];
                m[row * 9 + col] = m[piv * 9 + col];
                m[piv * 9 + col] = tmp;
                col += 1;
            }
        }
        rr = row + 1;
        while rr < 8 {
            let factor = m[rr * 9 + row] / m[row * 9 + row];
            var col: i64 = row;
            while col < 9 {
                m[rr * 9 + col] -= factor * m[row * 9 + col];
                col += 1;
            }
            rr += 1;
        }
        row += 1;
    }
    var i: i64 = 7;
    while i >= 0 {
        var sum = m[i * 9 + 8];
        var col: i64 = i + 1;
        while col < 8 {
            sum -= m[i * 9 + col] * atb[col];
            col += 1;
        }
        atb[i] = sum / m[i * 9 + i];
        i -= 1;
    }
    return true;
}

fn try_kappa(kappa: f64, times: f64[:], amounts: f64[:], counts: i32[:], quotes: f64[:], weights: f64[:], coeff: f64[:]) -> f64, bool {
    if counts.len != quotes.len || counts.len != weights.len || coeff.len < 8 { return 0.0, false; }
    var scale: f64[8] = [0.0; 8];
    var bond: i64 = 0;
    var cursor: i64 = 0;
    while bond < counts.len {
        let n = counts[bond] as i64;
        let w = weights[bond];
        var feat: f64[8] = [0.0; 8];
        let p0, ok = basis(kappa, times[cursor..cursor + n], amounts[cursor..cursor + n], feat);
        if !ok { return 0.0, false; }
        var j: i64 = 0;
        while j < 8 {
            let v = w * feat[j];
            scale[j] += v * v;
            j += 1;
        }
        cursor += n;
        bond += 1;
    }
    var j: i64 = 0;
    while j < 8 {
        if scale[j] < 1.0e-24 { return 0.0, false; }
        scale[j] = sqrt(scale[j]);
        j += 1;
    }
    var ata: f64[64] = [0.0; 64];
    var atb: f64[8] = [0.0; 8];
    bond = 0;
    cursor = 0;
    while bond < counts.len {
        let n = counts[bond] as i64;
        let w = weights[bond];
        var feat: f64[8] = [0.0; 8];
        let p0, ok = basis(kappa, times[cursor..cursor + n], amounts[cursor..cursor + n], feat);
        if !ok { return 0.0, false; }
        let target = w * (quotes[bond] - p0);
        var row: i64 = 0;
        while row < 8 {
            let fi = w * feat[row] / scale[row];
            atb[row] += fi * target;
            var col: i64 = 0;
            while col < 8 {
                ata[row * 8 + col] += fi * (w * feat[col] / scale[col]);
                col += 1;
            }
            row += 1;
        }
        cursor += n;
        bond += 1;
    }
    if !solve8(ata, atb) { return 0.0, false; }
    var i: i64 = 0;
    while i < 8 {
        coeff[i] = atb[i] / scale[i];
        i += 1;
    }
    let spot = discount(kappa, coeff, 0.0);
    if spot == 0.0 || spot != spot { return 0.0, false; }
    var sse = 0.0;
    bond = 0;
    cursor = 0;
    while bond < counts.len {
        let n = counts[bond] as i64;
        var px = 0.0;
        var k: i64 = 0;
        while k < n {
            px += amounts[cursor + k] * discount(kappa, coeff, times[cursor + k]);
            k += 1;
        }
        px /= spot;
        let err = weights[bond] * (quotes[bond] - px);
        sse += err * err;
        cursor += n;
        bond += 1;
    }
    if sse != sse { return 0.0, false; }
    return sse, true;
}

fn scan(k0: f64, steps: i32, step: f64, times: f64[:], amounts: f64[:], counts: i32[:], quotes: f64[:], weights: f64[:], best: Best) -> Best {
    var cur = best;
    var i: i32 = 0;
    while i <= steps {
        let kappa = k0 + i * step;
        var trial: f64[8] = [0.0; 8];
        let sse, ok = try_kappa(kappa, times, amounts, counts, quotes, weights, trial);
        cur.evals += 1;
        if ok && sse < cur.sse {
            cur.sse = sse;
            cur.kappa = kappa;
            cur.c = trial;
        }
        i += 1;
    }
    return cur;
}

fn par_on(kappa: f64, c: f64[:], settlement: date::Date, sched: i32[:], n: i32, dc: daycount::Count) -> f64, bool {
    if n < 2 { return 0.0, false; }
    var sum = 0.0;
    var i: i32 = 1;
    while i < n {
        let prev, pok = date::from_serial(sched[(i - 1) as i64]);
        let cur, cok = date::from_serial(sched[i as i64]);
        if !pok || !cok { return 0.0, false; }
        let dt, dok = daycount::year_fraction(dc, prev, cur, date::blank(), date::blank());
        let t, tok = daycount::year_fraction(dc, settlement, cur, date::blank(), date::blank());
        if !dok || !tok || dt < 0.0 { return 0.0, false; }
        sum += discount(kappa, c, t) * dt;
        i += 1;
    }
    if sum == 0.0 { return 0.0, false; }
    let front, fok = date::from_serial(sched[0]);
    let back, bok = date::from_serial(sched[(n - 1) as i64]);
    if !fok || !bok { return 0.0, false; }
    let t0, aok = daycount::year_fraction(dc, settlement, front, date::blank(), date::blank());
    let t1, bok2 = daycount::year_fraction(dc, settlement, back, date::blank(), date::blank());
    if !aok || !bok2 { return 0.0, false; }
    return (discount(kappa, c, t0) - discount(kappa, c, t1)) / sum, true;
}

fn model_clean(kappa: f64, c: f64[:], times: f64[:], amounts: f64[:]) -> f64, bool {
    if times.len != amounts.len { return 0.0, false; }
    let spot = discount(kappa, c, 0.0);
    if spot == 0.0 || spot != spot { return 0.0, false; }
    var px = 0.0;
    var i: i64 = 0;
    while i < times.len {
        px += amounts[i] * discount(kappa, c, times[i]);
        i += 1;
    }
    px /= spot;
    if px != px { return 0.0, false; }
    return px, true;
}

fn splines(today: date::Date) -> Report, bool {
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    let settlement, sok = calendar::advance(markets::TARGET, today, 0, period::DAYS, calendar::FOLLOWING, false, empty, empty);
    if !sok { return blank_report(), false; }
    let dc = daycount::make(daycount::SIMPLE);
    var pay: i32[>..] = [];
    var amounts: f64[>..] = [];
    var times: f64[>..] = [];
    var counts: i32[>..] = [];
    var b: i64 = 0;
    while b < 15 {
        if !push_bond(settlement, LENGTH[b], COUPON[b], dc, pay, amounts, times, counts) {
            return blank_report(), false;
        }
        b += 1;
    }
    if counts.len != 15 { return blank_report(), false; }
    var weights: f64[15] = [0.0; 15];
    var quotes: f64[15] = [100.0; 15];
    var cursor: i64 = 0;
    b = 0;
    while b < 15 {
        let n = counts[b] as i64;
        let y, yok = bond_yield(pay[cursor..cursor + n], amounts[cursor..cursor + n], settlement.serial, dc, COUPON[b]);
        let dur, dok = mod_duration(pay[cursor..cursor + n], amounts[cursor..cursor + n], settlement.serial, y, dc);
        if !yok || !dok || dur <= 0.0 { return blank_report(), false; }
        weights[b] = 1.0 / dur;
        cursor += n;
        b += 1;
    }
    var sum_sq = 0.0;
    b = 0;
    while b < 15 {
        sum_sq += weights[b] * weights[b];
        b += 1;
    }
    if sum_sq <= 0.0 { return blank_report(), false; }
    let norm = sqrt(sum_sq);
    b = 0;
    while b < 15 {
        weights[b] /= norm;
        b += 1;
    }
    var best = Best { sse: 1.0e300, kappa: 0.02, c: [0.0; 8], evals: 0 };
    best = scan(0.005, 245, 0.001, times, amounts, counts, quotes, weights, best);
    if best.sse == 1.0e300 { return blank_report(), false; }
    let origin = best.kappa - 0.001;
    best = scan(origin, 40, 0.00005, times, amounts, counts, quotes, weights, best);
    var report = blank_report();
    report.settlement = settlement;
    report.reference = settlement;
    report.evals = best.evals;
    cursor = 0;
    b = 0;
    while b < 15 {
        var sched: i32[40] = [0; 40];
        let n, ok = bond_schedule(settlement, LENGTH[b], sched);
        if !ok { return blank_report(), false; }
        let par, pok = par_on(best.kappa, best.c, settlement, sched, n, dc);
        let last, lok = date::from_serial(sched[(n - 1) as i64]);
        if !pok || !lok { return blank_report(), false; }
        let tenor, tok = daycount::year_fraction(dc, today, last, date::blank(), date::blank());
        if !tok { return blank_report(), false; }
        let count = counts[b] as i64;
        let px, xok = model_clean(best.kappa, best.c, times[cursor..cursor + count], amounts[cursor..cursor + count]);
        if !xok { return blank_report(), false; }
        report.tenor[b] = tenor;
        report.coupon[b] = 100.0 * COUPON[b];
        report.par[b] = 100.0 * par;
        report.clean[b] = px;
        report.quote[b] = quotes[b];
        cursor += count;
        b += 1;
    }
    return report, true;
}

fn month_name(m: i32) -> u8[:] {
    if m == date::JANUARY { return "January"; }
    if m == date::FEBRUARY { return "February"; }
    if m == date::MARCH { return "March"; }
    if m == date::APRIL { return "April"; }
    if m == date::MAY { return "May"; }
    if m == date::JUNE { return "June"; }
    if m == date::JULY { return "July"; }
    if m == date::AUGUST { return "August"; }
    if m == date::SEPTEMBER { return "September"; }
    if m == date::OCTOBER { return "October"; }
    if m == date::NOVEMBER { return "November"; }
    return "December";
}

fn format_ordinal(out: u8[>..]&, n: i32) {
    format(out, n as i64);
    let teen = n % 100;
    if teen >= 11 && teen <= 13 {
        format(out, "th");
        return;
    }
    let last = n % 10;
    if last == 1 { format(out, "st"); return; }
    if last == 2 { format(out, "nd"); return; }
    if last == 3 { format(out, "rd"); return; }
    format(out, "th");
}

fn format_long_date(out: u8[>..]&, d: date::Date) {
    if date::is_blank(d) {
        format(out, "null date");
        return;
    }
    format(out, month_name(date::month(d)));
    format(out, " ");
    format_ordinal(out, date::day_of_month(d));
    format(out, ", ");
    format(out, date::year(d) as i64);
}

fn fixed3(out: u8[>..]&, x: f64) {
    var body: u8[>..] = [];
    format_flt(body, x, 3);
    var spaces = 6 - body.len;
    while spaces > 0 {
        out.push(' ');
        spaces -= 1;
    }
    format(out, body);
}

fn format_report(out: u8[>..]&, report: Report) {
    format(out, "\nToday's date: ");
    format_long_date(out, report.reference);
    format(out, "\nBonds' settlement date: ");
    format_long_date(out, report.settlement);
    format(out, "\nCalculating fit for 15 bonds.....\n\n");
    format(out, "(a) exponential splines\nreference date : ");
    format_long_date(out, report.reference);
    format(out, "\nnumber of iterations : ");
    format(out, report.evals as i64);
    format(out, "\n\nOutput par rates for each curve. In this case, \n");
    format(out, "par rates should equal coupons for these par bonds.\n\n");
    format(out, " tenor | coupon |    (a)\n");
    var i: i64 = 0;
    while i < 15 {
        fixed3(out, report.tenor[i]);
        format(out, " | ");
        fixed3(out, report.coupon[i]);
        format(out, " | ");
        fixed3(out, report.par[i]);
        format(out, "\n");
        i += 1;
    }
}
