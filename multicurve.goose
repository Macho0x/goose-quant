// Eonia discount curve and Euribor 6M forecast curve.
// Dates and quotes are MulticurveBootstrapping, 11 December 2012.
// Nodes are log-linear discount factors solved from those quotes.

import date;
import period;
import daycount;
import calendar;
import markets;
import schedule;
import curve;
import cash;
import solver;

namespace multicurve;

fn say(msg: u8[:]) -> bool {
    write_stdout(msg);
    write_stdout("\n");
    return false;
}

fn wipe_f(xs: f64[>..]&) {
    while xs.len > 0 { xs.pop(); }
}

fn wipe_i(xs: i32[>..]&) {
    while xs.len > 0 { xs.pop(); }
}

fn wipe_l(xs: i64[>..]&) {
    while xs.len > 0 { xs.pop(); }
}

fn gap(got: f64, want: f64) -> f64 {
    var d = got - want;
    if d < 0.0 { d = -d; }
    return d;
}

fn tgt_adjust(d: date::Date, conv: i32) -> date::Date, bool {
    var hole: i32[1] = [0];
    return calendar::adjust(markets::TARGET, d, conv, hole[0..0], hole[0..0]);
}

fn tgt_advance(d: date::Date, n: i32, unit: i32, conv: i32, eom: bool) -> date::Date, bool {
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    return calendar::advance(markets::TARGET, d, n, unit, conv, eom, empty, empty);
}

fn time_on(ref_d: date::Date, d: date::Date) -> f64, bool {
    if d.serial < ref_d.serial { return 0.0, false; }
    if d.serial == ref_d.serial { return 0.0, true; }
    return daycount::year_fraction(daycount::actual365_fixed(), ref_d, d, date::blank(), date::blank());
}

fn df_guess(prev: f64, dt: f64, rate: f64) -> f64 {
    var g = prev;
    if dt > 0.0 {
        let den = 1.0 + rate * dt;
        if den > 0.2 { g = prev / den; }
    }
    if g < 0.02 { g = 0.02; }
    if g > 1.4 { g = 1.4; }
    return g;
}

fn put_date(out: u8[>..]&, d: date::Date) {
    format_int(out, date::year(d), 10, 4, '0');
    format(out, "-");
    format_int(out, date::month(d), 10, 2, '0');
    format(out, "-");
    format_int(out, date::day_of_month(d), 10, 2, '0');
}

fn ibor_rate(t0: f64, t1: f64, tau: f64, times: f64[:], dfs: f64[:]) -> f64, bool {
    let df0, a = curve::log_linear_discount(times, dfs, t0);
    let df1, b = curve::log_linear_discount(times, dfs, t1);
    if !a || !b || df1 == 0.0 || tau <= 0.0 { return 0.0, false; }
    return (df0 / df1 - 1.0) / tau, true;
}

fn fit_forward(t0: f64, t1: f64, tau: f64, quote: f64, times: f64[:], dfs: f64[:], guess: f64) -> f64, bool {
    if dfs.len == 0 || times.len != dfs.len { return 0.0, false; }
    let last = dfs.len - 1;
    let df, ok = solver::brent(guess, 1.0e-6, 1.5, 1.0e-14, 160) {
        dfs[last] = it;
        let f, fok = ibor_rate(t0, t1, tau, times, dfs);
        if fok { f - quote } else { 1.0 }
    };
    if ok { dfs[last] = df; }
    return df, ok;
}

