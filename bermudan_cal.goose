// Calibration of the BermudanSwaption example's diagonal.
// Five European swaptions, 1x5 through 5x1, on the flat 4.875825% curve.
// SwaptionHelper builds them on Euribor6M: semiannual Actual/360, nominal 1,
// receiver at the fair rate. Hull-White prices them with Jamshidian's
// decomposition. G2 uses the analytic engine with range 6 and 16 trapezoids.
// The helper's residual is the relative price error.
// ponytail: numerical Hull-White and Black-Karasinski stay out. Their
// calibration engines are trees on these helpers, not the bermudan lattice.

import math;
import date;
import period;
import calendar;
import markets;
import schedule;
import daycount;
import black;
import normal;

namespace bermudan_cal;

const RATE: f64 = 0.04875825;
const SQRT_EPS: f64 = 1.4901161193847656e-8;

fn yf(d1: date::Date, d2: date::Date) -> f64, bool {
    let blank = date::blank();
    return daycount::year_fraction(daycount::actual365_fixed(), d1, d2, blank, blank);
}

fn yf360(d1: date::Date, d2: date::Date) -> f64, bool {
    let blank = date::blank();
    return daycount::year_fraction(daycount::actual360(), d1, d2, blank, blank);
}

fn df(t: f64) -> f64 { exp(-RATE * t) }

fn market_vol(which: i64) -> f64 {
    if which == 0 { return 0.1148; }
    if which == 1 { return 0.1108; }
    if which == 2 { return 0.1070; }
    if which == 3 { return 0.0951; }
    return 0.1000;
}

fn b_hw(a: f64, t: f64, maturity: f64) -> f64 {
    let dt = maturity - t;
    if a < SQRT_EPS { return dt; }
    return (1.0 - exp(-a * dt)) / a;
}

fn hw_a(a: f64, sigma: f64, t: f64, maturity: f64) -> f64 {
    let bond = b_hw(a, t, maturity);
    let bond0 = b_hw(a, 0.0, 2.0 * t);
    let temp = sigma * bond;
    let value = bond * RATE - 0.25 * temp * temp * bond0;
    return exp(value) * df(maturity) / df(t);
}

fn hw_bond(a: f64, sigma: f64, t: f64, maturity: f64, r: f64) -> f64 {
    return hw_a(a, sigma, t, maturity) * exp(-b_hw(a, t, maturity) * r);
}

fn hw_std(a: f64, sigma: f64, maturity: f64, bond_start: f64, bond_maturity: f64) -> f64 {
    if a < SQRT_EPS {
        return sigma * b_hw(a, bond_start, bond_maturity) * sqrt(maturity);
    }
    let c = exp(-2.0 * a * (bond_start - maturity)) - exp(-2.0 * a * bond_start) - 2.0 * (exp(-a * (bond_start + bond_maturity - 2.0 * maturity)) - exp(-a * (bond_start + bond_maturity))) + exp(-2.0 * a * (bond_maturity - maturity)) - exp(-2.0 * a * bond_maturity);
    var floor = c;
    if floor < 0.0 { floor = 0.0; }
    return sigma / (a * sqrt(2.0 * a)) * sqrt(floor);
}

