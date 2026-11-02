import os;
import quant from "..";
import quant.date;
import quant.markets_seasia;

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
        let weekend = w == date::SATURDAY || w == date::SUNDAY;
        let biz = markets_seasia::is_business_day(kind, t);
        let day = date::day_of_month(t);
        let m = date::month(t);
        let y = date::year(t);
        let listed = in_hol(hol, day, m, y);
        if weekend && biz { fail_ymd(msg, day, m, y); }
        if !weekend && !biz && !listed { fail_ymd(msg, day, m, y); }
        if listed && biz { fail_ymd(msg, day, m, y); }
        serial += 1;
    }
}

fn holiday(kind: i32, day: i32, m: i32, y: i32, msg: u8[:]) {
    if markets_seasia::is_business_day(kind, ymd(day, m, y)) { fail_ymd(msg, day, m, y); }
}

fn open(kind: i32, day: i32, m: i32, y: i32, msg: u8[:]) {
    if !markets_seasia::is_business_day(kind, ymd(day, m, y)) { fail_ymd(msg, day, m, y); }
}

fn each_holiday(day: i32, m: i32, y: i32, msg: u8[:]) {
    holiday(markets_seasia::INDONESIA_BEJ, day, m, y, msg);
    holiday(markets_seasia::INDONESIA_JSX, day, m, y, msg);
    holiday(markets_seasia::INDONESIA_IDX, day, m, y, msg);
}

fn each_open(day: i32, m: i32, y: i32, msg: u8[:]) {
    open(markets_seasia::INDONESIA_BEJ, day, m, y, msg);
    open(markets_seasia::INDONESIA_JSX, day, m, y, msg);
    open(markets_seasia::INDONESIA_IDX, day, m, y, msg);
}

const MALAYSIA_HOL: i32[32] = [
    // 2024
    20240101, 20240125, 20240201, 20240212, 20240328, 20240410, 20240411, 20240501,
    20240522, 20240603, 20240617, 20240708, 20240916, 20241031, 20241225,
    // 2025
    20250101, 20250129, 20250130, 20250211, 20250318, 20250331, 20250401, 20250501,
    20250512, 20250602, 20250627, 20250901, 20250905, 20250915, 20250916, 20251020,
    20251225,
];

const PHILIPPINES_HOL: i32[53] = [
    // 2024
    20240101, 20240209, 20240328, 20240329, 20240409, 20240410, 20240501, 20240612,
    20240617, 20240724, 20240823, 20240826, 20241101, 20241224, 20241225, 20241230,
    20241231,
    // 2025
    20250101, 20250129, 20250401, 20250409, 20250417, 20250418, 20250501, 20250512,
    20250606, 20250612, 20250821, 20250825, 20251031, 20251208, 20251224, 20251225,
    20251230, 20251231,
    // 2026
    20260101, 20260217, 20260320, 20260402, 20260403, 20260409, 20260501, 20260527,
    20260612, 20260821, 20260831, 20261102, 20261130, 20261208, 20261224, 20261225,
    20261230, 20261231,
];

const INDIA_HOL: i32[20] = [
    // 2026
    20260115, 20260126, 20260219, 20260303, 20260319, 20260326, 20260331, 20260401,
    20260403, 20260414, 20260501, 20260528, 20260626, 20260826, 20260914, 20261002,
    20261020, 20261110, 20261124, 20261225,
];