fn swap_rate(fix_t: f64[:], fix_tau: f64[:], flt_s: f64[:], flt_e: f64[:], flt_tau: f64[:], flt_pay: f64[:], d_times: f64[:], d_dfs: f64[:], f_times: f64[:], f_dfs: f64[:]) -> f64, bool {
    if fix_t.len == 0 || fix_t.len != fix_tau.len { return 0.0, false; }
    if flt_s.len == 0 || flt_s.len != flt_e.len || flt_s.len != flt_tau.len || flt_s.len != flt_pay.len {
        return 0.0, false;
    }
    var float_pv = 0.0;
    var i: i64 = 0;
    while i < flt_s.len {
        let df0, a = curve::log_linear_discount(f_times, f_dfs, flt_s[i]);
        let df1, b = curve::log_linear_discount(f_times, f_dfs, flt_e[i]);
        let dfd, c = curve::log_linear_discount(d_times, d_dfs, flt_pay[i]);
        if !a || !b || !c || df1 == 0.0 || flt_tau[i] <= 0.0 { return 0.0, false; }
        let fwd = (df0 / df1 - 1.0) / flt_tau[i];
        float_pv += dfd * flt_tau[i] * fwd;
        i += 1;
    }
    var annuity = 0.0;
    i = 0;
    while i < fix_t.len {
        let dfd, c = curve::log_linear_discount(d_times, d_dfs, fix_t[i]);
        if !c { return 0.0, false; }
        annuity += fix_tau[i] * dfd;
        i += 1;
    }
    if annuity == 0.0 { return 0.0, false; }
    return float_pv / annuity, true;
}

fn fit_swap(fix_t: f64[:], fix_tau: f64[:], flt_s: f64[:], flt_e: f64[:], flt_tau: f64[:], flt_pay: f64[:], d_times: f64[:], d_dfs: f64[:], f_times: f64[:], f_dfs: f64[:], quote: f64, guess: f64) -> f64, bool {
    if f_dfs.len == 0 || f_times.len != f_dfs.len { return 0.0, false; }
    let last = f_dfs.len - 1;
    let df, ok = solver::brent(guess, 1.0e-6, 1.5, 1.0e-14, 200) {
        f_dfs[last] = it;
        let par, pok = swap_rate(fix_t, fix_tau, flt_s, flt_e, flt_tau, flt_pay, d_times, d_dfs, f_times, f_dfs);
        if pok { par - quote } else { 1.0 }
    };
    if ok { f_dfs[last] = df; }
    return df, ok;
}

fn sort_up(pillars: i32[:], order: i64[>..]&) {
    wipe_l(order);
    var i: i64 = 0;
    while i < pillars.len {
        order.push(i);
        i += 1;
    }
    i = 1;
    while i < order.len {
        let key = order[i];
        var j = i;
        while j > 0 {
            if pillars[order[j - 1]] <= pillars[key] { break; }
            order[j] = order[j - 1];
            j -= 1;
        }
        order[j] = key;
        i += 1;
    }
}

fn ordered(pillars: i32[:], order: i64[:]) -> bool {
    var i: i64 = 1;
    while i < order.len {
        if pillars[order[i]] <= pillars[order[i - 1]] {
            var line: u8[>..] = [];
            format(line, "pillar ");
            format_int(line, pillars[order[i - 1]], 10, 1, ' ');
            format(line, " ");
            format_int(line, pillars[order[i]], 10, 1, ' ');
            format(line, "\n");
            write_stdout(line);
            return false;
        }
        i += 1;
    }
    return true;
}

fn push_node(times: f64[>..]&, dfs: f64[>..]&, when: i32[>..]&, t: f64, serial: i32, guess: f64) -> bool {
    if times.len == 0 || t <= times[times.len - 1] { return say("node order"); }
    times.push(t);
    dfs.push(guess);
    when.push(serial);
    return true;
}

fn fit_fail(what: u8[:], i: i64, quote: f64) -> bool {
    var line: u8[>..] = [];
    format(line, what);
    format(line, " ");
    format_int(line, i as i32, 10, 1, ' ');
    format(line, " ");
    format(line, quote);
    format(line, "\n");
    write_stdout(line);
    return false;
}

fn quote_line(label: u8[:], quote: f64, got: f64) {
    var line: u8[>..] = [];
    format(line, label);
    format(line, " ");
    format(line, quote);
    format(line, " ");
    format(line, got);
    format(line, "\n");
    write_stdout(line);
}

fn ymd(day: i32, month: i32, year: i32) -> i32, bool {
    let d, ok = date::from_ymd(day, month, year);
    if !ok { return 0, false; }
    return d.serial, true;
}

