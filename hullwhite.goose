// HullWhite::convexityBias. Kirikos and Novak, Risk, March 1997.

import math;

namespace hullwhite;

const EPS: f64 = 2.2204460492503131e-16;

fn duration(a: f64, x: f64) -> f64 {
    // ponytail: a under machine epsilon is the x limit. (1-exp(-a*x))/a above that.
    if a < EPS { return x; }
    return (1.0 - exp(-a * x)) / a;
}

fn convexity_bias(future_price: f64, t: f64, maturity: f64, sigma: f64, a: f64) -> f64, bool {
    if future_price < 0.0 || t < 0.0 || maturity < t || sigma < 0.0 || a < 0.0 { return 0.0, false; }
    let dt = maturity - t;
    let g = duration(a, dt);
    let bt = duration(a, t);
    let z = sigma * sigma * 0.5 * (duration(a, 2.0 * t) * g + bt * bt);
    if dt < EPS { return z, true; }
    let rate = (100.0 - future_price) / 100.0;
    return (1.0 - exp(-z * g)) * (rate + 1.0 / dt), true;
}
