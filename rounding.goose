// QuantLib Rounding. None returns the value. Closest rounds the first
// dropped digit when it is at least digit/10. Floor and Ceiling follow
// QuantLib's names: Floor rounds positives up and negatives down.

import math;

namespace rounding;

const NONE: i32 = 0;
const UP: i32 = 1;
const DOWN: i32 = 2;
const CLOSEST: i32 = 3;
const FLOOR: i32 = 4;
const CEILING: i32 = 5;

fn pow10(precision: i32) -> f64 {
    if precision <= 0 { return 1.0; }
    if precision == 1 { return 10.0; }
    if precision == 2 { return 100.0; }
    if precision == 3 { return 1000.0; }
    if precision == 4 { return 10000.0; }
    if precision == 5 { return 100000.0; }
    if precision == 6 { return 1000000.0; }
    if precision == 7 { return 10000000.0; }
    if precision == 8 { return 100000000.0; }
    if precision == 9 { return 1000000000.0; }
    if precision == 10 { return 10000000000.0; }
    if precision == 11 { return 100000000000.0; }
    if precision == 12 { return 1000000000000.0; }
    if precision == 13 { return 10000000000000.0; }
    if precision == 14 { return 100000000000000.0; }
    if precision == 15 { return 1000000000000000.0; }
    return 10000000000000000.0;
}

fn apply(value: f64, precision: i32, kind: i32, digit: i32) -> f64 {
    if kind == NONE { return value; }
    let mult = pow10(precision);
    var neg = false;
    if value < 0.0 { neg = true; }
    var scaled = value;
    if neg { scaled = -scaled; }
    scaled *= mult;
    let integral = floor(scaled);
    let mod = scaled - integral;
    var kept = integral;
    let cut = digit / 10.0;
    if kind == UP {
        if mod != 0.0 { kept += 1.0; }
    } else if kind == CLOSEST {
        if mod >= cut { kept += 1.0; }
    } else if kind == FLOOR {
        if !neg && mod >= cut { kept += 1.0; }
    } else if kind == CEILING {
        if neg && mod >= cut { kept += 1.0; }
    }
    let back = kept / mult;
    if neg { return -back; }
    return back;
}
