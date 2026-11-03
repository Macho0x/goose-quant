// One-step European put from MakeMCEuropeanEngine<PseudoRandom>.
// Each path is one Mersenne Twister uniform through Acklam's inverse
// normal, then the exact Black-Scholes step. Drawing stops when the
// error estimate falls to the tolerance, and never past 200000 samples.

import math;
import normal;
import mt;

namespace mc;

const FIRST: i64 = 1023;
const CAP: i64 = 200000;

fn absorb(g: mt::Twister&, count: i64, spot: f64, strike: f64, drift: f64, sig: f64, df: f64, sx: f64, sxx: f64) -> f64, f64, bool {
    var sum = sx;
    var sumsq = sxx;
    var i: i64 = 0;
    while i < count {
        let z, ok = normal::inv_cdf(mt::next_real(g));
        if !ok { return sum, sumsq, false; }
        let terminal = spot * exp(sig * z + drift);
        var payoff = strike - terminal;
        if payoff < 0.0 { payoff = 0.0; }
        let y = payoff * df;
        sum += y;
        sumsq += y * y;
        i += 1;
    }
    return sum, sumsq, true;
}

fn stderr(sx: f64, sxx: f64, n: i64) -> f64 {
    var v = (sxx - sx * sx / n) / (n - 1.0);
    if v < 0.0 { v = 0.0; }
    return sqrt(v / n);
}

fn european_put(spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, tol: f64, seed: i64) -> f64, i64, bool {
    if spot <= 0.0 || strike < 0.0 || vol < 0.0 || t <= 0.0 || tol <= 0.0 { return 0.0, 0, false; }
    if seed <= 0 || seed > 4294967295 { return 0.0, 0, false; }
    let variance = vol * vol * t;
    let drift = (r - q) * t - 0.5 * variance;
    let sig = sqrt(variance);
    let df = exp(-r * t);
    var g = default<mt::Twister>();
    mt::seed(g, seed as u32);
    let sx0, sxx0, ok0 = absorb(g, FIRST, spot, strike, drift, sig, df, 0.0, 0.0);
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
        let sx1, sxx1, ok1 = absorb(g, nxt, spot, strike, drift, sig, df, sx, sxx);
        if !ok1 { return 0.0, n, false; }
        n += nxt;
        sx = sx1;
        sxx = sxx1;
        err = stderr(sx, sxx, n);
    }
    return sx / n, n, true;
}
