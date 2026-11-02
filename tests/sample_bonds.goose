import os;
import quant from "..";
import quant.date;
import quant.period;
import quant.daycount;
import quant.calendar;
import quant.markets;
import quant.schedule;
import quant.cash;
import quant.curve;
import quant.rate;
import quant.solver;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn shows(got: f64, want: f64) -> bool {
    var g = got;
    if g < 0.0 { g = -g; }
    var w = want;
    if w < 0.0 { w = -w; }
    let gc = (g * 100.0 + 0.5) as i32;
    let wc = (w * 100.0 + 0.5) as i32;
    return gc == wc;
}

fn shift(d: date::Date, n: i32) -> date::Date, bool {
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    return calendar::advance(markets::TARGET, d, n, period::DAYS, calendar::FOLLOWING, false, empty, empty);
}

fn adjust(d: date::Date, conv: i32) -> date::Date, bool {
    var hole: i32[1] = [0];
    return calendar::adjust(markets::TARGET, d, conv, hole[0..0], hole[0..0]);
}

fn df_on(times: f64[:], discounts: f64[:], ref: date::Date, d: date::Date) -> f64, bool {
    let t, ok = daycount::year_fraction(daycount::actual365_fixed(), ref, d, date::blank(), date::blank());
    if !ok { return 0.0, false; }
    if t < 0.0 { return curve::log_linear_discount(times, discounts, 0.0); }
    return curve::log_linear_discount(times, discounts, t);
}

fn pv(pay: i32[:], amounts: f64[:], cutoff: i32, ref: date::Date, times: f64[:], discounts: f64[:]) -> f64, bool {
    var sum = 0.0;
    var i: i64 = 0;
    while i < pay.len {
        if pay[i] > cutoff {
            let d, ok = date::from_serial(pay[i]);
            if !ok { return 0.0, false; }
            let df, dok = df_on(times, discounts, ref, d);
            if !dok { return 0.0, false; }
            sum += amounts[i] * df;
        }
        i += 1;
    }
    return sum, true;
}

fn fill_helper(day: i32, month: i32, year: i32, mat_day: i32, mat_month: i32, mat_year: i32, rate: f64, settlement: date::Date, pay: i32[>..]&, amounts: f64[>..]&) -> f64, bool {
    while pay.len > 0 { pay.pop(); }
    while amounts.len > 0 { amounts.pop(); }
    let issue, iok = date::from_ymd(day, month, year);
    let maturity, mok = date::from_ymd(mat_day, mat_month, mat_year);
    if !iok || !mok { return 0.0, false; }
    var sched: i32[>..] = [];
    var nslot: i32 = 0;
    while nslot < 80 {
        sched.push(0);
        nslot += 1;
    }
    let n, ok = schedule::build(issue, maturity, 6, period::MONTHS, markets::TARGET, calendar::UNADJUSTED, calendar::UNADJUSTED, schedule::BACKWARD, false, sched);
    if !ok || n < 2 { return 0.0, false; }
    let isma = daycount::actual_actual_isma();
    var accrued = 0.0;
    var k: i64 = 1;
    let n64 = n as i64;
    while k < n64 {
        let start, sok = date::from_serial(sched[k - 1]);
        let end, eok = date::from_serial(sched[k]);
        if !sok || !eok { return 0.0, false; }
        if settlement.serial > start.serial && settlement.serial < end.serial {
            let yf, yok = daycount::year_fraction(isma, start, settlement, start, end);
            if !yok { return 0.0, false; }
            accrued = 100.0 * rate * yf;
        }
        if end.serial > settlement.serial {
            let yf, yok = daycount::year_fraction(isma, start, end, start, end);
            if !yok { return 0.0, false; }
            var amount = 100.0 * rate * yf;
            if k == n64 - 1 { amount += 100.0; }
            pay.push(end.serial);
            amounts.push(amount);
        }
        k += 1;
    }
    return accrued, pay.len > 0;
}