// kind 0 deposit (a = fixing days), kind 1 tenor OIS (a = length, b = unit),
// kind 2 dated OIS (a = start serial, b = end serial).
fn disc_at(i: i64) -> i32, f64, i32, i32, bool {
    if i < 0 || i >= 30 { return 0, 0.0, 0, 0, false; }
    if i < 3 { return 0, 0.0004, i as i32, 0, true; }
    if i == 3 { return 1, 0.00070, 1, period::WEEKS, true; }
    if i == 4 { return 1, 0.00069, 2, period::WEEKS, true; }
    if i == 5 { return 1, 0.00078, 3, period::WEEKS, true; }
    if i == 6 { return 1, 0.00074, 1, period::MONTHS, true; }
    if i == 7 {
        let a, aok = ymd(16, date::JANUARY, 2013);
        let b, bok = ymd(13, date::FEBRUARY, 2013);
        if !aok || !bok { return 0, 0.0, 0, 0, false; }
        return 2, 0.000460, a, b, true;
    }
    if i == 8 {
        let a, aok = ymd(13, date::FEBRUARY, 2013);
        let b, bok = ymd(13, date::MARCH, 2013);
        if !aok || !bok { return 0, 0.0, 0, 0, false; }
        return 2, 0.000160, a, b, true;
    }
    if i == 9 {
        let a, aok = ymd(13, date::MARCH, 2013);
        let b, bok = ymd(10, date::APRIL, 2013);
        if !aok || !bok { return 0, 0.0, 0, 0, false; }
        return 2, -0.000070, a, b, true;
    }
    if i == 10 {
        let a, aok = ymd(10, date::APRIL, 2013);
        let b, bok = ymd(8, date::MAY, 2013);
        if !aok || !bok { return 0, 0.0, 0, 0, false; }
        return 2, -0.000130, a, b, true;
    }
    if i == 11 {
        let a, aok = ymd(8, date::MAY, 2013);
        let b, bok = ymd(12, date::JUNE, 2013);
        if !aok || !bok { return 0, 0.0, 0, 0, false; }
        return 2, -0.000140, a, b, true;
    }
    var n: i32[18] = [15, 18, 21, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15, 20, 25, 30];
    var unit: i32[18] = [
        period::MONTHS, period::MONTHS, period::MONTHS,
        period::YEARS, period::YEARS, period::YEARS, period::YEARS, period::YEARS,
        period::YEARS, period::YEARS, period::YEARS, period::YEARS, period::YEARS,
        period::YEARS, period::YEARS, period::YEARS, period::YEARS, period::YEARS
    ];
    var q: f64[18] = [
        0.00002, 0.00008, 0.00021, 0.00036, 0.00127, 0.00274, 0.00456, 0.00647,
        0.00827, 0.00996, 0.01147, 0.0128, 0.01404, 0.01516, 0.01764, 0.01939,
        0.02003, 0.02038
    ];
    let k = i - 12;
    return 1, q[k], n[k], unit[k], true;
}

fn raw_bounds(today: date::Date, kind: i32, a: i32, b: i32) -> date::Date, date::Date, bool {
    if kind == 0 {
        let s, sok = tgt_advance(today, a, period::DAYS, calendar::FOLLOWING, false);
        if !sok { return today, today, false; }
        let e, eok = tgt_advance(s, 1, period::DAYS, calendar::FOLLOWING, false);
        if !eok { return today, today, false; }
        return s, e, true;
    }
    if kind == 2 {
        let s, sok = date::from_serial(a);
        let e, eok = date::from_serial(b);
        if !sok || !eok { return today, today, false; }
        return s, e, true;
    }
    let s, sok = tgt_advance(today, 2, period::DAYS, calendar::FOLLOWING, false);
    if !sok { return today, today, false; }
    if b == period::WEEKS {
        let e, eok = date::plus_days(s, a * 7);
        if !eok { return today, today, false; }
        return s, e, true;
    }
    if b == period::MONTHS {
        let e, eok = date::plus_months(s, a);
        if !eok { return today, today, false; }
        return s, e, true;
    }
    let e, eok = date::plus_years(s, a);
    if !eok { return today, today, false; }
    return s, e, true;
}

fn ois_sched(start: date::Date, end: date::Date, buf: i32[>..]&) -> i32, bool {
    wipe_i(buf);
    while buf.len < 80 { buf.push(0); }
    return schedule::build(start, end, 1, period::YEARS, markets::TARGET, calendar::MODIFIED_FOLLOWING, calendar::MODIFIED_FOLLOWING, schedule::BACKWARD, false, buf);
}

