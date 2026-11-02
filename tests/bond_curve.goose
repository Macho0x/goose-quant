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

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn near(got: f64, want: f64) -> bool {
    var d = got - want;
    if d < 0.0 { d = -d; }
    return d <= 1.0e-6;
}

fn fill(day: i32, month: i32, year: i32, mat_day: i32, mat_month: i32, mat_year: i32, rate: f64, settlement: date::Date, pay: i32[>..]&, amounts: f64[>..]&) -> f64, bool {
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
    return accrued, pay.len > 0 && pay.len == amounts.len;
}

fn clean_price(pay: i32[:], amounts: f64[:], times: f64[:], discounts: f64[:], settlement: i32, today: i32, dc: daycount::Count, accrued: f64) -> f64, bool {
    let npv, nok = cash::curve_npv(pay, amounts, times, discounts, settlement, today, dc);
    let ref_d, rok = date::from_serial(today);
    let set_d, sok = date::from_serial(settlement);
    if !nok || !rok || !sok { return 0.0, false; }
    let t, tok = daycount::year_fraction(dc, ref_d, set_d, date::blank(), date::blank());
    if !tok { return 0.0, false; }
    let df, dok = curve::log_linear_discount(times, discounts, t);
    if !dok || df == 0.0 { return 0.0, false; }
    return npv / df - accrued, true;
}

fn ::main() {
    let settlement, sok = date::from_ymd(18, date::SEPTEMBER, 2008);
    if !sok { fail("settlement"); }
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    let today, tok = calendar::advance(markets::TARGET, settlement, -3, period::DAYS, calendar::FOLLOWING, false, empty, empty);
    if !tok || today.serial >= settlement.serial { fail("today"); }
    let dc = daycount::actual365_fixed();
    var times: f64[6] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    var discounts: f64[6] = [1.0, 0.5, 0.5, 0.5, 0.5, 0.5];
    var pay: i32[>..] = [];
    var amounts: f64[>..] = [];
    var quotes: f64[5] = [100.390625, 106.21875, 100.59375, 101.6875, 102.140625];
    var rates: f64[5] = [0.02375, 0.04625, 0.03125, 0.04, 0.045];
    var issue_d: i32[5] = [15, 15, 30, 15, 15];
    var issue_m: i32[5] = [date::MARCH, date::JUNE, date::JUNE, date::NOVEMBER, date::MAY];
    // ponytail: the 1987 bond starts at 15 May 2008. Dates before 1901 are outside
    // the serial range, and the remaining coupons stay on the 15 May / 15 Nov grid.
    var issue_y: i32[5] = [2005, 2005, 2006, 2002, 2008];
    var mat_d: i32[5] = [31, 31, 31, 15, 15];
    var mat_m: i32[5] = [date::AUGUST, date::AUGUST, date::AUGUST, date::AUGUST, date::MAY];
    var mat_y: i32[5] = [2010, 2011, 2013, 2018, 2038];
    var i: i64 = 0;
    while i < 5 {
        let accrued, aok = fill(issue_d[i], issue_m[i], issue_y[i], mat_d[i], mat_m[i], mat_y[i], rates[i], settlement, pay, amounts);
        if !aok { fail("schedule"); }
        let maturity, mok = date::from_ymd(mat_d[i], mat_m[i], mat_y[i]);
        if !mok { fail("maturity"); }
        let t, yok = daycount::year_fraction(dc, today, maturity, date::blank(), date::blank());
        if !yok { fail("time"); }
        let used = i + 2;
        times[used - 1] = t;
        let df, fok = cash::fit_clean(pay, amounts, times[0..used], discounts[0..used], settlement.serial, today.serial, dc, quotes[i], accrued, 0.5);
        if !fok || df <= 0.0 { fail("fit clean"); }
        let px, pok = clean_price(pay, amounts, times[0..used], discounts[0..used], settlement.serial, today.serial, dc, accrued);
        if !pok || !near(px, quotes[i]) { fail("reprice"); }
        i += 1;
    }
    write_stdout("bond curve ok\n");
}
