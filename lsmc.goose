// American put from MakeMCAmericanEngine<PseudoRandom>.
// One hundred equal steps, antithetic pairs, and 4096 calibration samples.
// An unset calibration seed is Null<Size>(), 2147483647. The engine compares
// that value with Null<Real>() and does not replace it, so calibration draws
// use 2147483647 while pricing uses the caller's seed.
// Drawing stops when the error estimate falls to the tolerance, and never
// past 200000 samples.
// On in-the-money paths the put is linear in the scaled spot, so it is already
// in the monomial span. ponytail: regress 1, x, x^2; the payoff column would
// only matter for a non-linear exercise value.

import math;
import normal;
import mt;

namespace lsmc;

const STEPS: i64 = 100;
const POINTS: i64 = 101;
const CALIB_SAMPLES: i64 = 4096;
const CALIB_SEED: u32 = 2147483647;
const MIN_ITM: i64 = 4;
const FIRST: i64 = 1023;
const CAP: i64 = 200000;

fn put_pay(s: f64, strike: f64) -> f64 {
    let p = strike - s;
    if p > 0.0 { return p; }
    return 0.0;
}

fn solve3(g: f64[:], rhs: f64[:], c: f64[:]) -> bool {
    if g.len < 9 || rhs.len < 3 || c.len < 3 { return false; }
    let scale = g[0];
    if scale < MIN_ITM { return false; }
    var a: f64[9] = [0.0; 9];
    var k: i64 = 0;
    while k < 9 {
        a[k] = g[k];
        k += 1;
    }
    let floor = scale * 1.0e-12;
    var i: i64 = 0;
    while i < 3 {
        var j: i64 = 0;
        while j <= i {
            var sum = a[i * 3 + j];
            var t: i64 = 0;
            while t < j {
                sum -= a[i * 3 + t] * a[j * 3 + t];
                t += 1;
            }
            if i == j {
                if sum <= floor { return false; }
                a[i * 3 + i] = sqrt(sum);
            } else {
                let diag = a[j * 3 + j];
                if diag == 0.0 { return false; }
                a[i * 3 + j] = sum / diag;
            }
            j += 1;
        }
        i += 1;
    }
    var y: f64[3] = [0.0, 0.0, 0.0];
    i = 0;
    while i < 3 {
        var sum = rhs[i];
        var t: i64 = 0;
        while t < i {
            sum -= a[i * 3 + t] * y[t];
            t += 1;
        }
        let diag = a[i * 3 + i];
        if diag == 0.0 { return false; }
        y[i] = sum / diag;
        i += 1;
    }
    var out: f64[3] = [0.0, 0.0, 0.0];
    i = 2;
    while i >= 0 {
        var sum = y[i];
        var t: i64 = i + 1;
        while t < 3 {
            sum -= a[t * 3 + i] * out[t];
            t += 1;
        }
        let diag = a[i * 3 + i];
        if diag == 0.0 { return false; }
        out[i] = sum / diag;
        i -= 1;
    }
    c[0] = out[0];
    c[1] = out[1];
    c[2] = out[2];
    return true;
}

fn draw_pair(g: mt::Twister&, path: f64[:], anti: f64[:], spot: f64, sig: f64, drift: f64) -> bool {
    if path.len < POINTS || anti.len < POINTS { return false; }
    path[0] = spot;
    anti[0] = spot;
    var sp = spot;
    var sn = spot;
    var k: i64 = 0;
    while k < STEPS {
        let z, ok = normal::inv_cdf(mt::next_real(g));
        if !ok { return false; }
        sp = sp * exp(sig * z + drift);
        sn = sn * exp(-sig * z + drift);
        k += 1;
        path[k] = sp;
        anti[k] = sn;
    }
    return true;
}

fn rollback(path: f64[:], strike: f64, scale: f64, df: f64, coeff: f64[:]) -> f64 {
    var price = put_pay(path[STEPS], strike);
    var i: i64 = STEPS - 1;
    while i > 0 {
        price *= df;
        let exercise = put_pay(path[i], strike);
        if exercise > 0.0 {
            let x = path[i] * scale;
            let row = (i - 1) * 3;
            let cont = coeff[row] + x * (coeff[row + 1] + x * coeff[row + 2]);
            if cont < exercise { price = exercise; }
        }
        i -= 1;
    }
    return price * df;
}

fn fill(g: mt::Twister&, spots: f64[>..]&, npaths: i64, spot: f64, sig: f64, drift: f64) -> bool {
    if npaths <= 0 || (npaths & 1) != 0 { return false; }
    spots.resize(npaths * POINTS, 0.0);
    var path: f64[101] = [0.0; 101];
    var anti: f64[101] = [0.0; 101];
    var p: i64 = 0;
    while p < npaths {
        if !draw_pair(g, path, anti, spot, sig, drift) { return false; }
        var t: i64 = 0;
        let base = p * POINTS;
        let other = base + POINTS;
        while t < POINTS {
            spots[base + t] = path[t];
            spots[other + t] = anti[t];
            t += 1;
        }
        p += 2;
    }
    return true;
}

