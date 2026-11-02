// A length and a unit, the same algebra as QuantLib's Period.
// Units are QuantLib's TimeUnit order: days, weeks, months, years.
// Frequency numbers are QuantLib's: Annual is 1, Monthly is 12, Daily is 365.

namespace period;

const DAYS: i32 = 0;
const WEEKS: i32 = 1;
const MONTHS: i32 = 2;
const YEARS: i32 = 3;

struct Span { n: i32, unit: i32 }

const NO_FREQUENCY: i32 = -1;
const ONCE: i32 = 0;
const ANNUAL: i32 = 1;
const SEMIANNUAL: i32 = 2;
const EVERY_FOURTH_MONTH: i32 = 3;
const QUARTERLY: i32 = 4;
const BIMONTHLY: i32 = 6;
const MONTHLY: i32 = 12;
const EVERY_FOURTH_WEEK: i32 = 13;
const BIWEEKLY: i32 = 26;
const WEEKLY: i32 = 52;
const DAILY: i32 = 365;
const OTHER: i32 = 999;

fn days(n: i32) -> Span { Span { n: n, unit: DAYS } }
fn weeks(n: i32) -> Span { Span { n: n, unit: WEEKS } }
fn months(n: i32) -> Span { Span { n: n, unit: MONTHS } }
fn years(n: i32) -> Span { Span { n: n, unit: YEARS } }

fn from_frequency(f: i32) -> Span, bool {
    if f == NO_FREQUENCY { return Span { n: 0, unit: DAYS }, true; }
    if f == ONCE { return Span { n: 0, unit: YEARS }, true; }
    if f == ANNUAL { return years(1), true; }
    if f == SEMIANNUAL || f == EVERY_FOURTH_MONTH || f == QUARTERLY || f == BIMONTHLY || f == MONTHLY {
        return months(12 / f), true;
    }
    if f == EVERY_FOURTH_WEEK || f == BIWEEKLY || f == WEEKLY {
        return weeks(52 / f), true;
    }
    if f == DAILY { return days(1), true; }
    return Span { n: 0, unit: DAYS }, false;
}

fn frequency(p: Span) -> i32 {
    var length = p.n;
    if length < 0 { length = -length; }
    if length == 0 {
        if p.unit == YEARS { return ONCE; }
        return NO_FREQUENCY;
    }
    if p.unit == YEARS {
        if length == 1 { return ANNUAL; }
        return OTHER;
    }
    if p.unit == MONTHS {
        if length <= 12 && 12 % length == 0 { return 12 / length; }
        return OTHER;
    }
    if p.unit == WEEKS {
        if length == 1 { return WEEKLY; }
        if length == 2 { return BIWEEKLY; }
        if length == 4 { return EVERY_FOURTH_WEEK; }
        return OTHER;
    }
    if length == 1 { return DAILY; }
    return OTHER;
}

fn normalize(p: Span) -> Span {
    if p.n == 0 { return Span { n: 0, unit: DAYS }; }
    if p.unit == MONTHS && p.n % 12 == 0 { return years(p.n / 12); }
    if p.unit == DAYS && p.n % 7 == 0 { return weeks(p.n / 7); }
    return p;
}

fn add(a: Span, b: Span) -> Span, bool {
    if a.n == 0 { return b, true; }
    if b.n == 0 { return a, true; }
    if a.unit == b.unit { return Span { n: a.n + b.n, unit: a.unit }, true; }
    if a.unit == YEARS && b.unit == MONTHS { return months(a.n * 12 + b.n), true; }
    if a.unit == MONTHS && b.unit == YEARS { return months(a.n + b.n * 12), true; }
    if a.unit == WEEKS && b.unit == DAYS { return days(a.n * 7 + b.n), true; }
    if a.unit == DAYS && b.unit == WEEKS { return days(a.n + b.n * 7), true; }
    return a, false;
}

fn sub(a: Span, b: Span) -> Span, bool {
    return add(a, Span { n: -b.n, unit: b.unit });
}

fn scale(p: Span, k: i32) -> Span {
    return Span { n: p.n * k, unit: p.unit };
}

fn div(p: Span, k: i32) -> Span, bool {
    if k == 0 { return p, false; }
    if p.n % k == 0 { return Span { n: p.n / k, unit: p.unit }, true; }
    if p.unit == YEARS {
        let length = p.n * 12;
        if length % k != 0 { return p, false; }
        return months(length / k), true;
    }
    if p.unit == WEEKS {
        let length = p.n * 7;
        if length % k != 0 { return p, false; }
        return days(length / k), true;
    }
    return p, false;
}

fn years_f(p: Span) -> f64, bool {
    if p.n == 0 { return 0.0, true; }
    if p.unit == MONTHS { return (p.n as f64) / 12.0, true; }
    if p.unit == YEARS { return p.n as f64, true; }
    return 0.0, false;
}

fn months_f(p: Span) -> f64, bool {
    if p.n == 0 { return 0.0, true; }
    if p.unit == MONTHS { return p.n as f64, true; }
    if p.unit == YEARS { return (p.n * 12) as f64, true; }
    return 0.0, false;
}

fn weeks_f(p: Span) -> f64, bool {
    if p.n == 0 { return 0.0, true; }
    if p.unit == DAYS { return (p.n as f64) / 7.0, true; }
    if p.unit == WEEKS { return p.n as f64, true; }
    return 0.0, false;
}

fn days_f(p: Span) -> f64, bool {
    if p.n == 0 { return 0.0, true; }
    if p.unit == DAYS { return p.n as f64, true; }
    if p.unit == WEEKS { return (p.n * 7) as f64, true; }
    return 0.0, false;
}

fn day_bounds(p: Span) -> i32, i32 {
    if p.unit == DAYS { return p.n, p.n; }
    if p.unit == WEEKS { return p.n * 7, p.n * 7; }
    if p.unit == MONTHS {
        if p.n >= 0 { return 28 * p.n, 31 * p.n; }
        return 31 * p.n, 28 * p.n;
    }
    if p.n >= 0 { return 365 * p.n, 366 * p.n; }
    return 366 * p.n, 365 * p.n;
}

// Less-than. The bool is false when the two periods do not order.
fn less(a: Span, b: Span) -> bool, bool {
    if a.n == 0 { return b.n > 0, true; }
    if b.n == 0 { return a.n < 0, true; }
    if a.unit == b.unit { return a.n < b.n, true; }
    if a.unit == MONTHS && b.unit == YEARS { return a.n < 12 * b.n, true; }
    if a.unit == YEARS && b.unit == MONTHS { return 12 * a.n < b.n, true; }
    if a.unit == DAYS && b.unit == WEEKS { return a.n < 7 * b.n, true; }
    if a.unit == WEEKS && b.unit == DAYS { return 7 * a.n < b.n, true; }
    let a0, a1 = day_bounds(a);
    let b0, b1 = day_bounds(b);
    if a1 < b0 { return true, true; }
    if a0 > b1 { return false, true; }
    return false, false;
}