fn ois_leg(today: date::Date, start: date::Date, end: date::Date, pay_t: f64[>..]&, taus: f64[>..]&) -> f64, f64, i32, bool {
    wipe_f(pay_t);
    wipe_f(taus);
    var buf: i32[>..] = [];
    let n, ok = ois_sched(start, end, buf);
    if !ok || n < 2 { return 0.0, 0.0, 0, false; }
    let act = daycount::actual360();
    let first, fok = date::from_serial(buf[0]);
    let last_i = (n as i64) - 1;
    let last, lok = date::from_serial(buf[last_i]);
    if !fok || !lok { return 0.0, 0.0, 0, false; }
    let start_t, sok = time_on(today, first);
    let end_t, eok = time_on(today, last);
    if !sok || !eok { return 0.0, 0.0, 0, false; }
    var k: i64 = 1;
    while k <= last_i {
        let a, aok = date::from_serial(buf[k - 1]);
        let b, bok = date::from_serial(buf[k]);
        if !aok || !bok { return 0.0, 0.0, 0, false; }
        let tau, tok = daycount::year_fraction(act, a, b, date::blank(), date::blank());
        let t, yok = time_on(today, b);
        if !tok || !yok || tau <= 0.0 { return 0.0, 0.0, 0, false; }
        taus.push(tau);
        pay_t.push(t);
        k += 1;
    }
    return start_t, end_t, last.serial, true;
}

fn disc_pillar(today: date::Date, kind: i32, a: i32, b: i32) -> i32, bool {
    let s, e, ok = raw_bounds(today, kind, a, b);
    if !ok { return 0, false; }
    if kind == 0 { return e.serial, true; }
    var pay: f64[>..] = [];
    var taus: f64[>..] = [];
    let st, et, serial, lok = ois_leg(today, s, e, pay, taus);
    if !lok || et < st { return 0, false; }
    return serial, true;
}

fn build_discount(today: date::Date, times: f64[>..]&, dfs: f64[>..]&, when: i32[>..]&) -> bool {
    wipe_f(times);
    wipe_f(dfs);
    wipe_i(when);
    times.push(0.0);
    dfs.push(1.0);
    when.push(today.serial);
    var pillars: i32[>..] = [];
    var i: i64 = 0;
    while i < 30 {
        let kind, quote, a, b, ok = disc_at(i);
        if !ok || quote == 0.0 && kind != 2 { return say("disc row"); }
        let pillar, pok = disc_pillar(today, kind, a, b);
        if !pok || pillar <= today.serial { return fit_fail("disc pillar", i, quote); }
        pillars.push(pillar);
        i += 1;
    }
    var order: i64[>..] = [];
    sort_up(pillars, order);
    if !ordered(pillars, order) { return false; }
    var pay_t: f64[>..] = [];
    var taus: f64[>..] = [];
    i = 0;
    while i < order.len {
        let k = order[i];
        let kind, quote, a, b, ok = disc_at(k);
        if !ok { return say("disc row"); }
        let s, e, bok = raw_bounds(today, kind, a, b);
        if !bok { return fit_fail("disc dates", k, quote); }
        if kind == 0 {
            let t0, t0ok = time_on(today, s);
            let t1, t1ok = time_on(today, e);
            let tau, tok = daycount::year_fraction(daycount::actual360(), s, e, date::blank(), date::blank());
            if !t0ok || !t1ok || !tok || tau <= 0.0 { return fit_fail("disc deposit", k, quote); }
            let guess = df_guess(dfs[dfs.len - 1], t1 - times[times.len - 1], quote);
            if !push_node(times, dfs, when, t1, e.serial, guess) { return false; }
            let n = times.len;
            let df, fok = fit_forward(t0, t1, tau, quote, times[0..n], dfs[0..n], guess);
            if !fok || df <= 0.0 { return fit_fail("disc fit", k, quote); }
        } else {
            let start_t, end_t, serial, lok = ois_leg(today, s, e, pay_t, taus);
            if !lok { return fit_fail("disc ois", k, quote); }
            let guess = df_guess(dfs[dfs.len - 1], end_t - times[times.len - 1], quote);
            if !push_node(times, dfs, when, end_t, serial, guess) { return false; }
            let n = times.len;
            let df, fok = cash::fit_par(pay_t, taus, times[0..n], dfs[0..n], start_t, end_t, quote, guess);
            if !fok || df <= 0.0 { return fit_fail("disc fit", k, quote); }
        }
        i += 1;
    }
    return true;
}

