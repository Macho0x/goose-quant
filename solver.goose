// Brent from QuantLib's Numerical Recipes port, and a one-function Newton.
// The block is f(it). Brent needs a bracket. Newton steps the slope.

namespace solver;

fn abs(x: f64) -> f64 {
    if x < 0.0 { return -x; }
    return x;
}

fn sign(a: f64, b: f64) -> f64 {
    if b >= 0.0 { return abs(a); }
    return -abs(a);
}

fn brent<F>(guess: f64, x_min: f64, x_max: f64, accuracy: f64, max_eval: i32) -> f64, bool {
    if accuracy <= 0.0 || x_min >= x_max || guess <= x_min || guess >= x_max { return 0.0, false; }
    var acc = accuracy;
    let eps = 2.220446049250313e-16;
    if acc < eps { acc = eps; }
    let fx_min = F(x_min);
    if fx_min == 0.0 { return x_min, true; }
    let fx_max = F(x_max);
    if fx_max == 0.0 { return x_max, true; }
    if fx_min * fx_max >= 0.0 { return 0.0, false; }

    var x_lo = x_min;
    var x_hi = x_max;
    var f_lo = fx_min;
    var f_hi = fx_max;
    var root = guess;
    var evals: i32 = 3;
    var froot = F(root);
    if froot * f_lo < 0.0 {
        x_hi = x_lo;
        f_hi = f_lo;
    } else {
        x_lo = x_hi;
        f_lo = f_hi;
    }
    var d = root - x_hi;
    var e = d;
    while evals <= max_eval {
        if (froot > 0.0 && f_hi > 0.0) || (froot < 0.0 && f_hi < 0.0) {
            x_hi = x_lo;
            f_hi = f_lo;
            e = root - x_lo;
            d = e;
        }
        if abs(f_hi) < abs(froot) {
            x_lo = root;
            root = x_hi;
            x_hi = x_lo;
            f_lo = froot;
            froot = f_hi;
            f_hi = f_lo;
        }
        let x_acc = 2.0 * eps * abs(root) + 0.5 * acc;
        let x_mid = (x_hi - root) / 2.0;
        if abs(x_mid) <= x_acc || froot == 0.0 { return root, true; }
        if abs(e) >= x_acc && abs(f_lo) > abs(froot) {
            let s = froot / f_lo;
            var p = 0.0;
            var q = 0.0;
            if x_lo == x_hi {
                p = 2.0 * x_mid * s;
                q = 1.0 - s;
            } else {
                q = f_lo / f_hi;
                let r = froot / f_hi;
                p = s * (2.0 * x_mid * q * (q - r) - (root - x_lo) * (r - 1.0));
                q = (q - 1.0) * (r - 1.0) * (s - 1.0);
            }
            if p > 0.0 { q = -q; }
            p = abs(p);
            let min1 = 3.0 * x_mid * q - abs(x_acc * q);
            let min2 = abs(e * q);
            var bound = min2;
            if min1 < min2 { bound = min1; }
            if 2.0 * p < bound {
                e = d;
                d = p / q;
            } else {
                d = x_mid;
                e = d;
            }
        } else {
            d = x_mid;
            e = d;
        }
        x_lo = root;
        f_lo = froot;
        if abs(d) > x_acc { root += d; }
        else { root += sign(x_acc, x_mid); }
        froot = F(root);
        evals += 1;
    }
    return root, false;
}

// ponytail: slope is a 1e-8 step. Pass an analytic derivative when a test needs it.
fn newton<F>(guess: f64, accuracy: f64, max_eval: i32) -> f64, bool {
    var x = guess;
    var n: i32 = 0;
    let step = 1.0e-8;
    while n < max_eval {
        let y = F(x);
        if abs(y) <= accuracy { return x, true; }
        let slope = (F(x + step) - y) / step;
        if slope == 0.0 { return 0.0, false; }
        x = x - y / slope;
        n += 1;
    }
    return x, false;
}
