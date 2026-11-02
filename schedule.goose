// QuantLib schedule generation for Backward, Forward, and Zero.
// Dates are serials written into the caller's buffer. The null calendar
// steps the seed. The market calendar adjusts.

import date;
import period;
import calendar;
import markets;

namespace schedule;

const BACKWARD: i32 = 0;
const FORWARD: i32 = 1;
const ZERO: i32 = 2;

fn allows_end_of_month(n: i32, unit: i32) -> bool {
    if n <= 0 { return false; }
    return unit == period::MONTHS || unit == period::YEARS;
}

fn adjusted(kind: i32, d: date::Date, conv: i32) -> date::Date, bool {
    var hole: i32[1] = [0];
    return calendar::adjust(kind, d, conv, hole[0..0], hole[0..0]);
}

fn stepped(seed: date::Date, steps: i32, unit: i32, conv: i32, end_of_month: bool) -> date::Date, bool {
    var hole: i32[1] = [0];
    return calendar::advance(markets::NULL_CAL, seed, steps, unit, conv, end_of_month, hole[0..0], hole[0..0]);
}

fn same_adjusted(kind: i32, a: date::Date, b: date::Date, conv: i32) -> bool {
    let left, lok = adjusted(kind, a, conv);
    let right, rok = adjusted(kind, b, conv);
    return lok && rok && left.serial == right.serial;
}

fn is_market_end(kind: i32, d: date::Date) -> bool {
    let last, ok = date::end_of_month(d);
    if !ok { return false; }
    let adj, aok = adjusted(kind, last, calendar::PRECEDING);
    return aok && d.serial >= adj.serial;
}

fn build(effective: date::Date, termination: date::Date, n: i32, unit: i32, kind: i32, conv: i32, term_conv: i32, rule: i32, end_of_month: bool, out: i32[:]) -> i32, bool {
    let blank = date::blank();
    return build_stubs(effective, termination, n, unit, kind, conv, term_conv, rule, end_of_month, blank, blank, out);
}

fn build_stubs(effective: date::Date, termination: date::Date, n: i32, unit: i32, kind: i32, conv: i32, term_conv: i32, rule: i32, end_of_month: bool, first: date::Date, next_to_last: date::Date, out: i32[:]) -> i32, bool {
    if date::is_blank(effective) || date::is_blank(termination) { return 0, false; }
    if effective.serial >= termination.serial { return 0, false; }
    var use_eom = end_of_month;
    if !allows_end_of_month(n, unit) { use_eom = false; }
    var rule_now = rule;
    if n == 0 { rule_now = ZERO; }
    if n < 0 { return 0, false; }

    var dates: i32[>..] = [];
    var seed = termination;
    if rule_now == ZERO {
        dates.push(effective.serial);
        dates.push(termination.serial);
    } else if rule_now == BACKWARD {
        dates.push(termination.serial);
        seed = termination;
        if !date::is_blank(next_to_last) {
            dates.push(next_to_last.serial);
            seed = next_to_last;
        }
        var exit_date = effective;
        if !date::is_blank(first) { exit_date = first; }
        var periods: i32 = 1;
        while periods < 4000 {
            let temp, ok = stepped(seed, -periods * n, unit, conv, use_eom);
            if !ok { return 0, false; }
            if temp.serial < exit_date.serial {
                if !date::is_blank(first) {
                    let back, bok = date::from_serial(dates[dates.len - 1]);
                    if bok && !same_adjusted(kind, back, first, conv) {
                        dates.push(first.serial);
                    }
                }
                break;
            }
            let back, bok = date::from_serial(dates[dates.len - 1]);
            if bok && !same_adjusted(kind, back, temp, conv) {
                dates.push(temp.serial);
            }
            periods += 1;
        }
        let back, bok = date::from_serial(dates[dates.len - 1]);
        if bok && !same_adjusted(kind, back, effective, conv) {
            dates.push(effective.serial);
        }
        var i: i64 = 0;
        var j = dates.len - 1;
        while i < j {
            let tmp = dates[i];
            dates[i] = dates[j];
            dates[j] = tmp;
            i += 1;
            j -= 1;
        }
    } else if rule_now == FORWARD {
        dates.push(effective.serial);
        seed = effective;
        if !date::is_blank(first) { seed = first; }
        var exit_date = termination;
        if !date::is_blank(next_to_last) { exit_date = next_to_last; }
        if !date::is_blank(first) { dates.push(first.serial); }
        var periods: i32 = 1;
        while periods < 4000 {
            let temp, ok = stepped(seed, periods * n, unit, conv, use_eom);
            if !ok { return 0, false; }
            if temp.serial > exit_date.serial {
                if !date::is_blank(next_to_last) {
                    let back, bok = date::from_serial(dates[dates.len - 1]);
                    if bok && !same_adjusted(kind, back, next_to_last, conv) {
                        dates.push(next_to_last.serial);
                    }
                }
                break;
            }
            let back, bok = date::from_serial(dates[dates.len - 1]);
            if bok && !same_adjusted(kind, back, temp, conv) {
                dates.push(temp.serial);
            }
            periods += 1;
        }
        let back, bok = date::from_serial(dates[dates.len - 1]);
        if bok && !same_adjusted(kind, back, termination, term_conv) {
            dates.push(termination.serial);
        }
    } else {
        return 0, false;
    }

    if dates.len < 2 { return 0, false; }
    if conv != calendar::UNADJUSTED {
        let front, fok = date::from_serial(dates[0]);
        let adj, aok = adjusted(kind, front, conv);
        if !fok || !aok { return 0, false; }
        dates[0] = adj.serial;
    }
    if term_conv != calendar::UNADJUSTED {
        let last = dates.len - 1;
        let back, bok = date::from_serial(dates[last]);
        let adj, aok = adjusted(kind, back, term_conv);
        if !bok || !aok { return 0, false; }
        dates[last] = adj.serial;
    }
    var k: i64 = 1;
    while k < dates.len - 1 {
        let cur, cok = date::from_serial(dates[k]);
        if !cok { return 0, false; }
        var basis = cur;
        if use_eom && is_market_end(kind, seed) {
            let month_end, mok = date::end_of_month(cur);
            if !mok { return 0, false; }
            basis = month_end;
        }
        let adj, aok = adjusted(kind, basis, conv);
        if !aok { return 0, false; }
        dates[k] = adj.serial;
        k += 1;
    }
    if dates.len >= 2 && dates[dates.len - 2] >= dates[dates.len - 1] {
        dates[dates.len - 2] = dates[dates.len - 1];
        dates.pop();
    }
    if dates.len >= 2 && dates[1] <= dates[0] {
        dates[1] = dates[0];
        var t: i64 = 0;
        while t < dates.len - 1 {
            dates[t] = dates[t + 1];
            t += 1;
        }
        dates.pop();
    }
    if dates.len < 2 || dates.len > out.len { return 0, false; }
    var c: i64 = 0;
    while c < dates.len {
        out[c] = dates[c];
        c += 1;
    }
    return dates.len as i32, true;
}
