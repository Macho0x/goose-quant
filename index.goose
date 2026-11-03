// Custom IBOR dates from QuantLib's CustomIborIndex.
// A bespoke calendar is the null market plus the caller's holiday serials.
// Value dates walk the value calendar, then follow onto the maturity calendar.
// Fixing dates walk back on the value calendar, then precede onto the fixing calendar.
// Maturity advances the tenor on the maturity calendar.

import date;
import period;
import calendar;

namespace index;

fn value_date(fixing: date::Date, days: i32, fix_off: i32[:], val_off: i32[:], mat_off: i32[:]) -> date::Date, bool {
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    if !calendar::is_business_day(calendar::NULL_CAL, fixing, fix_off, empty) {
        return date::blank(), false;
    }
    let spot, ok = calendar::advance(calendar::NULL_CAL, fixing, days, period::DAYS, calendar::FOLLOWING, false, val_off, empty);
    if !ok { return date::blank(), false; }
    return calendar::adjust(calendar::NULL_CAL, spot, calendar::FOLLOWING, mat_off, empty);
}

fn fixing_date(value: date::Date, days: i32, fix_off: i32[:], val_off: i32[:]) -> date::Date, bool {
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    let back, ok = calendar::advance(calendar::NULL_CAL, value, -days, period::DAYS, calendar::FOLLOWING, false, val_off, empty);
    if !ok { return date::blank(), false; }
    return calendar::adjust(calendar::NULL_CAL, back, calendar::PRECEDING, fix_off, empty);
}

fn maturity_date(value: date::Date, n: i32, unit: i32, conv: i32, end_of_month: bool, mat_off: i32[:]) -> date::Date, bool {
    var hole: i32[1] = [0];
    return calendar::advance(calendar::NULL_CAL, value, n, unit, conv, end_of_month, mat_off, hole[0..0]);
}
