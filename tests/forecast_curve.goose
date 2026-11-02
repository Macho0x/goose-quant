import os;
import quant from "..";
import quant.date;
import quant.period;
import quant.daycount;
import quant.calendar;
import quant.markets;
import quant.schedule;
import quant.cash;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn near(got: f64, want: f64) -> bool {
    var d = got - want;
    if d < 0.0 { d = -d; }
    return d <= 1.0e-8;
}

fn sched(start: date::Date, end: date::Date, n: i32, unit: i32, conv: i32, out: i32[:]) -> i32, bool {
    return schedule::build(start, end, n, unit, markets::TARGET, conv, conv, schedule::BACKWARD, false, out);
}

fn legs(spot: date::Date, years: i32, pay_t: f64[>..]&, taus: f64[>..]&) -> f64, f64, bool {
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
    let nfloat, fok = sched(spot, end, 6, period::MONTHS, calendar::MODIFIED_FOLLOWING, buf);
    if !fok || nfloat < 2 { return 0.0, 0.0, false; }
    let float_end, okf = date::from_serial(buf[(nfloat - 1) as i64]);
    if !okf { return 0.0, 0.0, false; }
    let curve = daycount::actual365_fixed();
    let end_t, etok = daycount::year_fraction(curve, spot, float_end, date::blank(), date::blank());
    if !etok { return 0.0, 0.0, false; }
    let n, ok = sched(spot, end, 1, period::YEARS, calendar::UNADJUSTED, buf);
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

fn ::main() {
    let settlement, sok = date::from_ymd(18, date::SEPTEMBER, 2008);
    if !sok { fail("settlement"); }
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    let today, tok = calendar::advance(markets::TARGET, settlement, -3, period::DAYS, calendar::FOLLOWING, false, empty, empty);
    let spot, pok = calendar::advance(markets::TARGET, today, 2, period::DAYS, calendar::FOLLOWING, false, empty, empty);
    if !tok || !pok { fail("spot"); }

    let deposit_end, dok = calendar::advance(markets::TARGET, spot, 6, period::MONTHS, calendar::MODIFIED_FOLLOWING, true, empty, empty);
    if !dok { fail("deposit"); }
    let act360 = daycount::actual360();
    let curve = daycount::actual365_fixed();
    let yf, yok = daycount::year_fraction(act360, spot, deposit_end, date::blank(), date::blank());
    let dep_t, dtok = daycount::year_fraction(curve, spot, deposit_end, date::blank(), date::blank());
    if !yok || !dtok || yf <= 0.0 { fail("deposit year"); }
    let dep_df = 1.0 / (1.0 + 0.03385 * yf);
    let forward = (1.0 / dep_df - 1.0) / yf;
    if !near(forward, 0.03385) { fail("deposit rate"); }

    var times: f64[7] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    var discounts: f64[7] = [1.0, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5];
    times[1] = dep_t;
    discounts[1] = dep_df;

    var years: i32[5] = [2, 3, 5, 10, 15];
    var quotes: f64[5] = [0.0295, 0.0323, 0.0359, 0.0412, 0.0433];
    var pay_t: f64[>..] = [];
    var taus: f64[>..] = [];
    var i: i64 = 0;
    while i < 5 {
        let pillar, end_t, lok = legs(spot, years[i], pay_t, taus);
        if !lok || pillar <= times[i + 1] { fail("legs"); }
        let node = i + 2;
        times[node] = pillar;
        let used = node + 1;
        let df, fok = cash::fit_par(pay_t, taus, times[0..used], discounts[0..used], 0.0, end_t, quotes[i], 0.5);
        if !fok || df <= 0.0 { fail("fit"); }
        let par, pok2 = cash::swap_par(pay_t, taus, times[0..used], discounts[0..used], 0.0, end_t);
        if !pok2 || !near(par, quotes[i]) { fail("par"); }
        i += 1;
    }
    write_stdout("forecast curve ok\n");
}