fn reprice_discount(today: date::Date, times: f64[:], dfs: f64[:]) -> f64, bool {
    var worst = 0.0;
    var pay_t: f64[>..] = [];
    var taus: f64[>..] = [];
    var i: i64 = 0;
    while i < 30 {
        let kind, quote, a, b, ok = disc_at(i);
        if !ok { return 0.0, say("disc row"); }
        let s, e, bok = raw_bounds(today, kind, a, b);
        if !bok { return 0.0, fit_fail("disc dates", i, quote); }
        var got = 0.0;
        var gok = false;
        if kind == 0 {
            let t0, t0ok = time_on(today, s);
            let t1, t1ok = time_on(today, e);
            let tau, tok = daycount::year_fraction(daycount::actual360(), s, e, date::blank(), date::blank());
            if !t0ok || !t1ok || !tok { return 0.0, fit_fail("disc deposit", i, quote); }
            let f, fok = ibor_rate(t0, t1, tau, times, dfs);
            got = f;
            gok = fok;
            if gok { quote_line("deposit", quote, got); }
        } else {
            let start_t, end_t, serial, lok = ois_leg(today, s, e, pay_t, taus);
            if !lok || serial == 0 { return 0.0, fit_fail("disc ois", i, quote); }
            let par, pok = cash::swap_par(pay_t, taus, times, dfs, start_t, end_t);
            got = par;
            gok = pok;
            if gok { quote_line("ois", quote, got); }
        }
        if !gok { return 0.0, fit_fail("disc quote", i, quote); }
        let err = gap(got, quote);
        if err > worst { worst = err; }
        if err > 1.0e-8 { return err, fit_fail("disc reprice", i, quote); }
        i += 1;
    }
    return worst, true;
}

fn fra_quote(k: i64) -> f64 {
    var q: f64[18] = [
        0.002930, 0.002720, 0.002600, 0.002560, 0.002520, 0.002480, 0.002540, 0.002610, 0.002670,
        0.002790, 0.002910, 0.003030, 0.003180, 0.003350, 0.003520, 0.003710, 0.003890, 0.004090
    ];
    return q[k];
}

fn swap_years(k: i64) -> i32 {
    var y: i32[17] = [3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 30, 35, 40, 50, 60];
    return y[k];
}

fn swap_quote(k: i64) -> f64 {
    var q: f64[17] = [
        0.004240, 0.005760, 0.007620, 0.009540, 0.011350, 0.013030, 0.014520, 0.015840, 0.018090,
        0.020370, 0.021870, 0.022340, 0.022560, 0.022950, 0.023480, 0.024210, 0.024630
    ];
    return q[k];
}

// kind 0: 6M deposit. kind 1: FRA, a = months to start. kind 2: swap, a = years.
fn fore_at(i: i64) -> i32, f64, i32, bool {
    if i == 0 { return 0, 0.00312, 6, true; }
    if i >= 1 && i <= 18 { return 1, fra_quote(i - 1), i as i32, true; }
    if i >= 19 && i < 36 { return 2, swap_quote(i - 19), swap_years(i - 19), true; }
    return 0, 0.0, 0, false;
}

fn deposit6(today: date::Date) -> date::Date, date::Date, f64, bool {
    let start, sok = tgt_advance(today, 3, period::DAYS, calendar::FOLLOWING, false);
    if !sok { return today, today, 0.0, false; }
    let end, eok = tgt_advance(start, 6, period::MONTHS, calendar::FOLLOWING, false);
    if !eok { return today, today, 0.0, false; }
    let tau, tok = daycount::year_fraction(daycount::actual360(), start, end, date::blank(), date::blank());
    if !tok || tau <= 0.0 { return today, today, 0.0, false; }
    return start, end, tau, true;
}

