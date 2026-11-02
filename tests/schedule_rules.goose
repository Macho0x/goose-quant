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

fn cds_dates(trade: date::Date, termination: date::Date, out: i32[:]) -> i32, bool {
    return schedule::build_cds(trade, termination, 3, period::MONTHS, markets::WEEKENDS, calendar::FOLLOWING, calendar::UNADJUSTED, out);
}

fn ::main() {
    var out: i32[32] = [0; 32];

    let trade = ymd(18, 9, 2015);
    let maturity, mok = schedule::cds_maturity(trade, 1, period::YEARS);
    if !mok { fail("maturity 18 Sep 2015"); }
    if maturity.serial != ymd(20, 9, 2016).serial { fail("maturity 18 Sep 2015"); }
    let n, ok = cds_dates(trade, maturity, out);
    if !ok { fail("cds 18 Sep 2015"); }
    var want6: i32[6] = [0; 6];
    want6[0] = ymd(22, 6, 2015).serial;
    want6[1] = ymd(21, 9, 2015).serial;
    want6[2] = ymd(21, 12, 2015).serial;
    want6[3] = ymd(21, 3, 2016).serial;
    want6[4] = ymd(20, 6, 2016).serial;
    want6[5] = ymd(20, 9, 2016).serial;
    expect(out, n, want6);

    let trade19 = ymd(19, 9, 2015);
    let mat19, m19ok = schedule::cds_maturity(trade19, 1, period::YEARS);
    if !m19ok { fail("maturity 19 Sep 2015"); }
    let n19, ok19 = cds_dates(trade19, mat19, out);
    if !ok19 { fail("cds 19 Sep 2015"); }
    expect(out, n19, want6);

    let trade20 = ymd(20, 9, 2015);
    let mat20, m20ok = schedule::cds_maturity(trade20, 1, period::YEARS);
    if !m20ok { fail("maturity 20 Sep 2015"); }
    if mat20.serial != ymd(20, 12, 2016).serial { fail("maturity 20 Sep 2015"); }
    let n20, ok20 = cds_dates(trade20, mat20, out);
    if !ok20 { fail("cds 20 Sep 2015"); }
    var want7: i32[7] = [0; 7];
    want7[0] = ymd(22, 6, 2015).serial;
    want7[1] = ymd(21, 9, 2015).serial;
    want7[2] = ymd(21, 12, 2015).serial;
    want7[3] = ymd(21, 3, 2016).serial;
    want7[4] = ymd(20, 6, 2016).serial;
    want7[5] = ymd(20, 9, 2016).serial;
    want7[6] = ymd(20, 12, 2016).serial;
    expect(out, n20, want7);

    let trade21 = ymd(21, 9, 2015);
    let mat21, m21ok = schedule::cds_maturity(trade21, 1, period::YEARS);
    if !m21ok { fail("maturity 21 Sep 2015"); }
    if mat21.serial != ymd(20, 12, 2016).serial { fail("maturity 21 Sep 2015"); }
    let n21, ok21 = cds_dates(trade21, mat21, out);
    if !ok21 { fail("cds 21 Sep 2015"); }
    var want_drop: i32[6] = [0; 6];
    want_drop[0] = ymd(21, 9, 2015).serial;
    want_drop[1] = ymd(21, 12, 2015).serial;
    want_drop[2] = ymd(21, 3, 2016).serial;
    want_drop[3] = ymd(20, 6, 2016).serial;
    want_drop[4] = ymd(20, 9, 2016).serial;
    want_drop[5] = ymd(20, 12, 2016).serial;
    expect(out, n21, want_drop);

    let trade09 = ymd(20, 6, 2009);
    let end09 = ymd(20, 12, 2009);
    let n09, ok09 = cds_dates(trade09, end09, out);
    if !ok09 { fail("cds 20 Jun 2009"); }
    var want09: i32[4] = [0; 4];
    want09[0] = ymd(20, 3, 2009).serial;
    want09[1] = ymd(22, 6, 2009).serial;
    want09[2] = ymd(21, 9, 2009).serial;
    want09[3] = ymd(20, 12, 2009).serial;
    expect(out, n09, want09);

    let trade21jun = ymd(21, 6, 2009);
    let n21jun, ok21jun = cds_dates(trade21jun, end09, out);
    if !ok21jun { fail("cds 21 Jun 2009"); }
    expect(out, n21jun, want09);

    let trade22 = ymd(22, 6, 2009);
    let n22, ok22 = cds_dates(trade22, end09, out);
    if !ok22 { fail("cds 22 Jun 2009"); }
    var want22: i32[3] = [0; 3];
    want22[0] = ymd(22, 6, 2009).serial;
    want22[1] = ymd(21, 9, 2009).serial;
    want22[2] = ymd(20, 12, 2009).serial;
    expect(out, n22, want22);

    write_stdout("schedule rules ok\n");
}
