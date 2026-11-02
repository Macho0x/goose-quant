import os;
import quant from "..";
import quant.date;
import quant.period;
import quant.calendar;
import quant.markets;
import quant.schedule;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ymd(day: i32, m: i32, y: i32) -> date::Date {
    let d, ok = date::from_ymd(day, m, y);
    if !ok { fail("ymd"); }
    return d;
}

fn expect(got: i32[:], n: i32, want: i32[:]) {
    if n != want.len as i32 { fail("count"); }
    var i: i64 = 0;
    while i < want.len {
        if got[i] != want[i] { fail("date"); }
        i += 1;
    }
}

fn ::main() {
    var out: i32[32] = [0; 32];
    let start = ymd(17, 1, 2012);
    let end, eok = date::plus_days(start, 7);
    if !eok { fail("plus"); }
    let n, ok = schedule::build(start, end, 1, period::DAYS, markets::TARGET, calendar::PRECEDING, calendar::PRECEDING, schedule::BACKWARD, false, out);
    if !ok { fail("daily"); }
    var daily: i32[6] = [0; 6];
    daily[0] = ymd(17, 1, 2012).serial;
    daily[1] = ymd(18, 1, 2012).serial;
    daily[2] = ymd(19, 1, 2012).serial;
    daily[3] = ymd(20, 1, 2012).serial;
    daily[4] = ymd(23, 1, 2012).serial;
    daily[5] = ymd(24, 1, 2012).serial;
    expect(out, n, daily);

    let from = ymd(29, 2, 2024);
    let to, tok = date::plus_years(from, 1);
    if !tok { fail("year"); }
    let n1, ok1 = schedule::build(from, to, 1, period::MONTHS, markets::TARGET, calendar::UNADJUSTED, calendar::UNADJUSTED, schedule::BACKWARD, true, out);
    if !ok1 { fail("eom"); }
    var eom: i32[13] = [0; 13];
    eom[0] = ymd(29, 2, 2024).serial;
    eom[1] = ymd(31, 3, 2024).serial;
    eom[2] = ymd(30, 4, 2024).serial;
    eom[3] = ymd(31, 5, 2024).serial;
    eom[4] = ymd(30, 6, 2024).serial;
    eom[5] = ymd(31, 7, 2024).serial;
    eom[6] = ymd(31, 8, 2024).serial;
    eom[7] = ymd(30, 9, 2024).serial;
    eom[8] = ymd(31, 10, 2024).serial;
    eom[9] = ymd(30, 11, 2024).serial;
    eom[10] = ymd(31, 12, 2024).serial;
    eom[11] = ymd(31, 1, 2025).serial;
    eom[12] = ymd(28, 2, 2025).serial;
    expect(out, n1, eom);

    let n2, ok2 = schedule::build(from, to, 1, period::MONTHS, markets::TARGET, calendar::FOLLOWING, calendar::FOLLOWING, schedule::BACKWARD, true, out);
    if !ok2 { fail("eom following"); }
    var followed: i32[14] = [0; 14];
    followed[0] = ymd(29, 2, 2024).serial;
    followed[1] = ymd(2, 4, 2024).serial;
    followed[2] = ymd(30, 4, 2024).serial;
    followed[3] = ymd(31, 5, 2024).serial;
    followed[4] = ymd(1, 7, 2024).serial;
    followed[5] = ymd(31, 7, 2024).serial;
    followed[6] = ymd(2, 9, 2024).serial;
    followed[7] = ymd(30, 9, 2024).serial;
    followed[8] = ymd(31, 10, 2024).serial;
    followed[9] = ymd(2, 12, 2024).serial;
    followed[10] = ymd(31, 12, 2024).serial;
    followed[11] = ymd(31, 1, 2025).serial;
    followed[12] = ymd(28, 2, 2025).serial;
    expect(out, n2, followed[0..13]);

    write_stdout("schedule ok\n");
}