fn fra_span(spot: date::Date, months: i32) -> date::Date, date::Date, f64, bool {
    let start, sok = tgt_advance(spot, months, period::MONTHS, calendar::MODIFIED_FOLLOWING, true);
    if !sok { return spot, spot, 0.0, false; }
    let end, eok = tgt_advance(start, 6, period::MONTHS, calendar::MODIFIED_FOLLOWING, true);
    if !eok { return spot, spot, 0.0, false; }
    let tau, tok = daycount::year_fraction(daycount::actual360(), start, end, date::blank(), date::blank());
    if !tok || tau <= 0.0 { return spot, spot, 0.0, false; }
    return start, end, tau, true;
}

fn swap_leg(today: date::Date, spot: date::Date, years: i32, fix_t: f64[>..]&, fix_tau: f64[>..]&, flt_s: f64[>..]&, flt_e: f64[>..]&, flt_tau: f64[>..]&, flt_pay: f64[>..]&) -> i32, bool {
    wipe_f(fix_t);
    wipe_f(fix_tau);
    wipe_f(flt_s);
    wipe_f(flt_e);
    wipe_f(flt_tau);
    wipe_f(flt_pay);
    let raw, rok = date::plus_years(spot, years);
    if !rok { return 0, false; }
    var fixed: i32[>..] = [];
    var floating: i32[>..] = [];
    while fixed.len < 160 { fixed.push(0); }
    while floating.len < 160 { floating.push(0); }
    let nf, fok = schedule::build(spot, raw, 1, period::YEARS, markets::TARGET, calendar::UNADJUSTED, calendar::UNADJUSTED, schedule::BACKWARD, false, fixed);
    let nu, uok = schedule::build(spot, raw, 6, period::MONTHS, markets::TARGET, calendar::MODIFIED_FOLLOWING, calendar::MODIFIED_FOLLOWING, schedule::BACKWARD, false, floating);
    if !fok || !uok || nf < 2 || nu < 2 { return 0, false; }
    let euro = daycount::thirty360_euro();
    let act = daycount::actual360();
    var k: i64 = 1;
    let nfix = nf as i64;
    while k < nfix {
        let a, aok = date::from_serial(fixed[k - 1]);
        let b, bok = date::from_serial(fixed[k]);
        if !aok || !bok { return 0, false; }
        let pay, pok = tgt_adjust(b, calendar::MODIFIED_FOLLOWING);
        if !pok { return 0, false; }
        let tau, tok = daycount::year_fraction(euro, a, b, date::blank(), date::blank());
        let t, yok = time_on(today, pay);
        if !tok || !yok || tau <= 0.0 { return 0, false; }
        fix_tau.push(tau);
        fix_t.push(t);
        k += 1;
    }
    k = 1;
    let nfloat = nu as i64;
    while k < nfloat {
        let a, aok = date::from_serial(floating[k - 1]);
        let b, bok = date::from_serial(floating[k]);
        if !aok || !bok { return 0, false; }
        let tau, tok = daycount::year_fraction(act, a, b, date::blank(), date::blank());
        let ts, sok = time_on(spot, a);
        let te, eok = time_on(spot, b);
        let tp, pok = time_on(today, b);
        if !tok || !sok || !eok || !pok || tau <= 0.0 { return 0, false; }
        flt_s.push(ts);
        flt_e.push(te);
        flt_tau.push(tau);
        flt_pay.push(tp);
        k += 1;
    }
    return floating[nfloat - 1], true;
}

fn fore_pillar(today: date::Date, spot: date::Date, kind: i32, a: i32) -> i32, bool {
    if kind == 0 {
        let s, e, tau, ok = deposit6(today);
        if !ok || tau <= 0.0 { return 0, false; }
        return e.serial, true;
    }
    if kind == 1 {
        let s, e, tau, ok = fra_span(spot, a);
        if !ok || tau <= 0.0 { return 0, false; }
        return e.serial, true;
    }
    var fix_t: f64[>..] = [];
    var fix_tau: f64[>..] = [];
    var flt_s: f64[>..] = [];
    var flt_e: f64[>..] = [];
    var flt_tau: f64[>..] = [];
    var flt_pay: f64[>..] = [];
    return swap_leg(today, spot, a, fix_t, fix_tau, flt_s, flt_e, flt_tau, flt_pay);
}

