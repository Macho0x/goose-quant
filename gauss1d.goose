// G2++ analytic zero bond. QuantLib G2::discountBond on a flat continuous curve.
// testG2DiscountBondForSmallMeanReversion locks the price with 60-digit values.
// variance_kernel is the small-mean-reversion expansion of V(t).

import math;

namespace gauss1d;

const EPS: f64 = 2.2204460492503131e-16;

fn expm1(x: f64) -> f64 {
    if x == 0.0 { return 0.0; }
    let u = exp(x);
    if u == 1.0 { return x; }
    if u == 0.0 { return -1.0; }
    return (u - 1.0) * x / log(u);
}

fn decay(x: f64) -> f64 {
    return -expm1(-x) / x;
}

fn variance_kernel(u: f64, v: f64) -> f64 {
    var uu = u;
    var vv = v;
    if uu < vv {
        let held = uu;
        uu = vv;
        vv = held;
    }
    if uu + vv <= 2.0 {
        let s = uu + vv;
        var p = 2.0;
        var u_power = uu;
        var v_power = vv;
        var factorial = 6.0;
        var sign = 1.0;
        var sum = 0.0;
        var k: i64 = 2;
        while k < 60 {
            let term = sign * p / factorial;
            sum += term;
            if abs(term) < 0.01 * EPS * abs(sum) { return sum; }
            p = s * p + u_power + v_power;
            u_power *= uu;
            v_power *= vv;
            factorial *= (k + 2.0);
            sign = -sign;
            k += 1;
        }
        return sum;
    }
    if vv >= 0.5 {
        return (1.0 - decay(uu) - decay(vv) + decay(uu + vv)) / (uu * vv);
    }
    var omega = 0.0;
    var term = 0.5;
    var k: i64 = 2;
    while k < 40 {
        omega += term;
        term *= -vv / (k + 1.0);
        if abs(term) < 0.01 * EPS * abs(omega) { break; }
        k += 1;
    }
    let difference = (uu * exp(-uu) * expm1(-vv) - vv * expm1(-uu)) / (uu * (uu + vv));
    return (vv * omega - difference) / (uu * vv);
}

fn b_factor(kappa: f64, tau: f64) -> f64 {
    return -expm1(-kappa * tau) / kappa;
}

fn v_factor(t: f64, a: f64, sigma: f64, b: f64, eta: f64, rho: f64) -> f64 {
    let u = a * t;
    let v = b * t;
    let valuex = sigma * sigma * variance_kernel(u, u);
    let valuey = eta * eta * variance_kernel(v, v);
    let cross = 2.0 * rho * sigma * eta * variance_kernel(u, v);
    return t * t * t * (valuex + valuey + cross);
}

fn discount_bond(r: f64, a: f64, sigma: f64, b: f64, eta: f64, rho: f64, t: f64, maturity: f64, x: f64, y: f64) -> f64, bool {
    if a <= 0.0 || sigma <= 0.0 || b <= 0.0 || eta <= 0.0 { return 0.0, false; }
    if rho < -1.0 || rho > 1.0 || t < 0.0 || maturity < t { return 0.0, false; }
    let tau = maturity - t;
    let vx = v_factor(tau, a, sigma, b, eta, rho);
    let vm = v_factor(maturity, a, sigma, b, eta, rho);
    let vt = v_factor(t, a, sigma, b, eta, rho);
    let level = exp(-r * tau) * exp(0.5 * (vx - vm + vt));
    let px = level * exp(-b_factor(a, tau) * x - b_factor(b, tau) * y);
    if is_nan(px) || is_inf(px) { return 0.0, false; }
    return px, true;
}
