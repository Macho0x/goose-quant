import os;
import quant from "..";
import quant.date;
import quant.period;
import quant.daycount;
import quant.calendar;
import quant.markets;
import quant.curve;
import quant.solver;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn months(d: date::Date, n: i32) -> date::Date, bool {
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    return calendar::advance(markets::TARGET, d, n, period::MONTHS, calendar::MODIFIED_FOLLOWING, true, empty, empty);
}

fn days(d: date::Date, n: i32) -> date::Date, bool {
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    return calendar::advance(markets::TARGET, d, n, period::DAYS, calendar::FOLLOWING, false, empty, empty);
}

fn forward(t0: f64, t1: f64, tau: f64, times: f64[:], discounts: f64[:]) -> f64, bool {
    let df0, a = curve::log_linear_discount(times, discounts, t0);
    let df1, b = curve::log_linear_discount(times, discounts, t1);
    if !a || !b || df1 == 0.0 || tau <= 0.0 { return 0.0, false; }
    return (df0 / df1 - 1.0) / tau, true;
}

fn fit(t0: f64, t1: f64, tau: f64, quote: f64, times: f64[:], discounts: f64[:]) -> f64, bool {
    let last = discounts.len - 1;
    let df, ok = solver::brent(0.9, 0.0001, 1.2, 1.0e-12, 80) {
        discounts[last] = it;
        let f, fok = forward(t0, t1, tau, times, discounts);
        if fok { f - quote } else { 1.0 }
    };
    if ok { discounts[last] = df; }
    return df, ok;
}

fn amount(forward_rate: f64, strike: f64, tau: f64) -> f64 {
    return 100.0 * (forward_rate - strike) * tau / (1.0 + forward_rate * tau);
}

fn line(label: u8[:], x: f64) {
    var s: u8[>..] = [];
    format(s, label);
    format(s, x);
    format(s, "\n");
    write_stdout(s);
}

fn ::main() {
    let today, tok = date::from_ymd(23, date::MAY, 2006);
    if !tok { fail("today"); }
    let spot, sok = days(today, 2);
    if !sok { fail("spot"); }
    let isda = daycount::actual_actual_isda();
    let act = daycount::actual360();
    var months_to: i32[5] = [1, 2, 3, 6, 9];
    var quotes: f64[5] = [0.030, 0.031, 0.032, 0.033, 0.034];
    var t0s: f64[5] = [0.0, 0.0, 0.0, 0.0, 0.0];
    var t1s: f64[5] = [0.0, 0.0, 0.0, 0.0, 0.0];
    var taus: f64[5] = [0.0, 0.0, 0.0, 0.0, 0.0];
    var i: i64 = 0;
    while i < 5 {
        let start, aok = months(spot, months_to[i]);
        if !aok { fail("start"); }
        let end, eok = months(start, 3);
        if !eok { fail("end"); }
        let tau, uok = daycount::year_fraction(act, start, end, date::blank(), date::blank());
        let a, bok = daycount::year_fraction(isda, spot, start, date::blank(), date::blank());
        let b, cok = daycount::year_fraction(isda, spot, end, date::blank(), date::blank());
        if !uok || !bok || !cok || tau <= 0.0 || b <= a { fail("fra dates"); }
        t0s[i] = a;
        t1s[i] = b;
        taus[i] = tau;
        i += 1;
    }

    var times: f64[6] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    var discounts: f64[6] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0];
    i = 0;
    while i < 5 {
        if i > 0 && t1s[i] <= times[i] { fail("pillar order"); }
        let node = i + 1;
        times[node] = t1s[i];
        let used = node + 1;
        let df, ok = fit(t0s[i], t1s[i], taus[i], quotes[i], times[0..used], discounts[0..used]);
        if !ok || df <= 0.0 { fail("fit"); }
        i += 1;
    }

    write_stdout("\nTest FRA construction, NPV calculation, and FRA purchase\n\n");
    i = 0;
    while i < 5 {
        let f, fok = forward(t0s[i], t1s[i], taus[i], times, discounts);
        if !fok { fail("forward"); }
        let amt = amount(f, quotes[i], taus[i]);
        let df0, dok = curve::log_linear_discount(times, discounts, t0s[i]);
        if !dok { fail("df"); }
        let npv = amt * df0;
        var d = amt;
        if d < 0.0 { d = -d; }
        var n = npv;
        if n < 0.0 { n = -n; }
        if d > 1.0e-8 || n > 1.0e-8 { fail("unshifted"); }
        var head: u8[>..] = [];
        format(head, "3m Term FRA, Months to Start: ");
        format_int(head, months_to[i], 10, 1, ' ');
        format(head, "\n");
        write_stdout(head);
        line("strike FRA rate: ", quotes[i]);
        line("FRA 3m forward rate: ", f);
        line("FRA amount [should be zero]: ", amt);
        line("FRA NPV [should be zero]: ", npv);
        write_stdout("\n");
        i += 1;
    }

    write_stdout("Now take a 100 basis-point upward shift in FRA quotes and examine NPV\n\n");
    var bumped: f64[5] = [0.040, 0.041, 0.042, 0.043, 0.044];
    i = 0;
    while i < 6 {
        discounts[i] = 1.0;
        i += 1;
    }
    i = 0;
    while i < 5 {
        let node = i + 1;
        times[node] = t1s[i];
        let used = node + 1;
        let df, ok = fit(t0s[i], t1s[i], taus[i], bumped[i], times[0..used], discounts[0..used]);
        if !ok || df <= 0.0 { fail("refit"); }
        i += 1;
    }
    i = 0;
    while i < 5 {
        let f, fok = forward(t0s[i], t1s[i], taus[i], times, discounts);
        if !fok { fail("shifted forward"); }
        let strike = quotes[i];
        let amt = amount(f, strike, taus[i]);
        let df0, dok = curve::log_linear_discount(times, discounts, t0s[i]);
        if !dok { fail("shifted df"); }
        let npv = amt * df0;
        if amt <= 0.0 || npv <= 0.0 { fail("shifted"); }
        var head: u8[>..] = [];
        format(head, "3m Term FRA, 100 notional, Months to Start = ");
        format_int(head, months_to[i], 10, 1, ' ');
        format(head, "\n");
        write_stdout(head);
        line("strike FRA rate: ", strike);
        line("FRA 3m forward rate: ", f);
        line("FRA amount [should be positive]: ", amt);
        line("FRA NPV [should be positive]: ", npv);
        write_stdout("\n");
        i += 1;
    }
}