fn fit_step(spots: f64[:], value: f64[:], npaths: i64, step: i64, strike: f64, scale: f64, df: f64, coeff: f64[:]) {
    var g: f64[9] = [0.0; 9];
    var rhs: f64[3] = [0.0; 3];
    var n_itm: i64 = 0;
    var j: i64 = 0;
    while j < npaths {
        let s = spots[j * POINTS + step];
        let exercise = put_pay(s, strike);
        if exercise > 0.0 {
            let x = s * scale;
            let x2 = x * x;
            let y = df * value[j];
            rhs[0] += y;
            rhs[1] += x * y;
            rhs[2] += x2 * y;
            g[0] += 1.0;
            g[1] += x;
            g[2] += x2;
            g[3] += x;
            g[4] += x2;
            g[5] += x * x2;
            g[6] += x2;
            g[7] += x * x2;
            g[8] += x2 * x2;
            n_itm += 1;
        }
        j += 1;
    }
    var c: f64[3] = [0.0, 0.0, 0.0];
    if n_itm >= MIN_ITM {
        var trial: f64[3] = [0.0, 0.0, 0.0];
        if solve3(g, rhs, trial) {
            c[0] = trial[0];
            c[1] = trial[1];
            c[2] = trial[2];
        }
    }
    let row = (step - 1) * 3;
    coeff[row] = c[0];
    coeff[row + 1] = c[1];
    coeff[row + 2] = c[2];
    j = 0;
    while j < npaths {
        value[j] *= df;
        let s = spots[j * POINTS + step];
        let exercise = put_pay(s, strike);
        if exercise > 0.0 {
            let x = s * scale;
            let cont = c[0] + x * (c[1] + x * c[2]);
            if cont < exercise { value[j] = exercise; }
        }
        j += 1;
    }
}

fn calibrate(spots: f64[:], npaths: i64, strike: f64, scale: f64, df: f64, coeff: f64[>..]&) -> bool {
    if spots.len < npaths * POINTS { return false; }
    coeff.resize((STEPS - 1) * 3, 0.0);
    var value: f64[>..] = [];
    value.resize(npaths, 0.0);
    var j: i64 = 0;
    while j < npaths {
        value[j] = put_pay(spots[j * POINTS + STEPS], strike);
        j += 1;
    }
    var step: i64 = STEPS - 1;
    while step > 0 {
        fit_step(spots, value, npaths, step, strike, scale, df, coeff);
        step -= 1;
    }
    return true;
}

fn absorb(g: mt::Twister&, count: i64, spot: f64, strike: f64, sig: f64, drift: f64, df: f64, scale: f64, coeff: f64[:], sx: f64, sxx: f64) -> f64, f64, bool {
    var sum = sx;
    var sumsq = sxx;
    var path: f64[101] = [0.0; 101];
    var anti: f64[101] = [0.0; 101];
    var n: i64 = 0;
    while n < count {
        if !draw_pair(g, path, anti, spot, sig, drift) { return sum, sumsq, false; }
        let y1 = rollback(path, strike, scale, df, coeff);
        let y2 = rollback(anti, strike, scale, df, coeff);
        let y = 0.5 * (y1 + y2);
        sum += y;
        sumsq += y * y;
        n += 1;
    }
    return sum, sumsq, true;
}

fn stderr(sx: f64, sxx: f64, n: i64) -> f64 {
    var v = (sxx - sx * sx / n) / (n - 1.0);
    if v < 0.0 { v = 0.0; }
    return sqrt(v / n);
}

fn american_put(spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, tol: f64, seed: i64) -> f64, i64, bool {
    if spot <= 0.0 || strike <= 0.0 || vol < 0.0 || t <= 0.0 || tol <= 0.0 { return 0.0, 0, false; }
    if seed <= 0 || seed > 4294967295 { return 0.0, 0, false; }
    if is_nan(spot) || is_nan(strike) || is_nan(r) || is_nan(q) || is_nan(vol) || is_nan(t) { return 0.0, 0, false; }
    let dt = t / STEPS;
    let variance = vol * vol * dt;
    let sig = sqrt(variance);
    let drift = (r - q) * dt - 0.5 * variance;
    let df = exp(-r * dt);
    let scale = 1.0 / strike;
    if is_nan(sig) || is_nan(drift) || is_nan(df) || is_inf(df) { return 0.0, 0, false; }

    var spots: f64[>..] = [];
    var cg = default<mt::Twister>();
    mt::seed(cg, CALIB_SEED);
    if !fill(cg, spots, CALIB_SAMPLES * 2, spot, sig, drift) { return 0.0, 0, false; }
    var coeff: f64[>..] = [];
    if !calibrate(spots, CALIB_SAMPLES * 2, strike, scale, df, coeff) { return 0.0, 0, false; }

    var g = default<mt::Twister>();
    mt::seed(g, seed as u32);
    let sx0, sxx0, ok0 = absorb(g, FIRST, spot, strike, sig, drift, df, scale, coeff, 0.0, 0.0);
    if !ok0 { return 0.0, 0, false; }
    var n = FIRST;
    var sx = sx0;
    var sxx = sxx0;
    var err = stderr(sx, sxx, n);
    while err > tol {
        if n >= CAP { return sx / n, n, false; }
        let order = err * err / tol / tol;
        var raw = n * order * 0.8 - n;
        if raw < FIRST { raw = FIRST; }
        let room = CAP - n;
        if raw > room { raw = room; }
        let nxt = raw as i64;
        if nxt <= 0 { return sx / n, n, false; }
        let sx1, sxx1, ok1 = absorb(g, nxt, spot, strike, sig, drift, df, scale, coeff, sx, sxx);
        if !ok1 { return 0.0, n, false; }
        n += nxt;
        sx = sx1;
        sxx = sxx1;
        err = stderr(sx, sxx, n);
    }
    let mean = sx / n;
    if is_nan(mean) || is_inf(mean) { return 0.0, n, false; }
    return mean, n, true;
}