// Fair rate, Black price, exercise time, and swap start. Pay times are Actual/365.
fn quote(which: i64, pay: f64[>..] &, tau: f64[>..] &) -> f64, f64, f64, f64, bool {
    if which < 0 || which > 4 { return 0.0, 0.0, 0.0, 0.0, false; }
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    let settle, sok = date::from_ymd(19, 2, 2002);
    if !sok { return 0.0, 0.0, 0.0, 0.0, false; }
    let maturity_n = (which + 1) as i32;
    let length_n = (5 - which) as i32;
    let exercise, eok = calendar::advance(markets::TARGET, settle, maturity_n, period::YEARS, calendar::MODIFIED_FOLLOWING, false, empty, empty);
    if !eok { return 0.0, 0.0, 0.0, 0.0, false; }
    let start, aok = calendar::advance(markets::TARGET, exercise, 2, period::DAYS, calendar::MODIFIED_FOLLOWING, false, empty, empty);
    if !aok { return 0.0, 0.0, 0.0, 0.0, false; }
    let end, mok = calendar::advance(markets::TARGET, start, length_n, period::YEARS, calendar::MODIFIED_FOLLOWING, false, empty, empty);
    if !mok { return 0.0, 0.0, 0.0, 0.0, false; }
    var buf: i32[16] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    let n_dates, fok = schedule::build(start, end, 6, period::MONTHS, markets::TARGET, calendar::MODIFIED_FOLLOWING, calendar::MODIFIED_FOLLOWING, schedule::FORWARD, false, buf);
    if !fok || n_dates < 2 { return 0.0, 0.0, 0.0, 0.0, false; }
    let n = n_dates as i64;
    let exercise_t, etok = yf(settle, exercise);
    let start_d, sdok = date::from_serial(buf[0]);
    if !etok || !sdok || exercise_t <= 0.0 { return 0.0, 0.0, 0.0, 0.0, false; }
    let value_t, vtok = yf(settle, start_d);
    if !vtok { return 0.0, 0.0, 0.0, 0.0, false; }
    var level = 0.0;
    var float_npv = 0.0;
    var i: i64 = 0;
    while i < n - 1 {
        let rs, rso = date::from_serial(buf[i]);
        let re, reo = date::from_serial(buf[i + 1]);
        if !rso || !reo { return 0.0, 0.0, 0.0, 0.0, false; }
        let span, span_ok = yf360(rs, re);
        let t0, t0ok = yf(settle, rs);
        let t1, t1ok = yf(settle, re);
        if !span_ok || !t0ok || !t1ok || span == 0.0 { return 0.0, 0.0, 0.0, 0.0, false; }
        let disc1 = df(t1);
        float_npv += (df(t0) / disc1 - 1.0) * disc1;
        level += span * disc1;
        pay.push(t1);
        tau.push(span);
        i += 1;
    }
    if level == 0.0 || pay.len == 0 { return 0.0, 0.0, 0.0, 0.0, false; }
    let fair = float_npv / level;
    let vol = market_vol(which);
    let std = vol * sqrt(exercise_t);
    let black_px, bok = black::black(black::CALL, fair, fair, std, level, 0.0);
    if !bok { return 0.0, 0.0, 0.0, 0.0, false; }
    return fair, black_px, exercise_t, value_t, true;
}

// Model price and Black price of diagonal swaption `which` (0 is 1x5).
fn hw_price(a: f64, sigma: f64, which: i64) -> f64, f64, bool {
    if a <= 0.0 || sigma < 0.0 || which < 0 || which > 4 { return 0.0, 0.0, false; }
    var pay: f64[>..] = [];
    var tau: f64[>..] = [];
    let fair, black_px, exercise_t, value_t, qok = quote(which, pay, tau);
    if !qok { return 0.0, 0.0, false; }

    var amount: f64[>..] = [];
    var i: i64 = 0;
    while i < pay.len {
        amount.push(fair * tau[i]);
        i += 1;
    }
    let last = amount.len - 1;
    amount[last] += 1.0;

    fn gap(r: f64) -> f64 {
        var sum = 0.0;
        var k: i64 = 0;
        while k < pay.len {
            sum += amount[k] * hw_bond(a, sigma, exercise_t, pay[k], r) / hw_bond(a, sigma, exercise_t, value_t, r);
            k += 1;
        }
        return 1.0 - sum;
    }

    var lo = -2.0;
    var hi = 2.0;
    var flo = gap(lo);
    var fhi = gap(hi);
    if flo * fhi > 0.0 {
        lo = -10.0;
        hi = 10.0;
        flo = gap(lo);
        fhi = gap(hi);
        if flo * fhi > 0.0 { return 0.0, black_px, false; }
    }
    var guard_n: i64 = 0;
    var root = 0.0;
    while guard_n < 80 {
        root = 0.5 * (lo + hi);
        let fm = gap(root);
        if abs(fm) < 1.0e-12 || hi - lo < 1.0e-14 {
            guard_n = 80;
        } else if flo * fm <= 0.0 {
            hi = root;
            fhi = fm;
        } else {
            lo = root;
            flo = fm;
        }
        guard_n += 1;
    }

    var model = 0.0;
    i = 0;
    while i < pay.len {
        let strike = hw_bond(a, sigma, exercise_t, pay[i], root) / hw_bond(a, sigma, exercise_t, value_t, root);
        let std_b = hw_std(a, sigma, exercise_t, value_t, pay[i]);
        let forward = df(pay[i]);
        let bond_strike = df(value_t) * strike;
        let opt, ook = black::black(black::CALL, bond_strike, forward, std_b, 1.0, 0.0);
        if !ook { return 0.0, black_px, false; }
        model += amount[i] * opt;
        i += 1;
    }
    if is_nan(model) || is_inf(model) { return 0.0, black_px, false; }
    return model, black_px, true;
}

