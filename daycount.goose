// Day-count fractions from QuantLib's day counters.
// kind values are stable. include_last is the Actual/360, Actual/364,
// Actual/365.25, and Actual/366 option. term is the 30/360 ISDA termination
// serial, or 0 when there is none. A blank reference date is serial 0.

import date;
import calendar;
import markets;

namespace daycount;

const ACT_360: i32 = 1;
const ACT_365_FIXED: i32 = 2;
const ACT_365_CANADIAN: i32 = 3;
const ACT_365_NO_LEAP: i32 = 4;
const ACT_364: i32 = 5;
const ACT_365_25: i32 = 6;
const ACT_366: i32 = 7;
const T360_USA: i32 = 8;
const T360_EU: i32 = 9;
const T360_IT: i32 = 10;
const T360_ISMA: i32 = 11;
const T360_ISDA: i32 = 12;
const T360_NASD: i32 = 13;
const ACT_ACT_ISMA: i32 = 14;
const ACT_ACT_ISDA: i32 = 15;
const ACT_ACT_AFB: i32 = 16;
const SIMPLE: i32 = 17;
const ONE: i32 = 18;
const T365: i32 = 19;
const BUS_252: i32 = 20;

struct Count {
    kind: i32,
    include_last: bool,
    term: i32,
}

fn make(kind: i32) -> Count {
    Count { kind: kind, include_last: false, term: 0 }
}

fn actual360() -> Count { make(ACT_360) }
fn actual365_fixed() -> Count { make(ACT_365_FIXED) }
fn thirty360_usa() -> Count { make(T360_USA) }
fn thirty360_bond() -> Count { make(T360_ISMA) }
fn thirty360_euro() -> Count { make(T360_EU) }
fn actual_actual_isda() -> Count { make(ACT_ACT_ISDA) }
fn actual_actual_isma() -> Count { make(ACT_ACT_ISMA) }
fn actual_actual_afb() -> Count { make(ACT_ACT_AFB) }
fn business252() -> Count { make(BUS_252) }

fn with_last(kind: i32) -> Count {
    Count { kind: kind, include_last: true, term: 0 }
}

fn isda_30_count(term: i32) -> Count {
    Count { kind: T360_ISDA, include_last: false, term: term }
}

fn last_of_february(day: i32, m: i32, y: i32) -> bool {
    var len = 28;
    if date::is_leap(y) { len = 29; }
    return m == date::FEBRUARY && day == len;
}

const NO_LEAP_OFF: i32[12] = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];

fn no_leap_days(d1: date::Date, d2: date::Date) -> i32 {
    var s1 = date::day_of_month(d1) + NO_LEAP_OFF[date::month(d1) - 1] + date::year(d1) * 365;
    var s2 = date::day_of_month(d2) + NO_LEAP_OFF[date::month(d2) - 1] + date::year(d2) * 365;
    if date::month(d1) == date::FEBRUARY && date::day_of_month(d1) == 29 { s1 -= 1; }
    if date::month(d2) == date::FEBRUARY && date::day_of_month(d2) == 29 { s2 -= 1; }
    return s2 - s1;
}

fn ymd360(dd1: i32, mm1: i32, yy1: i32, dd2: i32, mm2: i32, yy2: i32) -> i32 {
    return 360 * (yy2 - yy1) + 30 * (mm2 - mm1) + (dd2 - dd1);
}

fn us_30(d1: date::Date, d2: date::Date) -> i32 {
    var dd1 = date::day_of_month(d1);
    var dd2 = date::day_of_month(d2);
    let mm1 = date::month(d1);
    let mm2 = date::month(d2);
    let yy1 = date::year(d1);
    let yy2 = date::year(d2);
    if last_of_february(dd1, mm1, yy1) {
        if last_of_february(dd2, mm2, yy2) { dd2 = 30; }
        dd1 = 30;
    }
    if dd2 == 31 && dd1 >= 30 { dd2 = 30; }
    if dd1 == 31 { dd1 = 30; }
    return ymd360(dd1, mm1, yy1, dd2, mm2, yy2);
}

fn isma_30(d1: date::Date, d2: date::Date) -> i32 {
    var dd1 = date::day_of_month(d1);
    var dd2 = date::day_of_month(d2);
    let mm1 = date::month(d1);
    let mm2 = date::month(d2);
    let yy1 = date::year(d1);
    let yy2 = date::year(d2);
    if dd1 == 31 { dd1 = 30; }
    if dd2 == 31 && dd1 == 30 { dd2 = 30; }
    return ymd360(dd1, mm1, yy1, dd2, mm2, yy2);
}