fn build_forecast(today: date::Date, spot: date::Date, d_times: f64[:], d_dfs: f64[:], times: f64[>..]&, dfs: f64[>..]&, when: i32[>..]&) -> bool {
    wipe_f(times);
    wipe_f(dfs);
    wipe_i(when);
    times.push(0.0);
    dfs.push(1.0);
    when.push(spot.serial);
    var pillars: i32[>..] = [];
    var i: i64 = 0;
    while i < 36 {
        let kind, quote, a, ok = fore_at(i);
        if !ok { return say("forecast row"); }
        let pillar, pok = fore_pillar(today, spot, kind, a);
        if !pok || pillar <= spot.serial { return fit_fail("forecast pillar", i, quote); }
        pillars.push(pillar);
        i += 1;
    }
    var order: i64[>..] = [];
    sort_up(pillars, order);
    if !ordered(pillars, order) { return false; }
    var fix_t: f64[>..] = [];
    var fix_tau: f64[>..] = [];
    var flt_s: f64[>..] = [];
    var flt_e: f64[>..] = [];
    var flt_tau: f64[>..] = [];
    var flt_pay: f64[>..] = [];
    i = 0;
    while i < order.len {
        let k = order[i];
        let kind, quote, a, ok = fore_at(k);
        if !ok { return say("forecast row"); }
        if kind == 0 {
            let s, e, tau, dok = deposit6(today);
            if !dok { return fit_fail("forecast deposit", k, quote); }
            let t0, t0ok = time_on(spot, s);
            let t1, t1ok = time_on(spot, e);
            if !t0ok || !t1ok { return fit_fail("forecast deposit", k, quote); }
            let guess = df_guess(dfs[dfs.len - 1], t1 - times[times.len - 1], quote);
            if !push_node(times, dfs, when, t1, e.serial, guess) { return false; }
            let n = times.len;
            let df, fok = fit_forward(t0, t1, tau, quote, times[0..n], dfs[0..n], guess);
            if !fok || df <= 0.0 { return fit_fail("forecast fit", k, quote); }
        } else if kind == 1 {
            let s, e, tau, fok0 = fra_span(spot, a);
            if !fok0 { return fit_fail("fra dates", k, quote); }
            let t0, t0ok = time_on(spot, s);
            let t1, t1ok = time_on(spot, e);
            if !t0ok || !t1ok { return fit_fail("fra dates", k, quote); }
            let guess = df_guess(dfs[dfs.len - 1], t1 - times[times.len - 1], quote);
            if !push_node(times, dfs, when, t1, e.serial, guess) { return false; }
            let n = times.len;
            let df, fok = fit_forward(t0, t1, tau, quote, times[0..n], dfs[0..n], guess);
            if !fok || df <= 0.0 { return fit_fail("forecast fit", k, quote); }
        } else {
            let serial, lok = swap_leg(today, spot, a, fix_t, fix_tau, flt_s, flt_e, flt_tau, flt_pay);
            if !lok || flt_e.len == 0 { return fit_fail("swap dates", k, quote); }
            let end_t = flt_e[flt_e.len - 1];
            let guess = df_guess(dfs[dfs.len - 1], end_t - times[times.len - 1], quote);
            if !push_node(times, dfs, when, end_t, serial, guess) { return false; }
            let n = times.len;
            let df, fok = fit_swap(fix_t, fix_tau, flt_s, flt_e, flt_tau, flt_pay, d_times, d_dfs, times[0..n], dfs[0..n], quote, guess);
            if !fok || df <= 0.0 { return fit_fail("forecast fit", k, quote); }
        }
        i += 1;
    }
    return true;
}

