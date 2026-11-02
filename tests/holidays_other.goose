import os;
import quant from "..";
import quant.date;
import quant.markets_other;

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
        let off = w == date::SATURDAY || w == date::SUNDAY;
        let biz = markets_other::is_business_day(kind, t);
        let day = date::day_of_month(t);
        let m = date::month(t);
        let y = date::year(t);
        let listed = in_hol(hol, day, m, y);
        if off && biz { fail_ymd(msg, day, m, y); }
        if !off && !biz && !listed { fail_ymd(msg, day, m, y); }
        if listed && biz { fail_ymd(msg, day, m, y); }
        serial += 1;
    }
}

fn tase_off(d: date::Date) -> bool {
    let w = date::weekday(d);
    let n = date::year(d) * 10000 + date::month(d) * 100 + date::day_of_month(d);
    if n >= 20260105 { return w == date::SATURDAY || w == date::SUNDAY; }
    return w == date::FRIDAY || w == date::SATURDAY;
}

fn check_tase(kind: i32, from: date::Date, to: date::Date, hol: i32[:], msg: u8[:]) {
    var serial = from.serial;
    while serial <= to.serial {
        let t, ok = date::from_serial(serial);
        if !ok { fail("serial"); }
        let off = tase_off(t);
        let biz = markets_other::is_business_day(kind, t);
        let day = date::day_of_month(t);
        let m = date::month(t);
        let y = date::year(t);
        let listed = in_hol(hol, day, m, y);
        if off && biz { fail_ymd(msg, day, m, y); }
        if !off && !biz && !listed { fail_ymd(msg, day, m, y); }
        if listed && biz { fail_ymd(msg, day, m, y); }
        serial += 1;
    }
}

fn holiday(kind: i32, day: i32, m: i32, y: i32, msg: u8[:]) {
    if markets_other::is_business_day(kind, ymd(day, m, y)) { fail_ymd(msg, day, m, y); }
}

fn open(kind: i32, day: i32, m: i32, y: i32, msg: u8[:]) {
    if !markets_other::is_business_day(kind, ymd(day, m, y)) { fail_ymd(msg, day, m, y); }
}

