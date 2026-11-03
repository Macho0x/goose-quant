// Monthly CPI flat lagged fixing. QuantLib CPI::laggedFixing, CPI::Flat:
// the published fixing for the month of (date minus the observation lag).

import date;

namespace inflation;

struct Fix { on: date::Date, value: f64 }

fn month_value(fixings: Fix[:], key: date::Date) -> f64, bool {
    var i: i64 = 0;
    while i < fixings.len {
        let start, sok = date::start_of_month(fixings[i].on);
        if sok && start.serial == key.serial { return fixings[i].value, true; }
        i += 1;
    }
    return 0.0, false;
}

fn lagged_fixing(fixings: Fix[:], on: date::Date, lag_months: i32) -> f64, bool {
    let back, bok = date::plus_months(on, -lag_months);
    if !bok { return 0.0, false; }
    let key, kok = date::start_of_month(back);
    if !kok { return 0.0, false; }
    return month_value(fixings, key);
}

// CPI::Linear. The weight is the day count inside the observation month.
// The two fixings are the lagged month and the month after it. The first
// of a month is the lagged fixing alone. A missing later fixing fails.
fn linear_fixing(fixings: Fix[:], on: date::Date, lag_months: i32) -> f64, bool {
    let back, bok = date::plus_months(on, -lag_months);
    if !bok { return 0.0, false; }
    let key, kok = date::start_of_month(back);
    if !kok { return 0.0, false; }
    let i0, ok0 = month_value(fixings, key);
    if !ok0 { return 0.0, false; }
    if date::day_of_month(on) == 1 { return i0, true; }
    let next, nok = date::plus_months(key, 1);
    if !nok { return 0.0, false; }
    let i1, ok1 = month_value(fixings, next);
    if !ok1 { return 0.0, false; }
    let span = date::month_length(date::month(on), date::is_leap(date::year(on)));
    if span <= 0 { return 0.0, false; }
    let elapsed = date::day_of_month(on) - 1;
    return i0 + (i1 - i0) * elapsed / span, true;
}
