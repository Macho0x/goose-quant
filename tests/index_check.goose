import os;
import quant from "..";
import quant.date;
import quant.period;
import quant.calendar;
import quant.index;

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

fn same(got: date::Date, ok: bool, day: i32, m: i32, y: i32) {
    let want = ymd(day, m, y);
    if !ok || got.serial != want.serial {
        var line: u8[>..] = [];
        format(line, "got ");
        format_int(line, got.serial, 10, 1, ' ');
        format(line, " want ");
        format_int(line, want.serial, 10, 1, ' ');
        format(line, "\n");
        write_stdout(line);
        exit(1);
    }
}

fn ::main() {
    let jan = date::JANUARY;
    let apr = date::APRIL;
    let feb = date::FEBRUARY;
    let may = date::MAY;
    var fix_off: i32[1] = [ymd(8, jan, 2025).serial];
    var val_off: i32[1] = [ymd(21, jan, 2025).serial];
    var mat_off: i32[4] = [ymd(7, jan, 2025).serial, ymd(15, jan, 2025).serial, ymd(23, apr, 2025).serial, ymd(30, apr, 2025).serial];
    let days: i32 = 2;

    let v1, o1 = index::value_date(ymd(7, jan, 2025), days, fix_off, val_off, mat_off);
    same(v1, o1, 9, jan, 2025);
    let v2, o2 = index::value_date(ymd(13, jan, 2025), days, fix_off, val_off, mat_off);
    same(v2, o2, 16, jan, 2025);
    let v3, o3 = index::value_date(ymd(20, jan, 2025), days, fix_off, val_off, mat_off);
    same(v3, o3, 23, jan, 2025);
    let bad, bok = index::value_date(ymd(8, jan, 2025), days, fix_off, val_off, mat_off);
    if bok || !date::is_blank(bad) { fail("invalid fixing"); }

    let f1, f1ok = index::fixing_date(ymd(23, jan, 2025), days, fix_off, val_off);
    same(f1, f1ok, 20, jan, 2025);
    let f2, f2ok = index::fixing_date(ymd(16, jan, 2025), days, fix_off, val_off);
    same(f2, f2ok, 14, jan, 2025);
    let f3, f3ok = index::fixing_date(ymd(10, jan, 2025), days, fix_off, val_off);
    same(f3, f3ok, 7, jan, 2025);

    let m1, m1ok = index::maturity_date(ymd(23, jan, 2025), 3, period::MONTHS, calendar::MODIFIED_FOLLOWING, true, mat_off);
    same(m1, m1ok, 24, apr, 2025);
    let m2, m2ok = index::maturity_date(ymd(30, jan, 2025), 3, period::MONTHS, calendar::MODIFIED_FOLLOWING, true, mat_off);
    same(m2, m2ok, 29, apr, 2025);
    let m3, m3ok = index::maturity_date(ymd(28, feb, 2025), 3, period::MONTHS, calendar::MODIFIED_FOLLOWING, true, mat_off);
    same(m3, m3ok, 31, may, 2025);

    write_stdout("index ok\n");
}