const TASE_2013: i32[16] = [
    20130224, 20130325, 20130326, 20130331, 20130401, 20130415, 20130416, 20130514,
    20130515, 20130716, 20130904, 20130905, 20130918, 20130919, 20130925, 20130926,
];
const TASE_2025: i32[13] = [
    20250413, 20250430, 20250501, 20250602, 20250803, 20250923, 20250924, 20251001,
    20251002, 20251006, 20251007, 20251013, 20251014,
];
const SHIR_HOL: i32[60] = [
    20220505, 20220603, 20220926, 20220927, 20221004, 20221005, 20221010, 20221017,
    20221101, 20221226, 20230102, 20230307, 20230308, 20230405, 20230406, 20230407,
    20230410, 20230412, 20230426, 20230526, 20230529, 20230727, 20230915, 20230925,
    20231225, 20231226, 20240101, 20240227, 20240325, 20240329, 20240422, 20240423,
    20240429, 20240514, 20240527, 20240612, 20240813, 20241002, 20241003, 20241004,
    20241011, 20241017, 20241024, 20241225, 20241226, 20250101, 20250314, 20250418,
    20250501, 20250526, 20250602, 20250922, 20250923, 20250924, 20251001, 20251002,
    20251007, 20251014, 20251225, 20251226,
];
const TELBOR_HOL: i32[47] = [
    20220505, 20220530, 20220926, 20220927, 20221005, 20221010, 20221017, 20221226,
    20230307, 20230308, 20230405, 20230406, 20230412, 20230426, 20230526, 20230529,
    20230727, 20230925, 20231225, 20231226, 20240101, 20240325, 20240422, 20240423,
    20240429, 20240514, 20240527, 20240612, 20240813, 20241003, 20241004, 20241017,
    20241024, 20241225, 20241226, 20250101, 20250314, 20250501, 20250526, 20250602,
    20250923, 20250924, 20251002, 20251007, 20251014, 20251225, 20251226,
];
const UZBEK_HOL: i32[13] = [
    20260101, 20260320, 20260527, 20260901, 20261001, 20261208, 20270101, 20270308,
    20270310, 20270517, 20270901, 20271001, 20271208,
];
const SA_2015: i32[10] = [
    20150101, 20150403, 20150406, 20150427, 20150501, 20150616, 20150810, 20150924,
    20151216, 20151225,
];
fn ::main() {
    if markets_other::known(209) || markets_other::known(219) || markets_other::known(250) { fail("unknown kind"); }
    if !markets_other::known(markets_other::ISRAEL_SETTLEMENT) { fail("known"); }
    if !markets_other::known(markets_other::ISRAEL_TASE) { fail("known"); }
    if !markets_other::known(markets_other::ISRAEL_SHIR) { fail("known"); }
    if !markets_other::known(markets_other::ISRAEL_TELBOR) { fail("known"); }
    if !markets_other::known(markets_other::SAUDI_ARABIA) { fail("known"); }
    if !markets_other::known(markets_other::SOUTH_AFRICA) { fail("known"); }
    if !markets_other::known(markets_other::TURKEY) { fail("known"); }
    if !markets_other::known(markets_other::BOTSWANA) { fail("known"); }
    if !markets_other::known(markets_other::UZBEKISTAN) { fail("known"); }
    if !markets_other::is_business_day(999, ymd(7, 2, 2015)) { fail("unknown day"); }

    check_tase(markets_other::ISRAEL_TASE, ymd(1, 1, 2013), ymd(31, 12, 2013), TASE_2013, "tase 2013");
    check_tase(markets_other::ISRAEL_SETTLEMENT, ymd(1, 1, 2013), ymd(31, 12, 2013), TASE_2013, "settlement 2013");
    check_tase(markets_other::ISRAEL_TASE, ymd(1, 1, 2025), ymd(31, 12, 2025), TASE_2025, "tase 2025");
    holiday(markets_other::ISRAEL_TASE, 2, 1, 2026, "tase friday");
    open(markets_other::ISRAEL_TASE, 4, 1, 2026, "tase sunday");
    open(markets_other::ISRAEL_TASE, 9, 1, 2026, "tase friday after");
    holiday(markets_other::ISRAEL_TASE, 11, 1, 2026, "tase sunday after");
    check_range(markets_other::ISRAEL_SHIR, ymd(5, 5, 2022), ymd(31, 12, 2025), SHIR_HOL, "shir");
    check_range(markets_other::ISRAEL_TELBOR, ymd(5, 5, 2022), ymd(31, 12, 2025), TELBOR_HOL, "telbor");

    holiday(markets_other::SAUDI_ARABIA, 23, 2, 2025, "saudi");
    holiday(markets_other::SAUDI_ARABIA, 22, 2, 2026, "saudi");
    holiday(markets_other::SAUDI_ARABIA, 21, 7, 2015, "saudi");
    holiday(markets_other::SAUDI_ARABIA, 22, 9, 2015, "saudi");
    holiday(markets_other::SAUDI_ARABIA, 5, 6, 2025, "saudi");
    holiday(markets_other::SAUDI_ARABIA, 10, 6, 2025, "saudi");
    holiday(markets_other::SAUDI_ARABIA, 20, 3, 2026, "saudi");
    holiday(markets_other::SAUDI_ARABIA, 25, 5, 2026, "saudi");
    open(markets_other::SAUDI_ARABIA, 19, 2, 2026, "saudi");
    open(markets_other::SAUDI_ARABIA, 16, 7, 2015, "saudi");
    open(markets_other::SAUDI_ARABIA, 22, 7, 2015, "saudi");
    open(markets_other::SAUDI_ARABIA, 21, 9, 2015, "saudi");
    open(markets_other::SAUDI_ARABIA, 28, 9, 2015, "saudi");
    open(markets_other::SAUDI_ARABIA, 4, 6, 2025, "saudi");
    open(markets_other::SAUDI_ARABIA, 11, 6, 2025, "saudi");
    open(markets_other::SAUDI_ARABIA, 16, 3, 2026, "saudi");
    open(markets_other::SAUDI_ARABIA, 24, 3, 2026, "saudi");
    open(markets_other::SAUDI_ARABIA, 21, 5, 2026, "saudi");
    open(markets_other::SAUDI_ARABIA, 31, 5, 2026, "saudi");
    holiday(markets_other::SAUDI_ARABIA, 6, 6, 2013, "saudi weekend");
    open(markets_other::SAUDI_ARABIA, 1, 6, 2013, "saudi weekend");
    open(markets_other::SAUDI_ARABIA, 4, 7, 2013, "saudi weekend");
    holiday(markets_other::SAUDI_ARABIA, 6, 7, 2013, "saudi weekend");

    holiday(markets_other::TURKEY, 1, 1, 2024, "turkey");
    holiday(markets_other::TURKEY, 23, 4, 2024, "turkey");
    holiday(markets_other::TURKEY, 1, 5, 2024, "turkey");
    holiday(markets_other::TURKEY, 19, 5, 2024, "turkey");
    holiday(markets_other::TURKEY, 15, 7, 2024, "turkey");
    holiday(markets_other::TURKEY, 30, 8, 2024, "turkey");
    holiday(markets_other::TURKEY, 29, 10, 2024, "turkey");
    open(markets_other::TURKEY, 2, 1, 2024, "turkey");
    holiday(markets_other::TURKEY, 1, 2, 2004, "turkey hist");
    holiday(markets_other::TURKEY, 19, 1, 2005, "turkey hist");
    holiday(markets_other::TURKEY, 10, 1, 2006, "turkey hist");
    holiday(markets_other::TURKEY, 2, 1, 2007, "turkey hist");
    holiday(markets_other::TURKEY, 30, 9, 2008, "turkey hist");
    holiday(markets_other::TURKEY, 20, 9, 2009, "turkey hist");
    holiday(markets_other::TURKEY, 9, 9, 2010, "turkey hist");
    holiday(markets_other::TURKEY, 9, 11, 2011, "turkey hist");
    holiday(markets_other::TURKEY, 18, 8, 2012, "turkey hist");
    holiday(markets_other::TURKEY, 7, 8, 2013, "turkey hist");
    holiday(markets_other::TURKEY, 27, 7, 2014, "turkey hist");
    holiday(markets_other::TURKEY, 17, 7, 2015, "turkey hist");
    holiday(markets_other::TURKEY, 5, 7, 2016, "turkey hist");
    holiday(markets_other::TURKEY, 25, 6, 2017, "turkey hist");
    holiday(markets_other::TURKEY, 15, 6, 2018, "turkey hist");
    holiday(markets_other::TURKEY, 4, 6, 2019, "turkey hist");
    holiday(markets_other::TURKEY, 24, 5, 2020, "turkey hist");
    holiday(markets_other::TURKEY, 13, 5, 2021, "turkey hist");
    holiday(markets_other::TURKEY, 2, 5, 2022, "turkey hist");
    holiday(markets_other::TURKEY, 21, 4, 2023, "turkey hist");
    holiday(markets_other::TURKEY, 10, 4, 2024, "turkey hist");
    holiday(markets_other::TURKEY, 31, 3, 2025, "turkey hist");
    holiday(markets_other::TURKEY, 20, 3, 2026, "turkey hist");

    holiday(markets_other::BOTSWANA, 1, 5, 2024, "botswana");
    open(markets_other::BOTSWANA, 2, 5, 2024, "botswana");

    check_range(markets_other::SOUTH_AFRICA, ymd(1, 1, 2015), ymd(31, 12, 2015), SA_2015, "south africa");
    holiday(markets_other::SOUTH_AFRICA, 14, 4, 2004, "south africa");
    holiday(markets_other::SOUTH_AFRICA, 22, 4, 2009, "south africa");
    holiday(markets_other::SOUTH_AFRICA, 3, 8, 2016, "south africa");
    holiday(markets_other::SOUTH_AFRICA, 1, 11, 2021, "south africa");
    holiday(markets_other::SOUTH_AFRICA, 29, 5, 2024, "south africa");
    holiday(markets_other::SOUTH_AFRICA, 4, 11, 2026, "south africa");
    holiday(markets_other::SOUTH_AFRICA, 27, 12, 2022, "south africa");
    holiday(markets_other::SOUTH_AFRICA, 15, 12, 2023, "south africa");
    holiday(markets_other::SOUTH_AFRICA, 16, 12, 2024, "south africa");
    open(markets_other::SOUTH_AFRICA, 17, 12, 2024, "south africa");

    check_range(markets_other::UZBEKISTAN, ymd(1, 1, 2026), ymd(31, 12, 2027), UZBEK_HOL, "uzbekistan");
    holiday(markets_other::UZBEKISTAN, 20, 3, 2026, "ramazon");
    holiday(markets_other::UZBEKISTAN, 10, 3, 2027, "ramazon");
    holiday(markets_other::UZBEKISTAN, 27, 2, 2028, "ramazon");
    holiday(markets_other::UZBEKISTAN, 15, 2, 2029, "ramazon");
    holiday(markets_other::UZBEKISTAN, 5, 2, 2030, "ramazon");
    holiday(markets_other::UZBEKISTAN, 25, 1, 2031, "ramazon");
    holiday(markets_other::UZBEKISTAN, 14, 1, 2032, "ramazon");
    holiday(markets_other::UZBEKISTAN, 2, 1, 2033, "ramazon");
    holiday(markets_other::UZBEKISTAN, 23, 12, 2033, "ramazon");
    holiday(markets_other::UZBEKISTAN, 12, 12, 2034, "ramazon");
    holiday(markets_other::UZBEKISTAN, 1, 12, 2035, "ramazon");
    holiday(markets_other::UZBEKISTAN, 19, 11, 2036, "ramazon");
    holiday(markets_other::UZBEKISTAN, 27, 5, 2026, "qurbon");
    holiday(markets_other::UZBEKISTAN, 17, 5, 2027, "qurbon");
    holiday(markets_other::UZBEKISTAN, 5, 5, 2028, "qurbon");
    holiday(markets_other::UZBEKISTAN, 24, 4, 2029, "qurbon");
    holiday(markets_other::UZBEKISTAN, 13, 4, 2030, "qurbon");
    holiday(markets_other::UZBEKISTAN, 3, 4, 2031, "qurbon");
    holiday(markets_other::UZBEKISTAN, 22, 3, 2032, "qurbon");
    holiday(markets_other::UZBEKISTAN, 11, 3, 2033, "qurbon");
    holiday(markets_other::UZBEKISTAN, 28, 2, 2034, "qurbon");
    holiday(markets_other::UZBEKISTAN, 18, 2, 2035, "qurbon");
    holiday(markets_other::UZBEKISTAN, 7, 2, 2036, "qurbon");
    holiday(markets_other::UZBEKISTAN, 27, 1, 2037, "qurbon");
    holiday(markets_other::UZBEKISTAN, 16, 1, 2038, "qurbon");
    holiday(markets_other::UZBEKISTAN, 5, 1, 2039, "qurbon");
    holiday(markets_other::UZBEKISTAN, 26, 12, 2039, "qurbon");
    holiday(markets_other::UZBEKISTAN, 15, 12, 2040, "qurbon");

    write_stdout("other ok\n");
}
