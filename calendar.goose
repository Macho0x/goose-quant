// Business-day adjustment and calendar advance, QuantLib's Calendar.
// A market is an i32. Holiday rules live in markets.goose.
// Added and removed holidays are serials the caller keeps; pass empty slices
// when the market's own holidays are enough.

import date;
import period;
import easter;
import markets;

namespace calendar;

const UNADJUSTED: i32 = 0;
const FOLLOWING: i32 = 1;
const MODIFIED_FOLLOWING: i32 = 2;
const PRECEDING: i32 = 3;
const MODIFIED_PRECEDING: i32 = 4;
const HALF_MONTH_MODIFIED_FOLLOWING: i32 = 5;
const NEAREST: i32 = 6;

const NULL_CAL: i32 = 0;
const WEEKENDS: i32 = 1;
const TARGET: i32 = 2;

fn western_weekend(w: i32) -> bool {
    return w == date::SATURDAY || w == date::SUNDAY;
}

fn is_holiday(kind: i32, d: date::Date) -> bool {
    return !markets::is_business_day(kind, d);
}

fn listed(serials: i32[:], serial: i32) -> bool {
    var i: i64 = 0;
    while i < serials.len {
        if serials[i] == serial { return true; }
        i += 1;
    }
    return false;
}

fn is_business_day(kind: i32, d: date::Date, added: i32[:], removed: i32[:]) -> bool {
    if date::is_blank(d) { return false; }
    if listed(added, d.serial) { return false; }
    if listed(removed, d.serial) { return true; }
    return markets::is_business_day(kind, d);
}

recursive fn adjust(kind: i32, d: date::Date, conv: i32, added: i32[:], removed: i32[:]) -> date::Date, bool {
    if date::is_blank(d) { return date::blank(), false; }
    if conv == UNADJUSTED { return d, true; }
    var d1 = d;
    if conv == FOLLOWING || conv == MODIFIED_FOLLOWING || conv == HALF_MONTH_MODIFIED_FOLLOWING {
        while is_off(kind, d1, added, removed) {
            let next, ok = date::plus_days(d1, 1);
            if !ok { return date::blank(), false; }
            d1 = next;
        }
        if conv == MODIFIED_FOLLOWING || conv == HALF_MONTH_MODIFIED_FOLLOWING {
            if date::month(d1) != date::month(d) {
                return adjust(kind, d, PRECEDING, added, removed);
            }
            if conv == HALF_MONTH_MODIFIED_FOLLOWING {
                if date::day_of_month(d) <= 15 && date::day_of_month(d1) > 15 {
                    return adjust(kind, d, PRECEDING, added, removed);
                }
            }
        }
        return d1, true;
    }
    if conv == PRECEDING || conv == MODIFIED_PRECEDING {
        while is_off(kind, d1, added, removed) {
            let prev, ok = date::plus_days(d1, -1);
            if !ok { return date::blank(), false; }
            d1 = prev;
        }
        if conv == MODIFIED_PRECEDING && date::month(d1) != date::month(d) {
            return adjust(kind, d, FOLLOWING, added, removed);
        }
        return d1, true;
    }
    if conv == NEAREST {
        var d2 = d;
        while is_off(kind, d1, added, removed) && is_off(kind, d2, added, removed) {
            let n1, ok1 = date::plus_days(d1, 1);
            let n2, ok2 = date::plus_days(d2, -1);
            if !ok1 || !ok2 { return date::blank(), false; }
            d1 = n1;
            d2 = n2;
        }
        if is_off(kind, d1, added, removed) { return d2, true; }
        return d1, true;
    }
    return date::blank(), false;
}

fn is_off(kind: i32, d: date::Date, added: i32[:], removed: i32[:]) -> bool {
    return !is_business_day(kind, d, added, removed);
}

