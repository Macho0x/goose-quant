// QuantLib dates. The serial is the Excel number: 367 is 1 January 1901
// and 109574 is 31 December 2199. Serial 0 is the null date.
// 1900 is a leap year here, matching Excel and QuantLib's table.
// Weekday numbers are Excel's: Sunday is 1 and Saturday is 7.

import std;
import period;

namespace date;

struct Date { serial: i32 }

const MIN_SERIAL: i32 = 367;
const MAX_SERIAL: i32 = 109574;

const SUNDAY: i32 = 1;
const MONDAY: i32 = 2;
const TUESDAY: i32 = 3;
const WEDNESDAY: i32 = 4;
const THURSDAY: i32 = 5;
const FRIDAY: i32 = 6;
const SATURDAY: i32 = 7;

const JANUARY: i32 = 1;
const FEBRUARY: i32 = 2;
const MARCH: i32 = 3;
const APRIL: i32 = 4;
const MAY: i32 = 5;
const JUNE: i32 = 6;
const JULY: i32 = 7;
const AUGUST: i32 = 8;
const SEPTEMBER: i32 = 9;
const OCTOBER: i32 = 10;
const NOVEMBER: i32 = 11;
const DECEMBER: i32 = 12;

const MONTH_LEN: i32[12] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
const MONTH_LEAP: i32[12] = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
const MONTH_OFF: i32[13] = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365];
const MONTH_LOFF: i32[13] = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366];

fn blank() -> Date { Date { serial: 0 } }
fn is_blank(d: Date) -> bool { d.serial == 0 }

fn is_leap(y: i32) -> bool {
    if y == 1900 { return true; }
    if y % 4 != 0 { return false; }
    if y % 100 != 0 { return true; }
    return y % 400 == 0;
}

fn month_length(m: i32, leap: bool) -> i32 {
    if leap { return MONTH_LEAP[m - 1]; }
    return MONTH_LEN[m - 1];
}

fn month_offset(m: i32, leap: bool) -> i32 {
    if leap { return MONTH_LOFF[m - 1]; }
    return MONTH_OFF[m - 1];
}

// December 31 of the previous year, as an Excel serial. 1900 counts as leap.
fn year_offset(y: i32) -> i32 {
    if y <= 1900 { return 0; }
    let n = y - 1900;
    let last = y - 1;
    var leaps = last / 4 - 1899 / 4;
    if y > 2100 { leaps -= 1; }
    if y > 2200 { leaps -= 1; }
    return n * 365 + leaps;
}

fn in_range(serial: i32) -> bool {
    return serial >= MIN_SERIAL && serial <= MAX_SERIAL;
}

fn from_serial(serial: i32) -> Date, bool {
    if !in_range(serial) { return blank(), false; }
    return Date { serial: serial }, true;
}

fn from_ymd(day: i32, m: i32, y: i32) -> Date, bool {
    if y <= 1900 || y >= 2200 { return blank(), false; }
    if m < 1 || m > 12 { return blank(), false; }
    let leap = is_leap(y);
    let len = month_length(m, leap);
    if day <= 0 || day > len { return blank(), false; }
    let serial = day + month_offset(m, leap) + year_offset(y);
    return Date { serial: serial }, true;
}

fn year(d: Date) -> i32 {
    var y = d.serial / 365 + 1900;
    if d.serial <= year_offset(y) { y -= 1; }
    return y;
}

fn day_of_year(d: Date) -> i32 {
    return d.serial - year_offset(year(d));
}

fn month(d: Date) -> i32 {
    let doy = day_of_year(d);
    var m = doy / 30 + 1;
    let leap = is_leap(year(d));
    while doy <= month_offset(m, leap) { m -= 1; }
    while doy > month_offset(m + 1, leap) { m += 1; }
    return m;
}

fn day_of_month(d: Date) -> i32 {
    let y = year(d);
    return day_of_year(d) - month_offset(month(d), is_leap(y));
}

fn weekday(d: Date) -> i32 {
    let w = d.serial % 7;
    if w == 0 { return 7; }
    return w;
}

fn plus_days(d: Date, n: i32) -> Date, bool {
    if is_blank(d) { return blank(), false; }
    return from_serial(d.serial + n);
}

