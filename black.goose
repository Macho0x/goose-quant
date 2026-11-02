// Black's formula on a forward, QuantLib's blackFormula.
// Call is +1 and put is -1, matching Option::Type. std_dev is volatility
// times the square root of time, the value QuantLib calls stdDev.

import math;
import normal;
import solver;

namespace black;

const CALL: i32 = 1;
const PUT: i32 = -1;

fn black(option: i32, strike: f64, forward: f64, std_dev: f64, discount: f64, displacement: f64) -> f64, bool {
    if option != CALL && option != PUT { return 0.0, false; }
    if displacement < 0.0 { return 0.0, false; }
    if strike + displacement < 0.0 { return 0.0, false; }
    if forward + displacement <= 0.0 { return 0.0, false; }
    if std_dev < 0.0 || discount <= 0.0 { return 0.0, false; }
    let sign = option;
    if std_dev == 0.0 {
        var intrinsic = (forward - strike) * sign;
        if intrinsic < 0.0 { intrinsic = 0.0; }
        return intrinsic * discount, true;
    }
    var f = forward + displacement;
    var k = strike + displacement;
    if k == 0.0 {
        if option == CALL { return f * discount, true; }
        return 0.0, true;
    }
    let d1 = log(f / k) / std_dev + 0.5 * std_dev;
    let d2 = d1 - std_dev;
    let nd1 = normal::cdf(sign * d1);
    let nd2 = normal::cdf(sign * d2);
    let result = discount * sign * (f * nd1 - k * nd2);
    if result < -1.0e-10 { return 0.0, false; }
    if result < 0.0 { return 0.0, true; }
    return result, true;
}

fn delta(option: i32, strike: f64, forward: f64, std_dev: f64, discount: f64, displacement: f64) -> f64, bool {
    if option != CALL && option != PUT { return 0.0, false; }
    if displacement < 0.0 || strike + displacement < 0.0 || forward + displacement <= 0.0 { return 0.0, false; }
    if std_dev < 0.0 || discount <= 0.0 { return 0.0, false; }
    let sign = option;
    if std_dev == 0.0 {
        var side = (forward - strike) * sign;
        if side > 0.0 { return sign * discount, true; }
        return 0.0, true;
    }
    var f = forward + displacement;
    var k = strike + displacement;
    if k == 0.0 {
        if option == CALL { return discount, true; }
        return 0.0, true;
    }
    let d1 = log(f / k) / std_dev + 0.5 * std_dev;
    return sign * normal::cdf(sign * d1) * discount, true;
}

fn implied_std(option: i32, strike: f64, forward: f64, price: f64, discount: f64, displacement: f64) -> f64, bool {
    if price < 0.0 { return 0.0, false; }
    return solver::brent(0.2, 1.0e-8, 5.0, 1.0e-12, 80) {
        let px, ok = black(option, strike, forward, it, discount, displacement);
        if ok { px - price } else { 1.0 }
    };
}
