import os;
import quant from "..";
import quant.date;
import quant.markets_west;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn fail_ymd(msg: u8[:], day: i32, m: i32, y: i32) {
    var line: u8[>..] = [];
    format(line, msg);
    format(line, " ");
    format_int(line, day, 10, 2, '0');
    format(line, "-");
    format_int(line, m, 10, 2, '0');
    format(line, "-");
    format_int(line, y, 10, 4, '0');
    format(line, "\n");
    write_stdout(line);
    exit(1);
}

fn ymd(day: i32, m: i32, y: i32) -> date::Date {
    let d, ok = date::from_ymd(day, m, y);
    if !ok { fail("ymd"); }
    return d;
}

fn in_hol(hol: i32[:], day: i32, m: i32, y: i32) -> bool {
    var i: i64 = 0;
    while i + 2 < hol.len {
        if hol[i] == day && hol[i + 1] == m && hol[i + 2] == y { return true; }
        i += 3;
    }
    return false;
}

fn check_holidays(kind: i32, from: date::Date, to: date::Date, hol: i32[:], extra: u8[:], missed: u8[:]) {
    var serial = from.serial;
    while serial <= to.serial {
        let t, ok = date::from_serial(serial);
        if !ok { fail("holiday serial"); }
        let w = date::weekday(t);
        let weekend = w == date::SATURDAY || w == date::SUNDAY;
        let biz = markets_west::is_business_day(kind, t);
        let day = date::day_of_month(t);
        let m = date::month(t);
        let y = date::year(t);
        let listed = in_hol(hol, day, m, y);
        if !weekend && !biz && !listed { fail_ymd(extra, day, m, y); }
        if listed && biz { fail_ymd(missed, day, m, y); }
        serial += 1;
    }
}

fn must_holiday(kind: i32, day: i32, m: i32, y: i32, msg: u8[:]) {
    if markets_west::is_business_day(kind, ymd(day, m, y)) { fail_ymd(msg, day, m, y); }
}

fn must_business(kind: i32, day: i32, m: i32, y: i32, msg: u8[:]) {
    if !markets_west::is_business_day(kind, ymd(day, m, y)) { fail_ymd(msg, day, m, y); }
}

const FRANKFURT_HOL: i32[33] = [
    1, 1, 2003, 18, 4, 2003, 21, 4, 2003, 1, 5, 2003, 24, 12, 2003, 25, 12, 2003, 26, 12, 2003,
    1, 1, 2004, 9, 4, 2004, 12, 4, 2004, 24, 12, 2004,
];

const EUREX_HOL: i32[39] = [
    1, 1, 2003, 18, 4, 2003, 21, 4, 2003, 1, 5, 2003, 24, 12, 2003, 25, 12, 2003, 26, 12, 2003, 31, 12, 2003,
    1, 1, 2004, 9, 4, 2004, 12, 4, 2004, 24, 12, 2004, 31, 12, 2004,
];

const ITALY_2002: i32[72] = [
    1, 1, 2002, 1, 4, 2002, 25, 4, 2002, 1, 5, 2002, 15, 8, 2002, 1, 11, 2002, 25, 12, 2002, 26, 12, 2002,
    1, 1, 2003, 6, 1, 2003, 21, 4, 2003, 25, 4, 2003, 1, 5, 2003, 2, 6, 2003,
    15, 8, 2003, 8, 12, 2003, 25, 12, 2003, 26, 12, 2003,
    1, 1, 2004, 6, 1, 2004, 12, 4, 2004, 2, 6, 2004, 1, 11, 2004, 8, 12, 2004,
];

const ITALY_1999: i32[18] = [
    1, 1, 1999, 6, 1, 1999, 5, 4, 1999, 1, 11, 1999, 8, 12, 1999, 31, 12, 1999,
];

const ITALY_2028: i32[33] = [
    6, 1, 2028, 17, 4, 2028, 25, 4, 2028, 1, 5, 2028, 2, 6, 2028, 15, 8, 2028,
    4, 10, 2028, 1, 11, 2028, 8, 12, 2028, 25, 12, 2028, 26, 12, 2028,
];