fn plus_months(d: Date, n: i32) -> Date, bool {
    if is_blank(d) { return blank(), false; }
    var day = day_of_month(d);
    var m = month(d) + n;
    var y = year(d);
    while m > 12 {
        m -= 12;
        y += 1;
    }
    while m < 1 {
        m += 12;
        y -= 1;
    }
    if y <= 1900 || y >= 2200 { return blank(), false; }
    let len = month_length(m, is_leap(y));
    if day > len { day = len; }
    return from_ymd(day, m, y);
}

fn plus_years(d: Date, n: i32) -> Date, bool {
    if is_blank(d) { return blank(), false; }
    var day = day_of_month(d);
    let m = month(d);
    let y = year(d) + n;
    if y <= 1900 || y >= 2200 { return blank(), false; }
    if day == 29 && m == FEBRUARY && !is_leap(y) { day = 28; }
    return from_ymd(day, m, y);
}

fn advance(d: Date, n: i32, unit: i32) -> Date, bool {
    if unit == period::DAYS { return plus_days(d, n); }
    if unit == period::WEEKS { return plus_days(d, n * 7); }
    if unit == period::MONTHS { return plus_months(d, n); }
    if unit == period::YEARS { return plus_years(d, n); }
    return blank(), false;
}

fn add_span(d: Date, p: period::Span) -> Date, bool {
    return advance(d, p.n, p.unit);
}

fn sub_span(d: Date, p: period::Span) -> Date, bool {
    return advance(d, -p.n, p.unit);
}

fn days_between(a: Date, b: Date) -> i32 {
    return b.serial - a.serial;
}

fn start_of_month(d: Date) -> Date, bool {
    if is_blank(d) { return blank(), false; }
    return from_ymd(1, month(d), year(d));
}

fn end_of_month(d: Date) -> Date, bool {
    if is_blank(d) { return blank(), false; }
    let m = month(d);
    let y = year(d);
    return from_ymd(month_length(m, is_leap(y)), m, y);
}

fn is_end_of_month(d: Date) -> bool {
    if is_blank(d) { return false; }
    let m = month(d);
    return day_of_month(d) == month_length(m, is_leap(year(d)));
}

fn next_weekday(d: Date, w: i32) -> Date, bool {
    if is_blank(d) { return blank(), false; }
    let wd = weekday(d);
    var add = w - wd;
    if wd > w { add += 7; }
    return plus_days(d, add);
}

fn nth_weekday(nth: i32, w: i32, m: i32, y: i32) -> Date, bool {
    if nth < 1 || nth > 5 { return blank(), false; }
    let first, ok = from_ymd(1, m, y);
    if !ok { return blank(), false; }
    let first_w = weekday(first);
    var skip = nth;
    if w >= first_w { skip = nth - 1; }
    let day = (1 + w + skip * 7) - first_w;
    return from_ymd(day, m, y);
}

fn min_date() -> Date { Date { serial: MIN_SERIAL } }
fn max_date() -> Date { Date { serial: MAX_SERIAL } }

fn parse_iso(s: u8[:]) -> Date, bool {
    if s.len != 10 || s[4] != '-' || s[7] != '-' { return blank(), false; }
    let y, yok = parse_int(s[0..4]);
    let m, mok = parse_int(s[5..7]);
    let d, dok = parse_int(s[8..10]);
    if !yok || !mok || !dok { return blank(), false; }
    return from_ymd(d as i32, m as i32, y as i32);
}

fn parse_ymd(s: u8[:], order: i32) -> Date, bool {
    if order == 0 { return parse_iso(s); }
    if s.len == 8 && order == 1 {
        let y, yok = parse_int(s[0..4]);
        let m, mok = parse_int(s[4..6]);
        let d, dok = parse_int(s[6..8]);
        if !yok || !mok || !dok { return blank(), false; }
        return from_ymd(d as i32, m as i32, y as i32);
    }
    if s.len != 10 || s[2] != '/' || s[5] != '/' { return blank(), false; }
    let a, aok = parse_int(s[0..2]);
    let b, bok = parse_int(s[3..5]);
    let y, yok = parse_int(s[6..10]);
    if !aok || !bok || !yok { return blank(), false; }
    if order == 2 { return from_ymd(b as i32, a as i32, y as i32); }
    return from_ymd(a as i32, b as i32, y as i32);
}
