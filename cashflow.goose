// Macaulay-style simple duration. Discounts compound one interval at a time.
// SimpleThenCompounded uses simple on the first interval only.
// CompoundedThenSimple uses simple on the last interval only.
// An empty leg or a leg with zero present value has duration 0.

import rate;

namespace cashflow;

const SIMPLE: i32 = 0;
const MODIFIED: i32 = 1;
const MACAULAY: i32 = 2;

fn step_discount(r: f64, compounding: i32, freq: i32, dt: f64, first: bool, last: bool) -> f64, bool {
    var use = compounding;
    if compounding == rate::SIMPLE_THEN_COMPOUNDED {
        if first { use = rate::SIMPLE; } else { use = rate::COMPOUNDED; }
    }
    if compounding == rate::COMPOUNDED_THEN_SIMPLE {
        if last { use = rate::SIMPLE; } else { use = rate::COMPOUNDED; }
    }
    return rate::discount_factor(r, use, freq, dt);
}

fn simple_duration(times: f64[:], amounts: f64[:], r: f64, compounding: i32, freq: i32) -> f64, bool {
    if times.len == 0 || times.len != amounts.len { return 0.0, true; }
    var df = 1.0;
    var npv = 0.0;
    var weighted = 0.0;
    var prev = 0.0;
    var i: i64 = 0;
    let last = times.len - 1;
    while i < times.len {
        let step, ok = step_discount(r, compounding, freq, times[i] - prev, i == 0, i == last);
        if !ok || step == 0.0 { return 0.0, false; }
        df *= step;
        npv += amounts[i] * df;
        weighted += times[i] * amounts[i] * df;
        prev = times[i];
        i += 1;
    }
    if npv == 0.0 { return 0.0, true; }
    return weighted / npv, true;
}

fn duration(times: f64[:], amounts: f64[:], r: f64, compounding: i32, freq: i32, kind: i32) -> f64, bool {
    if times.len == 0 { return 0.0, true; }
    if kind != SIMPLE && kind != MODIFIED && kind != MACAULAY { return 0.0, false; }
    let simple, ok = simple_duration(times, amounts, r, compounding, freq);
    if !ok { return 0.0, false; }
    if simple == 0.0 { return 0.0, true; }
    if kind == SIMPLE { return simple, true; }
    return 0.0, false;
}

fn convexity(times: f64[:], amounts: f64[:], r: f64, compounding: i32, freq: i32) -> f64, bool {
    let simple, ok = simple_duration(times, amounts, r, compounding, freq);
    if !ok { return 0.0, false; }
    if simple == 0.0 { return 0.0, true; }
    return 0.0, false;
}

fn basis_point_value(times: f64[:], amounts: f64[:], r: f64, compounding: i32, freq: i32) -> f64, bool {
    let simple, ok = simple_duration(times, amounts, r, compounding, freq);
    if !ok { return 0.0, false; }
    if simple == 0.0 { return 0.0, true; }
    return 0.0, false;
}