fn eu_30(d1: date::Date, d2: date::Date) -> i32 {
    var dd1 = date::day_of_month(d1);
    var dd2 = date::day_of_month(d2);
    if dd1 == 31 { dd1 = 30; }
    if dd2 == 31 { dd2 = 30; }
    return ymd360(dd1, date::month(d1), date::year(d1), dd2, date::month(d2), date::year(d2));
}

fn it_30(d1: date::Date, d2: date::Date) -> i32 {
    var dd1 = date::day_of_month(d1);
    var dd2 = date::day_of_month(d2);
    let mm1 = date::month(d1);
    let mm2 = date::month(d2);
    if dd1 == 31 { dd1 = 30; }
    if dd2 == 31 { dd2 = 30; }
    if mm1 == date::FEBRUARY && dd1 > 27 { dd1 = 30; }
    if mm2 == date::FEBRUARY && dd2 > 27 { dd2 = 30; }
    return ymd360(dd1, mm1, date::year(d1), dd2, mm2, date::year(d2));
}

fn isda_30(d1: date::Date, d2: date::Date, term: i32) -> i32 {
    var dd1 = date::day_of_month(d1);
    var dd2 = date::day_of_month(d2);
    let mm1 = date::month(d1);
    let mm2 = date::month(d2);
    let yy1 = date::year(d1);
    let yy2 = date::year(d2);
    if dd1 == 31 { dd1 = 30; }
    if dd2 == 31 { dd2 = 30; }
    if last_of_february(dd1, mm1, yy1) { dd1 = 30; }
    if d2.serial != term && last_of_february(dd2, mm2, yy2) { dd2 = 30; }
    return ymd360(dd1, mm1, yy1, dd2, mm2, yy2);
}

fn nasd_30(d1: date::Date, d2: date::Date) -> i32 {
    var dd1 = date::day_of_month(d1);
    var dd2 = date::day_of_month(d2);
    let mm1 = date::month(d1);
    var mm2 = date::month(d2);
    let yy1 = date::year(d1);
    let yy2 = date::year(d2);
    if dd1 == 31 { dd1 = 30; }
    if dd2 == 31 && dd1 >= 30 { dd2 = 30; }
    if dd2 == 31 && dd1 < 30 {
        dd2 = 1;
        mm2 += 1;
    }
    return ymd360(dd1, mm1, yy1, dd2, mm2, yy2);
}

fn actual_days(dc: Count, d1: date::Date, d2: date::Date) -> i32 {
    var n = date::days_between(d1, d2);
    if dc.include_last { n += 1; }
    return n;
}

fn day_count(dc: Count, d1: date::Date, d2: date::Date) -> i32 {
    if dc.kind == ACT_360 || dc.kind == ACT_364 || dc.kind == ACT_365_25 || dc.kind == ACT_366 {
        return actual_days(dc, d1, d2);
    }
    if dc.kind == ACT_365_NO_LEAP { return no_leap_days(d1, d2); }
    if dc.kind == T360_USA { return us_30(d1, d2); }
    if dc.kind == T360_EU || dc.kind == T365 { return eu_30(d1, d2); }
    if dc.kind == T360_IT { return it_30(d1, d2); }
    if dc.kind == T360_ISMA || dc.kind == SIMPLE { return isma_30(d1, d2); }
    if dc.kind == T360_ISDA { return isda_30(d1, d2, dc.term); }
    if dc.kind == T360_NASD { return nasd_30(d1, d2); }
    if dc.kind == ONE {
        if d2.serial >= d1.serial { return 1; }
        return -1;
    }
    if dc.kind == BUS_252 { return bus252_days(d1, d2); }
    return date::days_between(d1, d2);
}

fn lround(x: f64) -> i32 {
    if x >= 0.0 { return (x + 0.5) as i32; }
    return (x - 0.5) as i32;
}

fn year_fraction(dc: Count, d1: date::Date, d2: date::Date, rs: date::Date, re: date::Date) -> f64, bool {
    if date::is_blank(d1) || date::is_blank(d2) { return 0.0, false; }
    if dc.kind == ACT_360 { return (actual_days(dc, d1, d2) as f64) / 360.0, true; }
    if dc.kind == ACT_365_FIXED { return (date::days_between(d1, d2) as f64) / 365.0, true; }
    if dc.kind == ACT_365_CANADIAN { return canadian(d1, d2, rs, re); }
    if dc.kind == ACT_365_NO_LEAP { return (no_leap_days(d1, d2) as f64) / 365.0, true; }
    if dc.kind == ACT_364 { return (actual_days(dc, d1, d2) as f64) / 364.0, true; }
    if dc.kind == ACT_365_25 { return (actual_days(dc, d1, d2) as f64) / 365.25, true; }
    if dc.kind == ACT_366 { return (actual_days(dc, d1, d2) as f64) / 366.0, true; }
    if dc.kind == ONE { return day_count(dc, d1, d2) as f64, true; }
    if dc.kind == SIMPLE { return simple_yf(d1, d2); }
    if dc.kind == ACT_ACT_ISDA { return isda_act(d1, d2); }
    if dc.kind == ACT_ACT_AFB { return afb_act(d1, d2); }
    if dc.kind == ACT_ACT_ISMA { return isma_act(d1, d2, rs, re); }
    if dc.kind == T365 { return day_count(dc, d1, d2) / 365.0, true; }
    if dc.kind == BUS_252 { return day_count(dc, d1, d2) / 252.0, true; }
    if dc.kind == T360_USA || dc.kind == T360_EU || dc.kind == T360_IT || dc.kind == T360_ISMA || dc.kind == T360_ISDA || dc.kind == T360_NASD {
        return day_count(dc, d1, d2) / 360.0, true;
    }
    return 0.0, false;
}

