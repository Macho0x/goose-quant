// Monthly CPI flat lagged fixing. QuantLib CPI::laggedFixing, CPI::Flat:
// the published fixing for the month of (date minus the observation lag).

import date;

namespace inflation;

struct Fix { on: date::Date, value: f64 }

fn lagged_fixing(fixings: Fix[:], on: date::Date, lag_months: i32) -> f64, bool {
    let back, bok = date::plus_months(on, -lag_months);
    if !bok { return 0.0, false; }
    let key, kok = date::start_of_month(back);
    if !kok { return 0.0, false; }
    var i: i64 = 0;
    while i < fixings.len {
        let start, sok = date::start_of_month(fixings[i].on);
        if sok && start.serial == key.serial { return fixings[i].value, true; }
        i += 1;
    }
    return 0.0, false;
}