fn decay_ratio(x: f64) -> f64 {
    if abs(x) < 1.0e-8 { return 1.0 - 0.5 * x; }
    return (1.0 - exp(-x)) / x;
}

fn exp_m1(x: f64) -> f64 {
    if abs(x) < 1.0e-5 { return x + 0.5 * x * x + x * x * x / 6.0; }
    return exp(x) - 1.0;
}

// G2::V's kernel. Series when u+v is small, closed form otherwise.
fn variance_kernel(u_in: f64, v_in: f64) -> f64 {
    var u = u_in;
    var v = v_in;
    if u < v {
        let swap = u;
        u = v;
        v = swap;
    }
    if u + v <= 2.0 {
        let s = u + v;
        var poly = 2.0;
        var u_power = u;
        var v_power = v;
        var factorial = 6.0;
        var sign = 1.0;
        var sum = 0.0;
        var k: i64 = 2;
        while k < 60 {
            let term = sign * poly / factorial;
            sum += term;
            if abs(term) < 2.2204460492503131e-18 * abs(sum) { return sum; }
            poly = s * poly + u_power + v_power;
            u_power *= u;
            v_power *= v;
            factorial *= k + 2;
            sign = -sign;
            k += 1;
        }
        return sum;
    }
    if v >= 0.5 {
        return (1.0 - decay_ratio(u) - decay_ratio(v) + decay_ratio(u + v)) / (u * v);
    }
    var omega = 0.0;
    var term = 0.5;
    var k: i64 = 2;
    while k < 40 {
        omega += term;
        term *= -v / (k + 1);
        if abs(term) < 2.2204460492503131e-18 * abs(omega) { k = 40; }
        else { k += 1; }
    }
    let difference = (u * exp(-u) * exp_m1(-v) - v * exp_m1(-u)) / (u * (u + v));
    return (v * omega - difference) / (u * v);
}

fn g2_v(t: f64, a: f64, sigma: f64, b: f64, eta: f64, rho: f64) -> f64 {
    if t == 0.0 { return 0.0; }
    let u = a * t;
    let v = b * t;
    let value = sigma * sigma * variance_kernel(u, u) + eta * eta * variance_kernel(v, v) + 2.0 * rho * sigma * eta * variance_kernel(u, v);
    return t * t * t * value;
}

fn g2_a_factor(t: f64, maturity: f64, a: f64, sigma: f64, b: f64, eta: f64, rho: f64) -> f64 {
    let span = maturity - t;
    return df(maturity) / df(t) * exp(0.5 * (g2_v(span, a, sigma, b, eta, rho) - g2_v(maturity, a, sigma, b, eta, rho) + g2_v(t, a, sigma, b, eta, rho)));
}

fn g2_b_factor(speed: f64, t: f64) -> f64 {
    if speed < SQRT_EPS { return t; }
    return (1.0 - exp(-speed * t)) / speed;
}