fn ::main() {
    if markets_west::known(9) || markets_west::known(22) { fail("unknown kind"); }
    if !markets_west::known(markets_west::GERMANY_SETTLEMENT) { fail("known"); }
    if !markets_west::known(markets_west::ITALY_EXCHANGE) { fail("known"); }
    let sat = ymd(6, 1, 2024);
    if date::weekday(sat) != date::SATURDAY { fail("sat"); }
    if !markets_west::is_business_day(9, sat) { fail("unknown day"); }
    if !markets_west::is_business_day(9, ymd(1, 1, 2024)) { fail("unknown day"); }

    check_holidays(markets_west::GERMANY_FRANKFURT, ymd(1, 1, 2003), ymd(31, 12, 2004), FRANKFURT_HOL, "extra frankfurt", "missed frankfurt");
    check_holidays(markets_west::GERMANY_XETRA, ymd(1, 1, 2003), ymd(31, 12, 2004), FRANKFURT_HOL, "extra xetra", "missed xetra");
    check_holidays(markets_west::GERMANY_EUREX, ymd(1, 1, 2003), ymd(31, 12, 2004), EUREX_HOL, "extra eurex", "missed eurex");

    must_holiday(markets_west::GERMANY_SETTLEMENT, 30, 5, 2024, "settlement corpus");
    must_business(markets_west::GERMANY_FRANKFURT, 30, 5, 2024, "frankfurt corpus");
    must_holiday(markets_west::GERMANY_EUWAX, 20, 5, 2024, "euwax whit");
    must_business(markets_west::GERMANY_XETRA, 20, 5, 2024, "xetra whit");

    check_holidays(markets_west::ITALY_SETTLEMENT, ymd(1, 1, 2002), ymd(31, 12, 2004), ITALY_2002, "extra italy", "missed italy");
    check_holidays(markets_west::ITALY_SETTLEMENT, ymd(1, 1, 1999), ymd(31, 12, 1999), ITALY_1999, "extra italy 1999", "missed italy 1999");
    check_holidays(markets_west::ITALY_SETTLEMENT, ymd(1, 1, 2028), ymd(31, 12, 2028), ITALY_2028, "extra italy 2028", "missed italy 2028");
    must_holiday(markets_west::ITALY_SETTLEMENT, 2, 6, 2025, "italy republic");
    must_business(markets_west::ITALY_EXCHANGE, 2, 6, 2025, "italy exchange republic");

    must_holiday(markets_west::AUSTRIA_SETTLEMENT, 1, 1, 2024, "austria settlement");
    must_holiday(markets_west::AUSTRIA_SETTLEMENT, 1, 5, 2024, "austria settlement");
    must_holiday(markets_west::AUSTRIA_SETTLEMENT, 26, 10, 2024, "austria settlement");
    must_holiday(markets_west::AUSTRIA_EXCHANGE, 29, 3, 2024, "austria exchange");
    must_holiday(markets_west::AUSTRIA_EXCHANGE, 24, 12, 2024, "austria exchange");
    must_business(markets_west::AUSTRIA_EXCHANGE, 2, 1, 2024, "austria exchange");

    must_holiday(markets_west::FRANCE_SETTLEMENT, 1, 1, 2024, "france settlement");
    must_holiday(markets_west::FRANCE_SETTLEMENT, 1, 5, 2024, "france settlement");
    must_holiday(markets_west::FRANCE_SETTLEMENT, 14, 7, 2024, "france settlement");
    must_holiday(markets_west::FRANCE_SETTLEMENT, 9, 5, 2024, "france settlement");
    must_holiday(markets_west::FRANCE_SETTLEMENT, 20, 5, 2024, "france settlement");
    must_holiday(markets_west::FRANCE_SETTLEMENT, 29, 5, 2025, "france settlement");
    must_holiday(markets_west::FRANCE_SETTLEMENT, 9, 6, 2025, "france settlement");
    must_business(markets_west::FRANCE_SETTLEMENT, 10, 5, 2024, "france settlement");
    must_business(markets_west::FRANCE_SETTLEMENT, 21, 5, 2024, "france settlement");
    must_holiday(markets_west::FRANCE_EXCHANGE, 29, 3, 2024, "france exchange");
    must_holiday(markets_west::FRANCE_EXCHANGE, 24, 12, 2024, "france exchange");
    must_business(markets_west::FRANCE_EXCHANGE, 2, 1, 2024, "france exchange");

    must_holiday(markets_west::SWITZERLAND, 1, 1, 2024, "switzerland");
    must_holiday(markets_west::SWITZERLAND, 2, 1, 2024, "switzerland");
    must_holiday(markets_west::SWITZERLAND, 29, 3, 2024, "switzerland");
    must_holiday(markets_west::SWITZERLAND, 1, 5, 2024, "switzerland");
    must_holiday(markets_west::SWITZERLAND, 1, 8, 2024, "switzerland");
    must_business(markets_west::SWITZERLAND, 3, 1, 2024, "switzerland");

    write_stdout("west ok\n");
}
