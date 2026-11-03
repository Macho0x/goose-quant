import os;
import quant from "..";
import quant.credit;
import quant.date;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
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

fn put_ordinal(out: u8[>..]&, n: i32) {
    format(out, n as i64);
    let teen = n % 100;
    if teen >= 11 && teen <= 13 {
        format(out, "th");
        return;
    }
    let last = n % 10;
    if last == 1 {
        format(out, "st");
        return;
    }
    if last == 2 {
        format(out, "nd");
        return;
    }
    if last == 3 {
        format(out, "rd");
        return;
    }
    format(out, "th");
}

fn put_date(out: u8[>..]&, d: date::Date) {
    format(out, month_name(date::month(d)));
    format(out, " ");
    put_ordinal(out, date::day_of_month(d));
    format(out, ", ");
    format(out, date::year(d) as i64);
}

fn show(label: u8[:], x: f64) {
    var line: u8[>..] = [];
    format(line, label);
    format(line, x);
    format(line, "\n");
    write_stdout(line);
}

fn ::main() {
    let curve, ok = credit::calibrate(0.01);
    if !ok { fail("bootstrap"); }
    let today, tok = credit::market_date();
    if !tok { fail("date"); }
    write_stdout("\nCalibrated hazard rate values:\n");
    var i: i64 = 0;
    while i < curve.n {
        let d, dok = date::from_serial(curve.dates[i]);
        if !dok { fail("node"); }
        var line: u8[>..] = [];
        format(line, "hazard rate on ");
        put_date(line, d);
        format(line, " is ");
        format(line, curve.hazard[i]);
        format(line, "\n");
        write_stdout(line);
        i += 1;
    }
    write_stdout("\nSome survival probability values:\n");
    let y1, y1ok = date::plus_years(today, 1);
    let y2, y2ok = date::plus_years(today, 2);
    if !y1ok || !y2ok { fail("tenor"); }
    let s1, s1ok = credit::survival(curve, y1);
    let s2, s2ok = credit::survival(curve, y2);
    if !s1ok || !s2ok { fail("survival"); }
    show("1Y survival probability: ", s1);
    show("               expected: ", 0.9704);
    show("2Y survival probability: ", s2);
    show("               expected: ", 0.9418);
    write_stdout("\n");
}