fn canadian(d1: date::Date, d2: date::Date, rs: date::Date, re: date::Date) -> f64, bool {
    if d1.serial == d2.serial { return 0.0, true; }
    if date::is_blank(rs) || date::is_blank(re) { return 0.0, false; }
    let dcs = date::days_between(d1, d2) as f64;
    let dcc = date::days_between(rs, re) as f64;
    let months = lround(12.0 * dcc / 365.0);
    if months == 0 { return 0.0, false; }
    let frequency = 12 / months;
    if frequency == 0 { return 0.0, false; }
    if dcs < (365 / frequency) as f64 { return dcs / 365.0, true; }
    return 1.0 / (frequency as f64) - (dcc - dcs) / 365.0, true;
}

fn simple_yf(d1: date::Date, d2: date::Date) -> f64, bool {
    let dm1 = date::day_of_month(d1);
    let dm2 = date::day_of_month(d2);
    if dm1 == dm2 || (dm1 > dm2 && date::is_end_of_month(d2)) || (dm1 < dm2 && date::is_end_of_month(d1)) {
        let months = (date::year(d2) - date::year(d1)) as f64 + ((date::month(d2) - date::month(d1)) as f64) / 12.0;
        return months, true;
    }
    return (isma_30(d1, d2) as f64) / 360.0, true;
}

recursive fn isda_act(d1: date::Date, d2: date::Date) -> f64, bool {
    if d1.serial == d2.serial { return 0.0, true; }
    if d1.serial > d2.serial {
        let v, ok = isda_act(d2, d1);
        return -v, ok;
    }
    let y1 = date::year(d1);
    let y2 = date::year(d2);
    var dib1 = 365.0;
    var dib2 = 365.0;
    if date::is_leap(y1) { dib1 = 366.0; }
    if date::is_leap(y2) { dib2 = 366.0; }
    if y1 == y2 { return (date::days_between(d1, d2) as f64) / dib1, true; }
    let jan1, ok1 = date::from_ymd(1, date::JANUARY, y1 + 1);
    let jan2, ok2 = date::from_ymd(1, date::JANUARY, y2);
    if !ok1 || !ok2 { return 0.0, false; }
    var sum = (y2 - y1 - 1) as f64;
    sum += (date::days_between(d1, jan1) as f64) / dib1;
    sum += (date::days_between(jan2, d2) as f64) / dib2;
    return sum, true;
}

recursive fn afb_act(d1: date::Date, d2: date::Date) -> f64, bool {
    if d1.serial == d2.serial { return 0.0, true; }
    if d1.serial > d2.serial {
        let v, ok = afb_act(d2, d1);
        return -v, ok;
    }
    var new_d2 = d2;
    var temp = d2;
    var sum = 0.0;
    while temp.serial > d1.serial {
        let back, ok = date::plus_years(new_d2, -1);
        if !ok { return 0.0, false; }
        temp = back;
        if date::day_of_month(temp) == 28 && date::month(temp) == date::FEBRUARY && date::is_leap(date::year(temp)) {
            let bumped, bok = date::plus_days(temp, 1);
            if !bok { return 0.0, false; }
            temp = bumped;
        }
        if temp.serial >= d1.serial {
            sum += 1.0;
            new_d2 = temp;
        }
    }
    var den = 365.0;
    if date::is_leap(date::year(new_d2)) {
        let feb, ok = date::from_ymd(29, date::FEBRUARY, date::year(new_d2));
        if ok && new_d2.serial > feb.serial && d1.serial <= feb.serial { den += 1.0; }
    } else if date::is_leap(date::year(d1)) {
        let feb, ok = date::from_ymd(29, date::FEBRUARY, date::year(d1));
        if ok && new_d2.serial > feb.serial && d1.serial <= feb.serial { den += 1.0; }
    }
    return sum + (date::days_between(d1, new_d2) as f64) / den, true;
}