// G2SwaptionEngine, receiver, range 6, 16 trapezoids. Same Black price as hw_price.
fn g2_price(a: f64, sigma: f64, b: f64, eta: f64, rho: f64, which: i64) -> f64, f64, bool {
    if a <= 0.0 || sigma < 0.0 || b <= 0.0 || eta < 0.0 || rho <= -1.0 || rho >= 1.0 { return 0.0, 0.0, false; }
    if which < 0 || which > 4 { return 0.0, 0.0, false; }
    var pay: f64[>..] = [];
    var tau: f64[>..] = [];
    let fair, black_px, exercise_t, start_t, qok = quote(which, pay, tau);
    if !qok || exercise_t <= 0.0 { return 0.0, 0.0, false; }
    let n = pay.len;
    let sigmax = sigma * sqrt(0.5 * (1.0 - exp(-2.0 * a * start_t)) / a);
    let sigmay = eta * sqrt(0.5 * (1.0 - exp(-2.0 * b * start_t)) / b);
    if sigmax <= 0.0 || sigmay <= 0.0 { return 0.0, black_px, false; }
    let rhoxy = rho * eta * sigma * (1.0 - exp(-(a + b) * start_t)) / ((a + b) * sigmax * sigmay);
    if rhoxy <= -1.0 || rhoxy >= 1.0 { return 0.0, black_px, false; }
    let temp_x = sigma * sigma / (a * a);
    let mux = -((temp_x + rho * sigma * eta / (a * b)) * (1.0 - exp(-a * start_t)) - 0.5 * temp_x * (1.0 - exp(-2.0 * a * start_t)) - rho * sigma * eta / (b * (a + b)) * (1.0 - exp(-(a + b) * start_t)));
    let temp_y = eta * eta / (b * b);
    let muy = -((temp_y + rho * sigma * eta / (a * b)) * (1.0 - exp(-b * start_t)) - 0.5 * temp_y * (1.0 - exp(-2.0 * b * start_t)) - rho * sigma * eta / (a * (a + b)) * (1.0 - exp(-(a + b) * start_t)));
    var factor: f64[>..] = [];
    var ba: f64[>..] = [];
    var bb: f64[>..] = [];
    var i: i64 = 0;
    while i < n {
        factor.push(g2_a_factor(start_t, pay[i], a, sigma, b, eta, rho));
        ba.push(g2_b_factor(a, pay[i] - start_t));
        bb.push(g2_b_factor(b, pay[i] - start_t));
        i += 1;
    }
    let txy = sqrt(1.0 - rhoxy * rhoxy);
    let w = -1.0;

    fn at(x: f64) -> f64 {
        var lambda: f64[>..] = [];
        var k: i64 = 0;
        while k < n {
            var span = pay[k] - start_t;
            if k > 0 { span = pay[k] - pay[k - 1]; }
            var coupon = fair * span;
            if k == n - 1 { coupon = 1.0 + fair * span; }
            lambda.push(coupon * factor[k] * exp(-ba[k] * x));
            k += 1;
        }
        fn y_gap(y: f64) -> f64 {
            var sum = 1.0;
            var j: i64 = 0;
            while j < n {
                sum -= lambda[j] * exp(-bb[j] * y);
                j += 1;
            }
            return sum;
        }
        var bound = 10.0 * sigmay;
        if bound < 1.0 { bound = 1.0; }
        var lo = -bound;
        var hi = bound;
        var flo = y_gap(lo);
        var fhi = y_gap(hi);
        if flo * fhi > 0.0 { return 0.0; }
        var yb = 0.0;
        var steps: i64 = 0;
        while steps < 60 {
            yb = 0.5 * (lo + hi);
            let fm = y_gap(yb);
            if abs(fm) < 1.0e-8 || hi - lo < 1.0e-10 { steps = 60; }
            else if flo * fm <= 0.0 {
                hi = yb;
                fhi = fm;
            } else {
                lo = yb;
                flo = fm;
            }
            steps += 1;
        }
        let h1 = (yb - muy) / (sigmay * txy) - rhoxy * (x - mux) / (sigmax * txy);
        var value = normal::cdf(-w * h1);
        k = 0;
        while k < n {
            let h2 = h1 + bb[k] * sigmay * txy;
            let kappa = -bb[k] * (muy - 0.5 * txy * txy * sigmay * sigmay * bb[k] + rhoxy * sigmay * (x - mux) / sigmax);
            value -= lambda[k] * exp(kappa) * normal::cdf(-w * h2);
            k += 1;
        }
        let z = (x - mux) / sigmax;
        return exp(-0.5 * z * z) * value / (sigmax * sqrt(2.0 * PI));
    }

    let upper = mux + 6.0 * sigmax;
    let lower = mux - 6.0 * sigmax;
    let dx = (upper - lower) / 16.0;
    var sum = 0.5 * (at(lower) + at(upper));
    var step: i64 = 1;
    while step < 16 {
        sum += at(lower + step * dx);
        step += 1;
    }
    let model = w * df(start_t) * sum * dx;
    if is_nan(model) || is_inf(model) { return 0.0, black_px, false; }
    return model, black_px, true;
}