fn ::main() {
    if markets_seasia::known(179) || markets_seasia::known(210) { fail("unknown kind"); }
    if !markets_seasia::known(markets_seasia::INDIA_NSE) { fail("known india"); }
    if !markets_seasia::known(markets_seasia::INDONESIA_BEJ) { fail("known bej"); }
    if !markets_seasia::known(markets_seasia::INDONESIA_JSX) { fail("known jsx"); }
    if !markets_seasia::known(markets_seasia::INDONESIA_IDX) { fail("known idx"); }
    if !markets_seasia::known(markets_seasia::MALAYSIA_KLSE) { fail("known malaysia"); }
    if !markets_seasia::known(markets_seasia::PHILIPPINES_PSE) { fail("known philippines"); }
    if !markets_seasia::known(markets_seasia::SINGAPORE_SGX) { fail("known singapore"); }
    if !markets_seasia::known(markets_seasia::THAILAND) { fail("known thailand"); }
    if !markets_seasia::is_business_day(179, ymd(1, 1, 2024)) { fail("unknown day"); }

    // testIndonesiaCalendar
    each_holiday(1, 1, 2024, "indonesia");
    each_holiday(29, 3, 2024, "indonesia");
    each_holiday(1, 5, 2024, "indonesia");
    each_holiday(1, 6, 2024, "indonesia");
    each_holiday(17, 8, 2024, "indonesia");
    each_holiday(25, 12, 2024, "indonesia");
    each_holiday(21, 1, 2005, "indonesia");
    each_open(2, 1, 2024, "indonesia");
    each_holiday(9, 2, 2005, "indonesia hist");
    each_holiday(11, 3, 2005, "indonesia hist");
    each_holiday(24, 5, 2005, "indonesia hist");
    each_holiday(10, 1, 2006, "indonesia hist");
    each_holiday(30, 3, 2006, "indonesia hist");
    each_holiday(24, 10, 2006, "indonesia hist");
    each_holiday(19, 3, 2007, "indonesia hist");
    each_holiday(20, 12, 2007, "indonesia hist");
    each_holiday(7, 2, 2008, "indonesia hist");
    each_holiday(30, 9, 2008, "indonesia hist");
    each_holiday(26, 1, 2009, "indonesia hist");
    each_holiday(18, 9, 2009, "indonesia hist");
    each_holiday(3, 2, 2011, "indonesia hist");
    each_holiday(23, 1, 2012, "indonesia hist");
    each_holiday(24, 1, 2013, "indonesia hist");
    each_holiday(14, 1, 2014, "indonesia hist");
    each_holiday(19, 2, 2015, "indonesia hist");
    each_holiday(8, 2, 2016, "indonesia hist");
    each_holiday(2, 1, 2017, "indonesia hist");
    each_holiday(16, 2, 2018, "indonesia hist");
    each_holiday(5, 2, 2019, "indonesia hist");
    each_holiday(25, 3, 2020, "indonesia hist");
    each_holiday(12, 2, 2021, "indonesia hist");
    each_holiday(1, 2, 2022, "indonesia hist");
    each_holiday(23, 1, 2023, "indonesia hist");
    each_holiday(8, 2, 2024, "indonesia hist");
    each_holiday(27, 1, 2025, "indonesia hist");
    each_holiday(16, 1, 2026, "indonesia hist");

    // testThailandCalendar
    holiday(markets_seasia::THAILAND, 1, 1, 2024, "thailand");
    holiday(markets_seasia::THAILAND, 15, 4, 2019, "thailand");
    holiday(markets_seasia::THAILAND, 4, 5, 2020, "thailand");
    holiday(markets_seasia::THAILAND, 3, 6, 2024, "thailand");
    holiday(markets_seasia::THAILAND, 29, 7, 2024, "thailand");
    holiday(markets_seasia::THAILAND, 14, 10, 2024, "thailand");
    open(markets_seasia::THAILAND, 15, 4, 2020, "thailand");
    open(markets_seasia::THAILAND, 2, 1, 2024, "thailand");
    holiday(markets_seasia::THAILAND, 5, 5, 2001, "thailand hist");
    holiday(markets_seasia::THAILAND, 23, 2, 2005, "thailand hist");
    holiday(markets_seasia::THAILAND, 23, 5, 2005, "thailand hist");
    holiday(markets_seasia::THAILAND, 22, 7, 2005, "thailand hist");
    holiday(markets_seasia::THAILAND, 13, 2, 2006, "thailand hist");
    holiday(markets_seasia::THAILAND, 12, 6, 2006, "thailand hist");
    holiday(markets_seasia::THAILAND, 11, 7, 2006, "thailand hist");
    holiday(markets_seasia::THAILAND, 5, 3, 2007, "thailand hist");
    holiday(markets_seasia::THAILAND, 31, 5, 2007, "thailand hist");
    holiday(markets_seasia::THAILAND, 24, 12, 2007, "thailand hist");
    holiday(markets_seasia::THAILAND, 21, 2, 2008, "thailand hist");
    holiday(markets_seasia::THAILAND, 19, 5, 2008, "thailand hist");
    holiday(markets_seasia::THAILAND, 17, 7, 2008, "thailand hist");
    holiday(markets_seasia::THAILAND, 9, 2, 2009, "thailand hist");
    holiday(markets_seasia::THAILAND, 1, 3, 2010, "thailand hist");
    holiday(markets_seasia::THAILAND, 18, 2, 2011, "thailand hist");
    holiday(markets_seasia::THAILAND, 2, 1, 2012, "thailand hist");
    holiday(markets_seasia::THAILAND, 7, 5, 2012, "thailand hist");
    holiday(markets_seasia::THAILAND, 4, 6, 2012, "thailand hist");
    holiday(markets_seasia::THAILAND, 6, 5, 2013, "thailand hist");
    holiday(markets_seasia::THAILAND, 23, 10, 2013, "thailand hist");
    holiday(markets_seasia::THAILAND, 14, 2, 2014, "thailand hist");
    holiday(markets_seasia::THAILAND, 4, 3, 2015, "thailand hist");
    holiday(markets_seasia::THAILAND, 22, 2, 2016, "thailand hist");
    holiday(markets_seasia::THAILAND, 13, 2, 2017, "thailand hist");
    holiday(markets_seasia::THAILAND, 1, 3, 2018, "thailand hist");
    holiday(markets_seasia::THAILAND, 4, 5, 2019, "thailand hist");
    holiday(markets_seasia::THAILAND, 3, 6, 2019, "thailand hist");
    holiday(markets_seasia::THAILAND, 12, 2, 2021, "thailand hist");
    holiday(markets_seasia::THAILAND, 16, 2, 2022, "thailand hist");
    holiday(markets_seasia::THAILAND, 6, 3, 2023, "thailand hist");

    // testSingaporeCalendar
    holiday(markets_seasia::SINGAPORE_SGX, 1, 1, 2024, "singapore");
    holiday(markets_seasia::SINGAPORE_SGX, 29, 3, 2024, "singapore");
    holiday(markets_seasia::SINGAPORE_SGX, 1, 5, 2024, "singapore");
    holiday(markets_seasia::SINGAPORE_SGX, 9, 8, 2024, "singapore");
    holiday(markets_seasia::SINGAPORE_SGX, 25, 12, 2024, "singapore");
    open(markets_seasia::SINGAPORE_SGX, 2, 1, 2024, "singapore");

    // testMalaysia
    check_range(markets_seasia::MALAYSIA_KLSE, ymd(1, 1, 2024), ymd(31, 12, 2025), MALAYSIA_HOL, "malaysia");

    // testMalaysiaVariableHolidays
    holiday(markets_seasia::MALAYSIA_KLSE, 3, 2, 2015, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 24, 1, 2016, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 9, 2, 2017, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 31, 1, 2018, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 21, 1, 2019, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 9, 2, 2020, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 28, 1, 2021, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 18, 1, 2022, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 5, 2, 2023, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 25, 1, 2024, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 11, 2, 2025, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 22, 1, 2027, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 19, 2, 2015, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 8, 2, 2016, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 28, 1, 2017, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 16, 2, 2018, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 5, 2, 2019, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 25, 1, 2020, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 12, 2, 2021, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 1, 2, 2022, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 22, 1, 2023, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 10, 2, 2024, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 29, 1, 2025, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 17, 2, 2026, "malaysia variable");
    holiday(markets_seasia::MALAYSIA_KLSE, 6, 2, 2027, "malaysia variable");

    // testMalaysiaFixedHolidaysOutsideTabulatedRange
    holiday(markets_seasia::MALAYSIA_KLSE, 1, 1, 2035, "malaysia fixed");
    holiday(markets_seasia::MALAYSIA_KLSE, 1, 2, 2035, "malaysia fixed");
    holiday(markets_seasia::MALAYSIA_KLSE, 1, 5, 2035, "malaysia fixed");
    holiday(markets_seasia::MALAYSIA_KLSE, 31, 8, 2035, "malaysia fixed");
    holiday(markets_seasia::MALAYSIA_KLSE, 25, 12, 2035, "malaysia fixed");
    holiday(markets_seasia::MALAYSIA_KLSE, 16, 9, 2035, "malaysia fixed");
    open(markets_seasia::MALAYSIA_KLSE, 16, 9, 2009, "malaysia fixed");

    // testPhilippines
    check_range(markets_seasia::PHILIPPINES_PSE, ymd(1, 1, 2024), ymd(31, 12, 2026), PHILIPPINES_HOL, "philippines");

    // testPhilippinesTransferredHolidays
    holiday(markets_seasia::PHILIPPINES_PSE, 10, 4, 2023, "philippines moved");
    holiday(markets_seasia::PHILIPPINES_PSE, 27, 11, 2023, "philippines moved");
    holiday(markets_seasia::PHILIPPINES_PSE, 23, 8, 2024, "philippines moved");
    holiday(markets_seasia::PHILIPPINES_PSE, 31, 12, 2020, "philippines moved");
    holiday(markets_seasia::PHILIPPINES_PSE, 25, 2, 2022, "philippines moved");
    holiday(markets_seasia::PHILIPPINES_PSE, 24, 2, 2023, "philippines moved");
    holiday(markets_seasia::PHILIPPINES_PSE, 17, 3, 2020, "philippines moved");
    holiday(markets_seasia::PHILIPPINES_PSE, 18, 3, 2020, "philippines moved");
    open(markets_seasia::PHILIPPINES_PSE, 30, 11, 2023, "philippines moved");
    open(markets_seasia::PHILIPPINES_PSE, 21, 8, 2024, "philippines moved");
    open(markets_seasia::PHILIPPINES_PSE, 31, 12, 2021, "philippines moved");
    open(markets_seasia::PHILIPPINES_PSE, 25, 2, 2025, "philippines moved");
    open(markets_seasia::PHILIPPINES_PSE, 19, 3, 2020, "philippines moved");

    // testPhilippinesFixedHolidaysOutsideTabulatedRange
    holiday(markets_seasia::PHILIPPINES_PSE, 1, 1, 2035, "philippines fixed");
    holiday(markets_seasia::PHILIPPINES_PSE, 9, 4, 2035, "philippines fixed");
    holiday(markets_seasia::PHILIPPINES_PSE, 1, 5, 2035, "philippines fixed");
    holiday(markets_seasia::PHILIPPINES_PSE, 12, 6, 2035, "philippines fixed");
    holiday(markets_seasia::PHILIPPINES_PSE, 21, 8, 2035, "philippines fixed");
    holiday(markets_seasia::PHILIPPINES_PSE, 27, 8, 2035, "philippines fixed");
    holiday(markets_seasia::PHILIPPINES_PSE, 1, 11, 2035, "philippines fixed");
    holiday(markets_seasia::PHILIPPINES_PSE, 30, 11, 2035, "philippines fixed");
    holiday(markets_seasia::PHILIPPINES_PSE, 25, 12, 2035, "philippines fixed");
    holiday(markets_seasia::PHILIPPINES_PSE, 31, 12, 2035, "philippines fixed");
    open(markets_seasia::PHILIPPINES_PSE, 20, 8, 2035, "philippines fixed");
    open(markets_seasia::PHILIPPINES_PSE, 21, 8, 2003, "philippines fixed");
    open(markets_seasia::PHILIPPINES_PSE, 8, 12, 2015, "philippines fixed");

    // testIndia
    check_range(markets_seasia::INDIA_NSE, ymd(1, 1, 2026), ymd(31, 12, 2026), INDIA_HOL, "india");
    holiday(markets_seasia::INDIA_NSE, 21, 1, 2005, "india hist");
    holiday(markets_seasia::INDIA_NSE, 11, 1, 2006, "india hist");
    holiday(markets_seasia::INDIA_NSE, 1, 1, 2007, "india hist");
    holiday(markets_seasia::INDIA_NSE, 6, 3, 2008, "india hist");
    holiday(markets_seasia::INDIA_NSE, 8, 1, 2009, "india hist");
    holiday(markets_seasia::INDIA_NSE, 1, 1, 2010, "india hist");
    holiday(markets_seasia::INDIA_NSE, 2, 3, 2011, "india hist");
    holiday(markets_seasia::INDIA_NSE, 20, 2, 2012, "india hist");
    holiday(markets_seasia::INDIA_NSE, 27, 3, 2013, "india hist");
    holiday(markets_seasia::INDIA_NSE, 27, 2, 2014, "india hist");
    holiday(markets_seasia::INDIA_NSE, 19, 2, 2019, "india hist");
    holiday(markets_seasia::INDIA_NSE, 19, 2, 2020, "india hist");
    holiday(markets_seasia::INDIA_NSE, 19, 2, 2021, "india hist");
    holiday(markets_seasia::INDIA_NSE, 1, 3, 2022, "india hist");
    holiday(markets_seasia::INDIA_NSE, 7, 3, 2023, "india hist");
    holiday(markets_seasia::INDIA_NSE, 22, 1, 2024, "india hist");
    holiday(markets_seasia::INDIA_NSE, 19, 2, 2025, "india hist");

    write_stdout("seasia ok\n");
}