fn reprice_forecast(today: date::Date, spot: date::Date, d_times: f64[:], d_dfs: f64[:], times: f64[:], dfs: f64[:]) -> f64, bool {
    var worst = 0.0;
    var fix_t: f64[>..] = [];
    var fix_tau: f64[>..] = [];
    var flt_s: f64[>..] = [];
    var flt_e: f64[>..] = [];
    var flt_tau: f64[>..] = [];
    var flt_pay: f64[>..] = [];
    var i: i64 = 0;
    while i < 36 {
        let kind, quote, a, ok = fore_at(i);
        if !ok { return 0.0, say("forecast row"); }
        var got = 0.0;
        var gok = false;
        if kind == 0 {
            let s, e, tau, dok = deposit6(today);
            if !dok { return 0.0, fit_fail("forecast deposit", i, quote); }
            let t0, t0ok = time_on(spot, s);
            let t1, t1ok = time_on(spot, e);
            if !t0ok || !t1ok { return 0.0, fit_fail("forecast deposit", i, quote); }
            let f, fok = ibor_rate(t0, t1, tau, times, dfs);
            got = f;
            gok = fok;
            if gok { quote_line("deposit", quote, got); }
        } else if kind == 1 {
            let s, e, tau, fok0 = fra_span(spot, a);
            if !fok0 { return 0.0, fit_fail("fra dates", i, quote); }
            let t0, t0ok = time_on(spot, s);
            let t1, t1ok = time_on(spot, e);
            if !t0ok || !t1ok { return 0.0, fit_fail("fra dates", i, quote); }
            let f, fok = ibor_rate(t0, t1, tau, times, dfs);
            if !fok { return 0.0, fit_fail("fra quote", i, quote); }
            let amt, aok = cash::fra_amount(1.0, f, quote, tau, true);
            if !aok || gap(amt, 0.0) > 1.0e-8 { return 0.0, fit_fail("fra amount", i, quote); }
            got = f;
            gok = true;
            quote_line("fra", quote, got);
        } else {
            let serial, lok = swap_leg(today, spot, a, fix_t, fix_tau, flt_s, flt_e, flt_tau, flt_pay);
            if !lok || serial == 0 { return 0.0, fit_fail("swap dates", i, quote); }
            let par, pok = swap_rate(fix_t, fix_tau, flt_s, flt_e, flt_tau, flt_pay, d_times, d_dfs, times, dfs);
            got = par;
            gok = pok;
            if gok { quote_line("swap", quote, got); }
        }
        if !gok { return 0.0, fit_fail("forecast quote", i, quote); }
        let err = gap(got, quote);
        if err > worst { worst = err; }
        if err > 1.0e-8 { return err, fit_fail("forecast reprice", i, quote); }
        i += 1;
    }
    return worst, true;
}

fn print_nodes(label: u8[:], when: i32[:], dfs: f64[:]) {
    var i: i64 = 0;
    while i < when.len && i < dfs.len {
        var line: u8[>..] = [];
        format(line, label);
        format(line, " ");
        let d, ok = date::from_serial(when[i]);
        if ok { put_date(line, d); }
        format(line, " ");
        format(line, dfs[i]);
        format(line, "\n");
        write_stdout(line);
        i += 1;
    }
}

fn verify() -> bool {
    let today, tok = date::from_ymd(11, date::DECEMBER, 2012);
    if !tok { return say("today"); }
    let spot, sok = tgt_advance(today, 2, period::DAYS, calendar::FOLLOWING, false);
    if !sok { return say("settlement"); }
    var head: u8[>..] = [];
    format(head, "Today ");
    put_date(head, today);
    format(head, "\nSettlement ");
    put_date(head, spot);
    format(head, "\n");
    write_stdout(head);

    var d_t: f64[>..] = [];
    var d_df: f64[>..] = [];
    var d_when: i32[>..] = [];
    if !build_discount(today, d_t, d_df, d_when) { return false; }
    let e1, ok1 = reprice_discount(today, d_t, d_df);
    if !ok1 { return false; }

    var f_t: f64[>..] = [];
    var f_df: f64[>..] = [];
    var f_when: i32[>..] = [];
    if !build_forecast(today, spot, d_t, d_df, f_t, f_df, f_when) { return false; }
    let e2, ok2 = reprice_forecast(today, spot, d_t, d_df, f_t, f_df);
    if !ok2 { return false; }

    print_nodes("discount", d_when, d_df);
    print_nodes("forecast", f_when, f_df);
    var tail: u8[>..] = [];
    format(tail, "max ");
    var worst = e1;
    if e2 > worst { worst = e2; }
    format(tail, worst);
    format(tail, "\nmulticurve ok\n");
    write_stdout(tail);
    return true;
}