fn swap_legs(spot: date::Date, years: i32, pay_t: f64[>..]&, taus: f64[>..]&) -> f64, f64, bool {
    while pay_t.len > 0 { pay_t.pop(); }
    while taus.len > 0 { taus.pop(); }
    let end, eok = date::plus_years(spot, years);
    if !eok { return 0.0, 0.0, false; }
    var buf: i32[>..] = [];
    var nslot: i32 = 0;
    while nslot < 40 {
        buf.push(0);
        nslot += 1;
    }
    let nfloat, fok = schedule::build(spot, end, 6, period::MONTHS, markets::TARGET, calendar::MODIFIED_FOLLOWING, calendar::MODIFIED_FOLLOWING, schedule::BACKWARD, false, buf);
    if !fok || nfloat < 2 { return 0.0, 0.0, false; }
    let float_end, okf = date::from_serial(buf[(nfloat - 1) as i64]);
    if !okf { return 0.0, 0.0, false; }
    let curve = daycount::actual365_fixed();
    let end_t, etok = daycount::year_fraction(curve, spot, float_end, date::blank(), date::blank());
    if !etok { return 0.0, 0.0, false; }
    let n, ok = schedule::build(spot, end, 1, period::YEARS, markets::TARGET, calendar::UNADJUSTED, calendar::UNADJUSTED, schedule::BACKWARD, false, buf);
    if !ok || n < 2 { return 0.0, 0.0, false; }
    let euro = daycount::thirty360_euro();
    var k: i64 = 1;
    let n64 = n as i64;
    while k < n64 {
        let a, aok = date::from_serial(buf[k - 1]);
        let b, bok = date::from_serial(buf[k]);
        if !aok || !bok { return 0.0, 0.0, false; }
        let tau, tok = daycount::year_fraction(euro, a, b, date::blank(), date::blank());
        let t, yok = daycount::year_fraction(curve, spot, b, date::blank(), date::blank());
        if !tok || !yok { return 0.0, 0.0, false; }
        taus.push(tau);
        pay_t.push(t);
        k += 1;
    }
    var pillar = end_t;
    if pay_t[pay_t.len - 1] > pillar { pillar = pay_t[pay_t.len - 1]; }
    return pillar, end_t, pay_t.len > 0;
}

fn forward(start: date::Date, end: date::Date, spot: date::Date, times: f64[:], discounts: f64[:]) -> f64, bool {
    let fixing, f1 = shift(start, -2);
    let value, vok = shift(fixing, 2);
    if !f1 || !vok { return 0.0, false; }
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    let index_end, iok = calendar::advance(markets::TARGET, value, 6, period::MONTHS, calendar::MODIFIED_FOLLOWING, true, empty, empty);
    let next_fix, nfk = shift(end, -2);
    let par_end, pok = shift(next_fix, 2);
    if !iok || !nfk || !pok { return 0.0, false; }
    var est = par_end;
    let nxt, nok = date::plus_days(value, 1);
    if nok && est.serial < nxt.serial { est = nxt; }
    let tau, tok = daycount::year_fraction(daycount::actual360(), value, est, date::blank(), date::blank());
    if !tok || tau <= 0.0 { return 0.0, false; }
    let df1, d1 = df_on(times, discounts, spot, value);
    let df2, d2 = df_on(times, discounts, spot, est);
    if !d1 || !d2 || df2 == 0.0 { return 0.0, false; }
    return (df1 / df2 - 1.0) / tau, true;
}

fn num_text(x: f64) -> u8[>..] {
    var s: u8[>..] = [];
    var v = x;
    if v < 0.0 { v = -v; }
    let cents = (v * 100.0 + 0.5) as i32;
    format_int(s, cents / 100, 10, 1, ' ');
    format(s, ".");
    let frac = cents % 100;
    if frac < 10 { format(s, "0"); }
    format_int(s, frac, 10, 1, ' ');
    return s;
}

fn rate_text(x: f64) -> u8[>..] {
    var s = num_text(x * 100.0);
    format(s, " %");
    return s;
}

fn cell(out: u8[>..]&, text: u8[:], width: i64) {
    var padn = width - text.len;
    while padn > 0 {
        out.push(' ');
        padn -= 1;
    }
    format(out, text);
}

fn row(label: u8[:], a: u8[:], b: u8[:], c: u8[:]) {
    var line: u8[>..] = [];
    format(line, label);
    while line.len < 18 { line.push(' '); }
    cell(line, a, 10);
    cell(line, b, 10);
    cell(line, c, 10);
    format(line, "\n");
    write_stdout(line);
}

