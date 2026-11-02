import os;
import quant from "..";
import quant.date;
import quant.calendar;
import quant.period;
import quant.markets_other;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn fail_case(id: i32, got: i32, want: i32) {
    var line: u8[>..] = [];
    format(line, "case ");
    format_int(line, id, 10, 1, ' ');
    format(line, " got ");
    format_int(line, got, 10, 1, ' ');
    format(line, " want ");
    format_int(line, want, 10, 1, ' ');
    format(line, "\n");
    write_stdout(line);
    exit(1);
}

fn ymd(day: i32, m: i32, y: i32) -> date::Date {
    let d, ok = date::from_ymd(day, m, y);
    if !ok { fail("ymd"); }
    return d;
}

fn one(id: i32, conv: i32, day: i32, m: i32, y: i32, n: i32, unit: i32, eom: bool, rd: i32, rm: i32, ry: i32) {
    var hole: i32[1] = [0];
    let start = ymd(day, m, y);
    let want = ymd(rd, rm, ry);
    let got, ok = calendar::advance(markets_other::SOUTH_AFRICA, start, n, unit, conv, eom, hole[0..0], hole[0..0]);
    if !ok || got.serial != want.serial { fail_case(id, got.serial, want.serial); }
}

fn ::main() {

    one(0, calendar::FOLLOWING, 3, 2, 2015, 1, period::MONTHS, false, 3, 3, 2015);
    one(1, calendar::FOLLOWING, 3, 2, 2015, 4, period::DAYS, false, 9, 2, 2015);
    one(2, calendar::FOLLOWING, 31, 1, 2015, 1, period::MONTHS, true, 27, 2, 2015);
    one(3, calendar::FOLLOWING, 31, 1, 2015, 1, period::MONTHS, false, 2, 3, 2015);
    one(4, calendar::MODIFIED_FOLLOWING, 3, 2, 2015, 1, period::MONTHS, false, 3, 3, 2015);
    one(5, calendar::MODIFIED_FOLLOWING, 3, 2, 2015, 4, period::DAYS, false, 9, 2, 2015);
    one(6, calendar::MODIFIED_FOLLOWING, 31, 1, 2015, 1, period::MONTHS, true, 27, 2, 2015);
    one(7, calendar::MODIFIED_FOLLOWING, 31, 1, 2015, 1, period::MONTHS, false, 27, 2, 2015);
    one(8, calendar::MODIFIED_FOLLOWING, 25, 3, 2015, 1, period::MONTHS, false, 28, 4, 2015);
    one(9, calendar::MODIFIED_FOLLOWING, 7, 2, 2015, 1, period::MONTHS, false, 9, 3, 2015);
    one(10, calendar::PRECEDING, 3, 3, 2015, -1, period::MONTHS, false, 3, 2, 2015);
    one(11, calendar::PRECEDING, 3, 2, 2015, -2, period::DAYS, false, 30, 1, 2015);
    one(12, calendar::PRECEDING, 1, 3, 2015, -1, period::MONTHS, true, 30, 1, 2015);
    one(13, calendar::PRECEDING, 1, 3, 2015, -1, period::MONTHS, false, 30, 1, 2015);
    one(14, calendar::MODIFIED_PRECEDING, 3, 3, 2015, -1, period::MONTHS, false, 3, 2, 2015);
    one(15, calendar::MODIFIED_PRECEDING, 3, 2, 2015, -2, period::DAYS, false, 30, 1, 2015);
    one(16, calendar::MODIFIED_PRECEDING, 1, 3, 2015, -1, period::MONTHS, true, 2, 2, 2015);
    one(17, calendar::MODIFIED_PRECEDING, 1, 3, 2015, -1, period::MONTHS, false, 2, 2, 2015);
    one(18, calendar::UNADJUSTED, 3, 2, 2015, 1, period::MONTHS, false, 3, 3, 2015);
    one(19, calendar::UNADJUSTED, 3, 2, 2015, 4, period::DAYS, false, 9, 2, 2015);
    one(20, calendar::UNADJUSTED, 31, 1, 2015, 1, period::MONTHS, true, 28, 2, 2015);
    one(21, calendar::UNADJUSTED, 30, 1, 2015, 1, period::MONTHS, true, 28, 2, 2015);
    one(22, calendar::UNADJUSTED, 27, 2, 2015, 1, period::MONTHS, true, 27, 3, 2015);
    one(23, calendar::UNADJUSTED, 31, 1, 2015, 1, period::MONTHS, false, 28, 2, 2015);
    one(24, calendar::HALF_MONTH_MODIFIED_FOLLOWING, 3, 2, 2015, 1, period::MONTHS, false, 3, 3, 2015);
    one(25, calendar::HALF_MONTH_MODIFIED_FOLLOWING, 3, 2, 2015, 4, period::DAYS, false, 9, 2, 2015);
    one(26, calendar::HALF_MONTH_MODIFIED_FOLLOWING, 31, 1, 2015, 1, period::MONTHS, true, 27, 2, 2015);
    one(27, calendar::HALF_MONTH_MODIFIED_FOLLOWING, 31, 1, 2015, 1, period::MONTHS, false, 27, 2, 2015);
    one(28, calendar::HALF_MONTH_MODIFIED_FOLLOWING, 3, 1, 2015, 1, period::WEEKS, false, 12, 1, 2015);
    one(29, calendar::HALF_MONTH_MODIFIED_FOLLOWING, 21, 3, 2015, 1, period::WEEKS, false, 30, 3, 2015);
    one(30, calendar::HALF_MONTH_MODIFIED_FOLLOWING, 7, 2, 2015, 1, period::MONTHS, false, 9, 3, 2015);
    one(31, calendar::NEAREST, 3, 2, 2015, 1, period::MONTHS, false, 3, 3, 2015);
    one(32, calendar::NEAREST, 3, 2, 2015, 4, period::DAYS, false, 9, 2, 2015);
    one(33, calendar::NEAREST, 16, 4, 2015, 1, period::MONTHS, false, 15, 5, 2015);
    one(34, calendar::NEAREST, 17, 4, 2015, 1, period::MONTHS, false, 18, 5, 2015);
    one(35, calendar::NEAREST, 4, 3, 2015, 1, period::MONTHS, false, 2, 4, 2015);
    one(36, calendar::NEAREST, 2, 4, 2015, 1, period::MONTHS, false, 4, 5, 2015);
    write_stdout("conventions ok\n");
}