recursive fn isma_act(d1: date::Date, d2: date::Date, rs: date::Date, re: date::Date) -> f64, bool {
    if d1.serial == d2.serial { return 0.0, true; }
    if d1.serial > d2.serial {
        let v, ok = isma_act(d2, d1, rs, re);
        return -v, ok;
    }
    var ref_start = d1;
    var ref_end = d2;
    if !date::is_blank(rs) { ref_start = rs; }
    if !date::is_blank(re) { ref_end = re; }
    if ref_end.serial <= ref_start.serial || ref_end.serial <= d1.serial { return 0.0, false; }
    var months = lround(12.0 * (date::days_between(ref_start, ref_end) as f64) / 365.0);
    if months == 0 {
        ref_start = d1;
        let end, ok = date::plus_years(d1, 1);
        if !ok { return 0.0, false; }
        ref_end = end;
        months = 12;
    }
    let period = (months as f64) / 12.0;
    if d2.serial <= ref_end.serial {
        if d1.serial >= ref_start.serial {
            let span = date::days_between(ref_start, ref_end);
            if span == 0 { return 0.0, false; }
            return period * (date::days_between(d1, d2) as f64) / (span as f64), true;
        }
        let previous, ok = date::plus_months(ref_start, -months);
        if !ok { return 0.0, false; }
        if d2.serial > ref_start.serial {
            let a, aok = isma_act(d1, ref_start, previous, ref_start);
            let b, bok = isma_act(ref_start, d2, ref_start, ref_end);
            if !aok || !bok { return 0.0, false; }
            return a + b, true;
        }
        return isma_act(d1, d2, previous, ref_start);
    }
    if ref_start.serial > d1.serial { return 0.0, false; }
    let head, hok = isma_act(d1, ref_end, ref_start, ref_end);
    if !hok { return 0.0, false; }
    var sum = head;
    var i: i32 = 0;
    while true {
        let new_start, sok = date::plus_months(ref_end, months * i);
        let new_end, eok = date::plus_months(ref_end, months * (i + 1));
        if !sok || !eok { return 0.0, false; }
        if d2.serial < new_end.serial {
            let tail, tok = isma_act(new_start, d2, new_start, new_end);
            if !tok { return 0.0, false; }
            return sum + tail, true;
        }
        sum += period;
        i += 1;
        if i > 600 { return 0.0, false; }
    }
    return 0.0, false;
}

fn same_month(a: date::Date, b: date::Date) -> bool {
    return date::year(a) == date::year(b) && date::month(a) == date::month(b);
}

fn brazil_between(a: date::Date, b: date::Date) -> i32 {
    var hole: i32[1] = [0];
    return calendar::business_days_between(markets::BRAZIL, a, b, true, false, hole[0..0], hole[0..0]);
}

fn brazil_month(m: i32, y: i32) -> i32 {
    let d1, ok1 = date::from_ymd(1, m, y);
    if !ok1 { return 0; }
    let d2, ok2 = date::plus_months(d1, 1);
    if !ok2 { return 0; }
    return brazil_between(d1, d2);
}

fn brazil_year(y: i32) -> i32 {
    var total: i32 = 0;
    var m: i32 = 1;
    while m <= 12 {
        total += brazil_month(m, y);
        m += 1;
    }
    return total;
}

fn bus252_days(d1: date::Date, d2: date::Date) -> i32 {
    if same_month(d1, d2) || d1.serial >= d2.serial {
        return brazil_between(d1, d2);
    }
    if date::year(d1) == date::year(d2) {
        let som, sok = date::start_of_month(d1);
        if !sok { return 0; }
        let nxt, nok = date::plus_months(som, 1);
        if !nok { return 0; }
        var total = brazil_between(d1, nxt);
        var cursor = nxt;
        while !same_month(cursor, d2) {
            total += brazil_month(date::month(cursor), date::year(cursor));
            let step, ok = date::plus_months(cursor, 1);
            if !ok { return total; }
            cursor = step;
        }
        return total + brazil_between(cursor, d2);
    }
    let som, sok = date::start_of_month(d1);
    if !sok { return 0; }
    let nxt, nok = date::plus_months(som, 1);
    if !nok { return 0; }
    var total = brazil_between(d1, nxt);
    var m = date::month(d1) + 1;
    while m <= 12 {
        total += brazil_month(m, date::year(d1));
        m += 1;
    }
    var y = date::year(d1) + 1;
    while y != date::year(d2) {
        total += brazil_year(y);
        y += 1;
    }
    var mm: i32 = 1;
    while mm < date::month(d2) {
        total += brazil_month(mm, date::year(d2));
        mm += 1;
    }
    let last, lok = date::from_ymd(1, date::month(d2), date::year(d2));
    if !lok { return total; }
    return total + brazil_between(last, d2);
}
