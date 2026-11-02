// Interest-rate compounding from QuantLib's InterestRate.
// SimpleThenCompounded and CompoundedThenSimple are rejected here, as
// QuantLib rejects them on the direct compound-factor path.

import math;

namespace rate;

const SIMPLE: i32 = 0;
const COMPOUNDED: i32 = 1;
const CONTINUOUS: i32 = 2;
const SIMPLE_THEN_COMPOUNDED: i32 = 3;
const COMPOUNDED_THEN_SIMPLE: i32 = 4;

fn compound_factor(r: f64, compounding: i32, freq: i32, t: f64) -> f64, bool {
    if t < 0.0 { return 0.0, false; }
    if compounding == SIMPLE { return 1.0 + r * t, true; }
    if compounding == COMPOUNDED {
        if freq <= 0 { return 0.0, false; }
        return pow(1.0 + r / freq, freq * t), true;
    }
    if compounding == CONTINUOUS { return exp(r * t), true; }
    return 0.0, false;
}

fn discount_factor(r: f64, compounding: i32, freq: i32, t: f64) -> f64, bool {
    let cf, ok = compound_factor(r, compounding, freq, t);
    if !ok || cf == 0.0 { return 0.0, false; }
    return 1.0 / cf, true;
}

fn implied_rate(compound: f64, compounding: i32, freq: i32, t: f64) -> f64, bool {
    if compound <= 0.0 { return 0.0, false; }
    if compounding == SIMPLE_THEN_COMPOUNDED || compounding == COMPOUNDED_THEN_SIMPLE {
        return 0.0, false;
    }
    if compound == 1.0 {
        if t < 0.0 { return 0.0, false; }
        return 0.0, true;
    }
    if t <= 0.0 { return 0.0, false; }
    if compounding == SIMPLE { return (compound - 1.0) / t, true; }
    if compounding == COMPOUNDED {
        if freq <= 0 { return 0.0, false; }
        return (pow(compound, 1.0 / (freq * t)) - 1.0) * freq, true;
    }
    if compounding == CONTINUOUS { return log(compound) / t, true; }
    return 0.0, false;
}

fn equivalent(r: f64, from_comp: i32, from_freq: i32, to_comp: i32, to_freq: i32, t: f64) -> f64, bool {
    let cf, ok = compound_factor(r, from_comp, from_freq, t);
    if !ok { return 0.0, false; }
    return implied_rate(cf, to_comp, to_freq, t);
}

// Caller-owned evaluation date. QuantLib keeps this on a singleton.
struct Settings { evaluation: i32 }
