import os;
import quant from "..";
import quant.date;
import quant.markets_north;

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

fn in_hol(hol: i32[:], day: i32, m: i32, y: i32) -> bool {
    let key: i32 = y * 10000 + m * 100 + day;
    var i: i64 = 0;
    while i < hol.len {
        if hol[i] == key { return true; }
        i += 1;
    }
    return false;
}

fn check_range(kind: i32, from: date::Date, to: date::Date, hol: i32[:], msg: u8[:]) {
    var serial = from.serial;
    while serial <= to.serial {
        let t, ok = date::from_serial(serial);
        if !ok { fail("serial"); }
        let w = date::weekday(t);
        let weekend = w == date::SATURDAY || w == date::SUNDAY;
        let biz = markets_north::is_business_day(kind, t);
        let listed = in_hol(hol, date::day_of_month(t), date::month(t), date::year(t));
        if weekend && biz { fail(msg); }
        if !weekend && !biz && !listed { fail(msg); }
        if listed && biz { fail(msg); }
        serial += 1;
    }
}

fn holiday(kind: i32, day: i32, m: i32, y: i32, msg: u8[:]) {
    if markets_north::is_business_day(kind, ymd(day, m, y)) { fail(msg); }
}

fn open(kind: i32, day: i32, m: i32, y: i32, msg: u8[:]) {
    if !markets_north::is_business_day(kind, ymd(day, m, y)) { fail(msg); }
}

const DENMARK_HOL: i32[30] = [
    20200101, 20200409, 20200410, 20200413, 20200508, 20200521, 20200522,
    20200601, 20200605, 20201224, 20201225, 20201231,
    20210101, 20210401, 20210402, 20210405, 20210430, 20210513, 20210514,
    20210524, 20211224, 20211231,
    20220414, 20220415, 20220418, 20220513, 20220526, 20220527, 20220606,
    20221226,
];

const UK_HOL: i32[32] = [
    20040101, 20040409, 20040412, 20040503, 20040531, 20040830, 20041227, 20041228,
    20050103, 20050325, 20050328, 20050502, 20050530, 20050829, 20051226, 20051227,
    20060102, 20060414, 20060417, 20060501, 20060529, 20060828, 20061225, 20061226,
    20070101, 20070406, 20070409, 20070507, 20070528, 20070827, 20071225, 20071226,
];

fn ::main() {
    if !markets_north::known(markets_north::DENMARK) { fail("known denmark"); }
    if !markets_north::known(markets_north::FINLAND) { fail("known finland"); }
    if !markets_north::known(markets_north::ICELAND) { fail("known iceland"); }
    if !markets_north::known(markets_north::NORWAY) { fail("known norway"); }
    if !markets_north::known(markets_north::SWEDEN) { fail("known sweden"); }
    if !markets_north::known(markets_north::UK_EXCHANGE) { fail("known exchange"); }
    if !markets_north::known(markets_north::UK_METALS) { fail("known metals"); }
    if markets_north::known(4) { fail("known settlement"); }
    if markets_north::known(99) { fail("known other"); }
    if !markets_north::is_business_day(99, ymd(4, 1, 2020)) { fail("unknown day"); }

    check_range(markets_north::DENMARK, ymd(1, 1, 2020), ymd(31, 12, 2022), DENMARK_HOL, "denmark");
    check_range(markets_north::UK_EXCHANGE, ymd(1, 1, 2004), ymd(31, 12, 2007), UK_HOL, "uk exchange");
    check_range(markets_north::UK_METALS, ymd(1, 1, 2004), ymd(31, 12, 2007), UK_HOL, "uk metals");

    holiday(markets_north::FINLAND, 6, 12, 2024, "finland holiday");
    open(markets_north::FINLAND, 5, 12, 2024, "finland open");
    holiday(markets_north::ICELAND, 17, 6, 2024, "iceland holiday");
    open(markets_north::ICELAND, 18, 6, 2024, "iceland open");
    holiday(markets_north::NORWAY, 17, 5, 2024, "norway holiday");
    open(markets_north::NORWAY, 16, 5, 2024, "norway open");
    holiday(markets_north::SWEDEN, 6, 6, 2024, "sweden holiday");
    open(markets_north::SWEDEN, 7, 6, 2024, "sweden open");

    write_stdout("north ok\n");
}