fn hw_cost(a: f64, sigma: f64) -> f64 {
    var sum = 0.0;
    var i: i64 = 0;
    while i < 5 {
        let model, market, ok = hw_price(a, sigma, i);
        if !ok || market <= 0.0 { return 1.0e8; }
        let gap_px = (model - market) / market;
        sum += gap_px * gap_px;
        i += 1;
    }
    return sum;
}

// Pattern search on a positive (a, sigma). Relative-price residual, same
// error SwaptionHelper uses by default.
fn calibrate_hw() -> f64, f64, bool {
    var best_a = 0.05;
    var best_s = 0.006;
    var best = hw_cost(best_a, best_s);
    if best >= 1.0e8 { return 0.0, 0.0, false; }
    var step_a = 0.03;
    var step_s = 0.003;
    var round: i64 = 0;
    while round < 48 {
        var improved = false;
        var da: f64[8] = [1.0, -1.0, 0.0, 0.0, 1.0, 1.0, -1.0, -1.0];
        var ds: f64[8] = [0.0, 0.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0];
        var k: i64 = 0;
        while k < 8 {
            let trial_a = best_a + da[k] * step_a;
            let trial_s = best_s + ds[k] * step_s;
            if trial_a > 1.0e-4 && trial_s > 1.0e-6 {
                let cost = hw_cost(trial_a, trial_s);
                if cost < best {
                    best = cost;
                    best_a = trial_a;
                    best_s = trial_s;
                    improved = true;
                }
            }
            k += 1;
        }
        if !improved {
            step_a *= 0.5;
            step_s *= 0.5;
        }
        if step_a < 1.0e-5 && step_s < 1.0e-6 { return best_a, best_s, true; }
        round += 1;
    }
    return best_a, best_s, true;
}

fn g2_cost(a: f64, sigma: f64, b: f64, eta: f64, rho: f64) -> f64 {
    var sum = 0.0;
    var i: i64 = 0;
    while i < 5 {
        let model, market, ok = g2_price(a, sigma, b, eta, rho, i);
        if !ok || market <= 0.0 { return 1.0e8; }
        let gap_px = (model - market) / market;
        sum += gap_px * gap_px;
        i += 1;
    }
    return sum;
}

// Coordinate search from the example's usual G2 start. Five parameters,
// relative price residual, same helper error as calibrate_hw.
fn calibrate_g2() -> f64, f64, f64, f64, f64, bool {
    var a = 0.050053;
    var sigma = 0.0094424;
    var b = 0.05005;
    var eta = 0.0094424;
    var rho = -0.76301;
    var best = g2_cost(a, sigma, b, eta, rho);
    if best >= 1.0e8 { return 0.0, 0.0, 0.0, 0.0, 0.0, false; }
    var step = 0.004;
    var step_r = 0.04;
    var round: i64 = 0;
    while round < 24 {
        var improved = false;
        var p: i64 = 0;
        while p < 5 {
            var dir: i64 = -1;
            while dir <= 1 {
                if dir != 0 {
                    var ta = a;
                    var ts = sigma;
                    var tb = b;
                    var te = eta;
                    var tr = rho;
                    let jump = dir as f64;
                    if p == 0 { ta += jump * step; }
                    if p == 1 { ts += jump * step * 0.2; }
                    if p == 2 { tb += jump * step; }
                    if p == 3 { te += jump * step * 0.2; }
                    if p == 4 { tr += jump * step_r; }
                    if ta > 1.0e-3 && ts > 1.0e-4 && tb > 1.0e-3 && te > 1.0e-4 && tr > -0.99 && tr < 0.99 {
                        let cost = g2_cost(ta, ts, tb, te, tr);
                        if cost < best {
                            best = cost;
                            a = ta;
                            sigma = ts;
                            b = tb;
                            eta = te;
                            rho = tr;
                            improved = true;
                        }
                    }
                }
                dir += 1;
            }
            p += 1;
        }
        if !improved {
            step *= 0.5;
            step_r *= 0.5;
        }
        if step < 1.0e-4 { return a, sigma, b, eta, rho, true; }
        round += 1;
    }
    return a, sigma, b, eta, rho, true;
}