fn ytm(pay: i32[:], amounts: f64[:], settlement: i32, dirty: f64) -> f64, bool {
    let dc = daycount::actual360();
    return solver::brent(0.04, 0.0001, 0.25, 1.0e-12, 80) {
        let npv, ok = cash::yield_npv(pay, amounts, settlement, it, rate::COMPOUNDED, 1, dc);
        if ok { npv - dirty } else { 1.0 }
    };
}

fn ::main() {
    let settlement, sok = date::from_ymd(18, date::SEPTEMBER, 2008);
    if !sok { fail("settlement"); }
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    let today, tok = calendar::advance(markets::TARGET, settlement, -3, period::DAYS, calendar::FOLLOWING, false, empty, empty);
    let spot, pok = calendar::advance(markets::TARGET, today, 2, period::DAYS, calendar::FOLLOWING, false, empty, empty);
    if !tok || !pok { fail("dates"); }
    let dc = daycount::actual365_fixed();

    var times: f64[6] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    var discounts: f64[6] = [1.0, 0.5, 0.5, 0.5, 0.5, 0.5];
    var pay: i32[>..] = [];
    var amounts: f64[>..] = [];
    var quotes: f64[5] = [100.390625, 106.21875, 100.59375, 101.6875, 102.140625];
    var rates: f64[5] = [0.02375, 0.04625, 0.03125, 0.04, 0.045];
    var issue_d: i32[5] = [15, 15, 30, 15, 15];
    var issue_m: i32[5] = [date::MARCH, date::JUNE, date::JUNE, date::NOVEMBER, date::MAY];
    var issue_y: i32[5] = [2005, 2005, 2006, 2002, 2008];
    var mat_d: i32[5] = [31, 31, 31, 15, 15];
    var mat_m: i32[5] = [date::AUGUST, date::AUGUST, date::AUGUST, date::AUGUST, date::MAY];
    var mat_y: i32[5] = [2010, 2011, 2013, 2018, 2038];
    var i: i64 = 0;
    while i < 5 {
        let accrued, aok = fill_helper(issue_d[i], issue_m[i], issue_y[i], mat_d[i], mat_m[i], mat_y[i], rates[i], settlement, pay, amounts);
        if !aok { fail("bond helper"); }
        let maturity, mok = date::from_ymd(mat_d[i], mat_m[i], mat_y[i]);
        if !mok { fail("maturity"); }
        let t, yok = daycount::year_fraction(dc, today, maturity, date::blank(), date::blank());
        if !yok { fail("time"); }
        let used = i + 2;
        times[used - 1] = t;
        let df, fok = cash::fit_clean(pay, amounts, times[0..used], discounts[0..used], settlement.serial, today.serial, dc, quotes[i], accrued, 0.5);
        if !fok || df <= 0.0 { fail("fit bond"); }
        i += 1;
    }

    let deposit_end, dok = calendar::advance(markets::TARGET, spot, 6, period::MONTHS, calendar::MODIFIED_FOLLOWING, true, empty, empty);
    if !dok { fail("deposit"); }
    let yf, yok = daycount::year_fraction(daycount::actual360(), spot, deposit_end, date::blank(), date::blank());
    let dep_t, dtok = daycount::year_fraction(dc, spot, deposit_end, date::blank(), date::blank());
    if !yok || !dtok { fail("deposit year"); }
    var ftimes: f64[7] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    var fdfs: f64[7] = [1.0, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5];
    ftimes[1] = dep_t;
    fdfs[1] = 1.0 / (1.0 + 0.03385 * yf);
    var syears: i32[5] = [2, 3, 5, 10, 15];
    var squotes: f64[5] = [0.0295, 0.0323, 0.0359, 0.0412, 0.0433];
    var pay_t: f64[>..] = [];
    var taus: f64[>..] = [];
    i = 0;
    while i < 5 {
        let pillar, end_t, lok = swap_legs(spot, syears[i], pay_t, taus);
        if !lok || pillar <= ftimes[i + 1] { fail("swap legs"); }
        let node = i + 2;
        ftimes[node] = pillar;
        let used = node + 1;
        let df, fok = cash::fit_par(pay_t, taus, ftimes[0..used], fdfs[0..used], 0.0, end_t, squotes[i], 0.5);
        if !fok || df <= 0.0 { fail("fit swap"); }
        i += 1;
    }

    let raw, rok = date::from_ymd(15, date::AUGUST, 2013);
    let zpay, zok = adjust(raw, calendar::FOLLOWING);
    if !rok || !zok { fail("zero date"); }
    let zdf, zdok = df_on(times, discounts, today, zpay);
    if !zdok { fail("zero df"); }
    let zc = 116.92 * zdf;
    let set_df0, sd0 = df_on(times, discounts, today, settlement);
    if !sd0 || set_df0 == 0.0 { fail("settlement df"); }
    var zpays: i32[1] = [zpay.serial];
    var zamts: f64[1] = [116.92];
    let zy, zyk = ytm(zpays, zamts, settlement.serial, zc / set_df0);
    if !zyk { fail("zero yield"); }

    let fixed_start, fsok = date::from_ymd(15, date::MAY, 2007);
    let fixed_end, feok = date::from_ymd(15, date::MAY, 2017);
    if !fsok || !feok { fail("fixed dates"); }
    var buf: i32[>..] = [];
    var nslot: i32 = 0;
    while nslot < 20 {
        buf.push(0);
        nslot += 1;
    }
    let n, nok = schedule::build(fixed_start, fixed_end, 1, period::YEARS, markets::TARGET, calendar::UNADJUSTED, calendar::UNADJUSTED, schedule::BACKWARD, false, buf);
    if !nok || n < 2 { fail("fixed schedule"); }
    while pay.len > 0 { pay.pop(); }
    while amounts.len > 0 { amounts.pop(); }
    let isma = daycount::actual_actual_isma();
    var fixed_accrued = 0.0;
    var k: i64 = 1;
    let n64 = n as i64;
    while k < n64 {
        let a, aok = date::from_serial(buf[k - 1]);
        let b, bok = date::from_serial(buf[k]);
        if !aok || !bok { fail("fixed period"); }
        if settlement.serial > a.serial && settlement.serial < b.serial {
            let yfr, yk = daycount::year_fraction(isma, a, settlement, a, b);
            if !yk { fail("fixed accrued"); }
            fixed_accrued = 100.0 * 0.045 * yfr;
        }
        let yf_c, yck = daycount::year_fraction(isma, a, b, a, b);
        let paid, pdk = adjust(b, calendar::MODIFIED_FOLLOWING);
        if !yck || !pdk { fail("fixed coupon"); }
        var amount = 100.0 * 0.045 * yf_c;
        if k == n64 - 1 { amount += 100.0; }
        pay.push(paid.serial);
        amounts.push(amount);
        k += 1;
    }
    let fixed, fxok = pv(pay, amounts, today.serial, today, times, discounts);
    let fixed_set, fsk = pv(pay, amounts, settlement.serial, today, times, discounts);
    let set_df, sdk = df_on(times, discounts, today, settlement);
    if !fxok || !fsk || !sdk || set_df == 0.0 { fail("fixed npv"); }
    let fixed_dirty = fixed_set / set_df;
    let fixed_clean = fixed_dirty - fixed_accrued;
    let fy, fyk = ytm(pay, amounts, settlement.serial, fixed_dirty);
    if !fyk { fail("fixed yield"); }

    let oct07, o7 = date::from_ymd(18, date::OCTOBER, 2007);
    let apr08, a8 = date::from_ymd(17, date::APRIL, 2008);
    if !o7 || !a8 { fail("fixings"); }
    let fl_start, fls = date::from_ymd(21, date::OCTOBER, 2005);
    let fl_end, fle = date::from_ymd(21, date::OCTOBER, 2010);
    if !fls || !fle { fail("float dates"); }
    let nf, fnok = schedule::build(fl_start, fl_end, 6, period::MONTHS, markets::TARGET, calendar::UNADJUSTED, calendar::UNADJUSTED, schedule::BACKWARD, true, buf);
    if !fnok || nf < 2 { fail("float schedule"); }
    while pay.len > 0 { pay.pop(); }
    while amounts.len > 0 { amounts.pop(); }
    var float_accrued = 0.0;
    k = 1;
    let fn64 = nf as i64;
    let act = daycount::actual360();
    while k < fn64 {
        let a, aok = date::from_serial(buf[k - 1]);
        let b, bok = date::from_serial(buf[k]);
        if !aok || !bok { fail("float period"); }
        let fixing, fik = shift(a, -2);
        if !fik { fail("fixing"); }
        var rate = 0.0;
        if fixing.serial == oct07.serial { rate = 0.026; }
        else if fixing.serial == apr08.serial { rate = 0.028; }
        else {
            let fwd, fwk = forward(a, b, spot, ftimes, fdfs);
            if !fwk { fail("forward"); }
            rate = fwd;
        }
        rate += 0.001;
        let tau, tk = daycount::year_fraction(act, a, b, date::blank(), date::blank());
        if !tk { fail("float tau"); }
        if settlement.serial > a.serial && settlement.serial < b.serial {
            let acc_t, atk = daycount::year_fraction(act, a, settlement, date::blank(), date::blank());
            if !atk { fail("float accrued"); }
            float_accrued = 100.0 * rate * acc_t;
        }
        let paid, pdk = adjust(b, calendar::MODIFIED_FOLLOWING);
        if !pdk { fail("float pay"); }
        var amount = 100.0 * rate * tau;
        if k == fn64 - 1 { amount += 100.0; }
        pay.push(paid.serial);
        amounts.push(amount);
        k += 1;
    }
    let floating, flok = pv(pay, amounts, today.serial, today, times, discounts);
    let float_set, flsk = pv(pay, amounts, settlement.serial, today, times, discounts);
    if !flok || !flsk { fail("float npv"); }
    let float_dirty = float_set / set_df;
    let float_clean = float_dirty - float_accrued;
    let fly, flyk = ytm(pay, amounts, settlement.serial, float_dirty);
    if !flyk { fail("float yield"); }
    let zero_dirty = zc / set_df;

    if !shows(zc, 100.92) || !shows(fixed, 107.32) || !shows(floating, 102.85) { fail("npv"); }
    if !shows(fixed_accrued, 1.55) || !shows(float_accrued, 1.21) { fail("accrued"); }
    if !shows(zero_dirty, 100.93) || !shows(fixed_dirty, 107.34) || !shows(float_dirty, 102.87) { fail("dirty"); }
    if !shows(zero_dirty, 100.93) || !shows(fixed_clean, 105.79) || !shows(float_clean, 101.66) { fail("clean"); }
    let zpc = (zy * 10000.0 + 0.5) as i32;
    let fpc = (fy * 10000.0 + 0.5) as i32;
    let lpc = (fly * 10000.0 + 0.5) as i32;
    if zpc != 300 || fpc != 365 || lpc != 220 { fail("yield"); }

    var blank: u8[>..] = [];
    row(blank, "ZC", "Fixed", "Floating");
    var rule: u8[>..] = [];
    var dash: i32 = 0;
    while dash < 48 {
        rule.push('-');
        dash += 1;
    }
    format(rule, "\n");
    write_stdout(rule);
    row("Net present value", num_text(zc), num_text(fixed), num_text(floating));
    row("Clean price", num_text(zero_dirty), num_text(fixed_clean), num_text(float_clean));
    row("Dirty price", num_text(zero_dirty), num_text(fixed_dirty), num_text(float_dirty));
    row("Accrued coupon", num_text(0.0), num_text(fixed_accrued), num_text(float_accrued));
    row("Previous coupon", "N/A", rate_text(0.045), rate_text(0.027));
    row("Next coupon", "N/A", rate_text(0.045), rate_text(0.029));
    row("Yield", rate_text(zy), rate_text(fy), rate_text(fly));
    write_stdout("\n");
    write_stdout("Sample indirect computations (for the floating rate bond):\n");
    write_stdout(rule);
    var tail: u8[>..] = [];
    format(tail, "Yield to Clean Price: ");
    format(tail, num_text(float_clean));
    format(tail, "\nClean Price to Yield: ");
    format(tail, rate_text(fly));
    format(tail, "\n");
    write_stdout(tail);
    write_stdout("sample bonds ok\n");
}