fn advance(kind: i32, d: date::Date, n: i32, unit: i32, conv: i32, end_of_month: bool, added: i32[:], removed: i32[:]) -> date::Date, bool {
    if date::is_blank(d) { return date::blank(), false; }
    if n == 0 { return adjust(kind, d, conv, added, removed); }
    if unit == period::DAYS {
        var d1 = d;
        var left = n;
        if left > 0 {
            while left > 0 {
                let next, ok = date::plus_days(d1, 1);
                if !ok { return date::blank(), false; }
                d1 = next;
                while is_off(kind, d1, added, removed) {
                    let step, sok = date::plus_days(d1, 1);
                    if !sok { return date::blank(), false; }
                    d1 = step;
                }
                left -= 1;
            }
        } else {
            while left < 0 {
                let prev, ok = date::plus_days(d1, -1);
                if !ok { return date::blank(), false; }
                d1 = prev;
                while is_off(kind, d1, added, removed) {
                    let step, sok = date::plus_days(d1, -1);
                    if !sok { return date::blank(), false; }
                    d1 = step;
                }
                left += 1;
            }
        }
        return d1, true;
    }
    if unit == period::WEEKS {
        let shifted, ok = date::plus_days(d, n * 7);
        if !ok { return date::blank(), false; }
        return adjust(kind, shifted, conv, added, removed);
    }
    let shifted, ok = date::advance(d, n, unit);
    if !ok { return date::blank(), false; }
    if end_of_month {
        if conv == UNADJUSTED {
            if date::is_end_of_month(d) { return date::end_of_month(shifted); }
        } else if is_end_of_month(kind, d, added, removed) {
            return end_of_business_month(kind, shifted, added, removed);
        }
    }
    return adjust(kind, shifted, conv, added, removed);
}

fn is_end_of_month(kind: i32, d: date::Date, added: i32[:], removed: i32[:]) -> bool {
    let end, ok = end_of_business_month(kind, d, added, removed);
    return ok && d.serial >= end.serial;
}

fn is_business_end(kind: i32, d: date::Date, added: i32[:], removed: i32[:]) -> bool {
    if !is_business_day(kind, d, added, removed) { return false; }
    let next, ok = date::plus_days(d, 1);
    if !ok { return true; }
    if date::month(next) != date::month(d) { return true; }
    var cursor = next;
    while date::month(cursor) == date::month(d) {
        if is_business_day(kind, cursor, added, removed) { return false; }
        let step, sok = date::plus_days(cursor, 1);
        if !sok { return true; }
        cursor = step;
    }
    return true;
}

fn end_of_business_month(kind: i32, d: date::Date, added: i32[:], removed: i32[:]) -> date::Date, bool {
    let last, ok = date::end_of_month(d);
    if !ok { return date::blank(), false; }
    return adjust(kind, last, PRECEDING, added, removed);
}

fn business_days_between(kind: i32, from: date::Date, to: date::Date, include_first: bool, include_last: bool, added: i32[:], removed: i32[:]) -> i32 {
    if from.serial < to.serial {
        return count_between(kind, from, to, include_first, include_last, added, removed);
    }
    if from.serial > to.serial {
        return -count_between(kind, to, from, include_last, include_first, added, removed);
    }
    if include_first && include_last && is_business_day(kind, from, added, removed) { return 1; }
    return 0;
}

fn count_between(kind: i32, from: date::Date, to: date::Date, include_first: bool, include_last: bool, added: i32[:], removed: i32[:]) -> i32 {
    var res: i32 = 0;
    if include_last && is_business_day(kind, to, added, removed) { res = 1; }
    var cursor = from;
    if !include_first {
        let next, ok = date::plus_days(from, 1);
        if !ok { return res; }
        cursor = next;
    }
    while cursor.serial < to.serial {
        if is_business_day(kind, cursor, added, removed) { res += 1; }
        let next, ok = date::plus_days(cursor, 1);
        if !ok { return res; }
        cursor = next;
    }
    return res;
}

fn start_of_month(kind: i32, d: date::Date, added: i32[:], removed: i32[:]) -> date::Date, bool {
    let som, ok = date::start_of_month(d);
    if !ok { return date::blank(), false; }
    return adjust(kind, som, FOLLOWING, added, removed);
}

fn joint_business(kinds: i32[:], d: date::Date, added: i32[:], removed: i32[:], join_holidays: bool) -> bool {
    if kinds.len == 0 { return false; }
    var i: i64 = 0;
    if join_holidays {
        while i < kinds.len {
            if !is_business_day(kinds[i], d, added, removed) { return false; }
            i += 1;
        }
        return true;
    }
    while i < kinds.len {
        if is_business_day(kinds[i], d, added, removed) { return true; }
        i += 1;
    }
    return false;
}

fn advance_span(kind: i32, d: date::Date, p: period::Span, conv: i32, end_of_month: bool) -> date::Date, bool {
    var hole: i32[1] = [0];
    return advance(kind, d, p.n, p.unit, conv, end_of_month, hole[0..0], hole[0..0]);
}
