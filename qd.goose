// QD+ fixed-point American put. QuantLib's QdFpAmericanEngine:
// fast is QdFpLegendreScheme(7, 2, 7, 27),
// accurate is QdFpLegendreTanhSinhScheme(25, 5, 13, 1e-8),
// high precision is QdFpTanhSinhIterationScheme(10, 30, 1e-10).
// The exercise root is the QD+ Halley iteration in qdplusamericanengine.cpp.

import math;
import black;
import normal;
import solver;

namespace qd;

const EPS: f64 = 2.2204460492503131e-16;
const MAX: i64 = 64;

struct Coeff {
    tau: f64,
    strike: f64,
    vol: f64,
    sigma2: f64,
    v: f64,
    r: f64,
    q: f64,
    dr: f64,
    dq: f64,
    ddr: f64,
    lam: f64,
    alpha: f64,
    beta: f64,
    xmax: f64,
    xmin: f64,
}

struct State {
    s: f64,
    dp: f64,
    dm: f64,
    n_dp: f64,
    n_dm: f64,
    phi_dp: f64,
    npv: f64,
    theta: f64,
    charm: f64,
}

fn finite(x: f64) -> bool {
    if is_nan(x) || is_inf(x) { return false; }
    return true;
}

fn close_enough(x: f64, y: f64) -> bool {
    if x == y { return true; }
    let diff = abs(x - y);
    let tolerance = 42.0 * EPS;
    if x == 0.0 || y == 0.0 { return diff < tolerance * tolerance; }
    return diff <= tolerance * abs(x) || diff <= tolerance * abs(y);
}

fn close(x: f64, y: f64) -> bool {
    if x == y { return true; }
    let diff = abs(x - y);
    let tolerance = 42.0 * EPS;
    if x == 0.0 || y == 0.0 { return diff < tolerance * tolerance; }
    return diff <= tolerance * abs(x) && diff <= tolerance * abs(y);
}

fn blank() -> Coeff {
    Coeff {
        tau: 0.0,
        strike: 0.0,
        vol: 0.0,
        sigma2: 0.0,
        v: 0.0,
        r: 0.0,
        q: 0.0,
        dr: 0.0,
        dq: 0.0,
        ddr: 0.0,
        lam: 0.0,
        alpha: 0.0,
        beta: 0.0,
        xmax: 0.0,
        xmin: 0.0,
    }
}

fn xmax_of(strike: f64, r: f64, q: f64) -> f64, bool {
    if r > 0.0 && q > 0.0 {
        var ratio = r / q;
        if ratio > 1.0 { ratio = 1.0; }
        return strike * ratio, true;
    }
    if r > 0.0 && q <= 0.0 { return strike, true; }
    if r == 0.0 && q < 0.0 { return strike, true; }
    if r == 0.0 && q >= 0.0 { return 0.0, true; }
    if r < 0.0 && q >= 0.0 { return 0.0, true; }
    if r < 0.0 && q < r { return strike, true; }
    if r < 0.0 && r <= q && q < 0.0 { return 0.0, true; }
    return 0.0, false;
}

fn make_coeff(spot: f64, strike: f64, r: f64, q: f64, vol: f64, tau: f64) -> Coeff, bool {
    var c = blank();
    if !(vol > 0.0) || !(tau > 0.0) || !(strike > 0.0) { return c, false; }
    let xm, xok = xmax_of(strike, r, q);
    if !xok || !(xm > 0.0) { return c, false; }
    let sigma2 = vol * vol;
    if !(sigma2 > 0.0) { return c, false; }
    let dr = exp(-r * tau);
    let dq = exp(-q * tau);
    var ddr = 0.0;
    if abs(r * tau) > 1.0e-5 {
        ddr = r / (1.0 - dr);
    } else {
        ddr = 1.0 / (tau * (1.0 - 0.5 * r * tau * (1.0 - r * tau / 3.0)));
    }
    let omega = 2.0 * (r - q) / sigma2;
    let inside = (omega - 1.0) * (omega - 1.0) + 8.0 * ddr / sigma2;
    if !(inside > 0.0) { return c, false; }
    let disc = sqrt(inside);
    if !(disc > 0.0) { return c, false; }
    let lam = 0.5 * (-(omega - 1.0) - disc);
    let lam_p = 2.0 * ddr * ddr / (sigma2 * disc);
    let den = 2.0 * lam + omega - 1.0;
    if den == 0.0 || !finite(den) { return c, false; }
    let alpha = 2.0 * dr / (sigma2 * den);
    let beta = alpha * (ddr + lam_p / den) - lam;
    var half = 0.5 * (strike + spot);
    if half > xm { half = xm; }
    if half < 0.0 { half = 0.0; }
    c.tau = tau;
    c.strike = strike;
    c.vol = vol;
    c.sigma2 = sigma2;
    c.v = vol * sqrt(tau);
    c.r = r;
    c.q = q;
    c.dr = dr;
    c.dq = dq;
    c.ddr = ddr;
    c.lam = lam;
    c.alpha = alpha;
    c.beta = beta;
    c.xmax = xm;
    c.xmin = EPS * 1.0e4 * half;
    if !finite(c.alpha) || !finite(c.beta) || !finite(c.v) { return blank(), false; }
    return c, true;
}

fn prepare(c: Coeff, s: f64) -> State {
    var used = s;
    if used < EPS { used = EPS; }
    let dp = log(used * c.dq / (c.strike * c.dr)) / c.v + 0.5 * c.v;
    let dm = dp - c.v;
    let n_dp = normal::cdf(-dp);
    let n_dm = normal::cdf(-dm);
    let phi_dp = normal::pdf(dp);
    let npv = c.dr * c.strike * n_dm - used * c.dq * n_dp;
    let theta = c.r * c.strike * c.dr * n_dm - c.q * used * c.dq * n_dp - c.sigma2 * used / (2.0 * c.v) * c.dq * phi_dp;
    let charm = -c.dq * (phi_dp * ((c.r - c.q) / c.v - dm / (2.0 * c.tau)) + c.q * n_dp);
    State {
        s: used,
        dp: dp,
        dm: dm,
        n_dp: n_dp,
        n_dm: n_dm,
        phi_dp: phi_dp,
        npv: npv,
        theta: theta,
        charm: charm,
    }
}

fn residual(c: Coeff, s: f64) -> f64 {
    let g = prepare(c, s);
    let live = g.s;
    if close_enough(c.strike - live, g.npv) {
        return (1.0 - c.dq * g.n_dp) * live + c.alpha * g.theta / c.dr;
    }
    let gap = c.strike - live - g.npv;
    let c0 = -c.beta - c.lam + c.alpha * g.theta / (c.dr * gap);
    return (1.0 - c.dq * g.n_dp) * live + (c.lam + c0) * gap;
}

fn slope(c: Coeff, s: f64) -> f64 {
    let g = prepare(c, s);
    return 1.0 - c.dq * g.n_dp + c.dq / c.v * g.phi_dp + c.beta * (1.0 - c.dq * g.n_dp) + c.alpha / c.dr * g.charm;
}

fn curve(c: Coeff, s: f64) -> f64 {
    let g = prepare(c, s);
    let gamma = g.phi_dp * c.dq / (c.v * g.s);
    let colour = gamma * (c.q + (c.r - c.q) * g.dp / c.v + (1.0 - g.dp * g.dm) / (2.0 * c.tau));
    return c.dq * (g.phi_dp / (g.s * c.v) - g.phi_dp * g.dp / (g.s * c.v * c.v)) + c.beta * gamma + c.alpha / c.dr * colour;
}

fn halley(c: Coeff, spot: f64, eps: f64) -> f64, bool {
    var x = c.xmax;
    var evals: i32 = 0;
    var fx = 0.0;
    var settled = false;
    while true {
        let x_old = x;
        fx = residual(c, x);
        evals += 1;
        let fp = slope(c, x);
        let f2 = curve(c, x);
        if fp == 0.0 || !finite(fp) || !finite(fx) || !finite(f2) { break; }
        let lf = fx * f2 / (fp * fp);
        let step = (1.0 / (1.0 - 0.5 * lf)) * fx / fp;
        if !finite(step) { break; }
        var nxt = x - step;
        if nxt < c.xmin { nxt = c.xmin; }
        x = nxt;
        settled = abs(x - x_old) < 0.5 * eps;
        if settled || evals >= 10 { break; }
    }
    if (settled || close(abs(fx), 0.0)) && finite(x) { return x, true; }

    var hi = 0.5 * (c.xmax + spot);
    if hi < c.xmax { hi = c.xmax; }
    let f_lo = residual(c, c.xmin);
    var grows: i32 = 0;
    while residual(c, hi) * f_lo > 0.0 && grows < 30 {
        hi *= 2.0;
        grows += 1;
        if !finite(hi) { return 0.0, false; }
    }
    var guess = x;
    if !finite(guess) { guess = 0.5 * (c.xmin + hi); }
    if guess >= hi { guess = hi - (hi - c.xmin) * 1.0e-12; }
    if guess <= c.xmin { guess = c.xmin + (hi - c.xmin) * 1.0e-12; }
    let root, rok = solver::brent(guess, c.xmin, hi, eps, 100) {
        residual(c, it)
    };
    if !rok || !finite(root) { return 0.0, false; }
    return root, true;
}

fn boundary_tau(spot: f64, strike: f64, r: f64, q: f64, vol: f64, tau: f64, eps: f64) -> f64, bool {
    let xm, xok = xmax_of(strike, r, q);
    if !xok { return 0.0, false; }
    if tau < EPS { return xm, true; }
    let c, cok = make_coeff(spot, strike, r, q, vol, tau);
    if !cok { return 0.0, false; }
    return halley(c, spot, eps);
}

fn put_boundary(spot: f64, strike: f64, r: f64, q: f64, vol: f64, tau: f64) -> f64, bool {
    return boundary_tau(spot, strike, r, q, vol, tau, 1.0e-6);
}

fn vanished(k: i64, d: f64[:], e: f64[:]) -> bool {
    let left = abs(d[k - 1]) + abs(d[k]);
    return left == left + abs(e[k]);
}

fn legendre(n: i64, x: f64[:], w: f64[:]) -> bool {
    if n < 1 || n > MAX || x.len < n || w.len < n { return false; }
    var d: f64[64] = [0.0; 64];
    var e: f64[64] = [0.0; 64];
    var ev: f64[64] = [0.0; 64];
    var i: i64 = 1;
    while i < n {
        let ii = i as f64;
        e[i] = ii / sqrt(4.0 * ii * ii - 1.0);
        i += 1;
    }
    ev[0] = 1.0;

    var k: i64 = n - 1;
    while k >= 1 {
        var spins: i64 = 0;
        while !vanished(k, d, e) {
            spins += 1;
            // A zero diagonal converges slower than Laguerre. Order 27 exceeds 500 steps.
            if spins > 20000 { return false; }
            var lo = k;
            while true {
                lo -= 1;
                if lo <= 0 || vanished(lo, d, e) { break; }
            }
            var qv = d[lo];
            let t1 = sqrt(0.25 * (d[k] * d[k] + d[k - 1] * d[k - 1]) - 0.5 * d[k - 1] * d[k] + e[k] * e[k]);
            let t2 = 0.5 * (d[k] + d[k - 1]);
            var shift = t2 - t1;
            if abs(t2 + t1 - d[k]) < abs(t2 - t1 - d[k]) { shift = t2 + t1; }
            var relax = 1.0;
            if k == n - 1 { relax = 1.25; }
            qv -= relax * shift;

            var sine = 1.0;
            var cosine = 1.0;
            var u = 0.0;
            var recover = false;
            var row = lo + 1;
            while row <= k && !recover {
                let h = cosine * e[row];
                let p = sine * e[row];
                e[row - 1] = sqrt(p * p + qv * qv);
                if e[row - 1] != 0.0 {
                    sine = p / e[row - 1];
                    cosine = qv / e[row - 1];
                    let g = d[row - 1] - u;
                    let rot = (d[row] - g) * sine + 2.0 * cosine * h;
                    u = sine * rot;
                    d[row - 1] = g + u;
                    qv = cosine * rot - h;
                    let tmp = ev[row - 1];
                    ev[row - 1] = sine * ev[row] + cosine * tmp;
                    ev[row] = cosine * ev[row] - sine * tmp;
                } else {
                    d[row - 1] -= u;
                    e[lo] = 0.0;
                    recover = true;
                }
                row += 1;
            }
            if !recover {
                d[k] -= u;
                e[k] = qv;
                e[lo] = 0.0;
            }
        }
        k -= 1;
    }

    i = 0;
    while i < n - 1 {
        var m = i;
        var j = i + 1;
        while j < n {
            if d[j] < d[m] { m = j; }
            j += 1;
        }
        if m != i {
            let td = d[i];
            d[i] = d[m];
            d[m] = td;
            let tv = ev[i];
            ev[i] = ev[m];
            ev[m] = tv;
        }
        i += 1;
    }

    var sum_w = 0.0;
    var moment = 0.0;
    var odd = 0.0;
    i = 0;
    while i < n {
        x[i] = d[i];
        let wi = 2.0 * ev[i] * ev[i];
        if !finite(wi) || !finite(d[i]) { return false; }
        w[i] = wi;
        sum_w += wi;
        moment += wi * d[i] * d[i];
        odd += wi * d[i];
        i += 1;
    }
    if abs(sum_w - 2.0) > 1.0e-8 { return false; }
    if n >= 2 && abs(moment - 2.0 / 3.0) > 1.0e-8 { return false; }
    if n >= 2 && abs(odd) > 1.0e-8 { return false; }
    return true;
}

fn chebyshev(z: f64[:], n: i64) {
    let denom = (n - 1) as f64;
    var i: i64 = 0;
    while i < n {
        z[i] = -cos(i * PI / denom);
        i += 1;
    }
}

fn barycentric(z: f64[:], lam: f64[:], n: i64) -> bool {
    let scale = 4.0 / (z[n - 1] - z[0]);
    var i: i64 = 0;
    while i < n {
        var w = 1.0;
        let x_i = z[i];
        var j: i64 = 0;
        while j < n {
            if i != j { w *= scale * (x_i - z[j]); }
            j += 1;
        }
        if w == 0.0 || !finite(w) { return false; }
        lam[i] = 1.0 / w;
        if !finite(lam[i]) { return false; }
        i += 1;
    }
    return true;
}

fn lagrange(z: f64[:], y: f64[:], lam: f64[:], n: i64, x: f64) -> f64 {
    let band = 10.0 * EPS * abs(x);
    var i: i64 = 0;
    while i < n {
        if z[i] >= x - band { break; }
        i += 1;
    }
    if i < n && z[i] - x < band { return y[i]; }
    var num = 0.0;
    var den = 0.0;
    i = 0;
    while i < n {
        let alpha = lam[i] / (x - z[i]);
        num += alpha * y[i];
        den += alpha;
        i += 1;
    }
    return num / den;
}

fn exercise_at(tau: f64, t_mat: f64, xm: f64, z: f64[:], y: f64[:], lam: f64[:], n: i64) -> f64 {
    let arg = 2.0 * sqrt(abs(tau) / t_mat) - 1.0;
    var qv = lagrange(z, y, lam, n, arg);
    if qv < 0.0 { qv = 0.0; }
    return xm * exp(-sqrt(qv));
}

fn sqlog(b: f64, xm: f64) -> f64, bool {
    if !(b > 0.0) || !(xm > 0.0) { return 0.0, false; }
    let lg = log(b / xm);
    if !finite(lg) { return 0.0, false; }
    return lg * lg, true;
}

fn d_pm(vol: f64, r: f64, q: f64, t: f64, z: f64) -> f64, f64, bool {
    if !(t > 0.0) || !(z > 0.0) || !(vol > 0.0) { return 0.0, 0.0, false; }
    let vv = vol * sqrt(t);
    if !(vv > 0.0) { return 0.0, 0.0, false; }
    let m = (log(z) + (r - q) * t) / vv + 0.5 * vv;
    if !finite(m) { return 0.0, 0.0, false; }
    return m, m - vv, true;
}

fn tiny_fv(tau: f64, b: f64, strike: f64, r: f64, q: f64, above_is_alpha: bool) -> f64, bool {
    let alpha = strike * exp(-(r - q) * tau);
    if close_enough(b, strike) { return alpha, true; }
    if b > strike {
        if above_is_alpha { return alpha, true; }
        return 0.0, true;
    }
    if close_enough(q, 0.0) {
        var sign = 1.0;
        if q < 0.0 { sign = -1.0; }
        return alpha * r * sign / EPS, true;
    }
    if q == 0.0 { return 0.0, false; }
    return alpha * r / q, true;
}

fn ts_sinh(t: f64) -> f64 {
    let e = exp(t);
    return 0.5 * (e - 1.0 / e);
}

fn ts_cosh(t: f64) -> f64 {
    let e = exp(t);
    return 0.5 * (e + 1.0 / e);
}

fn ts_pair(t: f64) -> f64, f64 {
    if t == 0.0 { return 0.0, 0.5 * PI; }
    let u = 0.5 * PI * ts_sinh(t);
    var w = 0.0;
    var x = 0.0;
    if u < 1.0 {
        let cs = ts_cosh(u);
        w = 0.5 * PI * ts_cosh(t) / (cs * cs);
        let e = exp(2.0 * u);
        x = (e - 1.0) / (e + 1.0);
    } else {
        let e2 = exp(-2.0 * u);
        let den = (1.0 + e2) * (1.0 + e2);
        w = 0.5 * PI * ts_cosh(t) * 4.0 * e2 / den;
        x = 1.0 - 2.0 * e2 / (1.0 + e2);
    }
    if x > 1.0 - 4.0 * EPS { x = 1.0 - 4.0 * EPS; }
    if x < 0.0 { x = 0.0; }
    return x, w;
}

// ponytail: abscissae stop at t=3.6 and 8 halvings, so a 1/sqrt endpoint stalls near 1e-8. Complement nodes out to t=6 and 15 refinements if that tail is the error.
fn tanh_sinh<F>(a: f64, b: f64, tol: f64) -> f64, bool {
    if !(b > a) || !finite(a) || !finite(b) || !(tol > 0.0) { return 0.0, false; }
    let half = 0.5 * (b - a);
    let mid = 0.5 * (a + b);
    var h = 1.0;
    var estimate = 0.0;
    var l1 = 0.0;
    var level: i64 = 0;
    var prev = 0.0;
    while level < 8 {
        var acc = 0.0;
        var ab = 0.0;
        var k: i64 = 0;
        var step: i64 = 1;
        if level > 0 {
            k = 1;
            step = 2;
        }
        while true {
            let t = (k as f64) * h;
            if t > 3.6 { break; }
            let x, w = ts_pair(t);
            if !finite(x) || !finite(w) { return 0.0, false; }
            let right = F(mid + half * x);
            if !finite(right) { return 0.0, false; }
            if k == 0 {
                acc += right * w;
                ab += abs(right * w);
            } else {
                let left = F(mid - half * x);
                if !finite(left) { return 0.0, false; }
                acc += (right + left) * w;
                ab += (abs(right) + abs(left)) * w;
            }
            if w < 1.0e-18 && t > 0.0 { break; }
            k += step;
        }
        if level == 0 {
            estimate = acc * h;
            l1 = ab * h;
        } else {
            estimate = 0.5 * estimate + acc * h;
            l1 = 0.5 * l1 + ab * h;
        }
        if level >= 4 {
            let err = abs(estimate - prev);
            if err <= tol * l1 {
                let value = estimate * half;
                if !finite(value) { return 0.0, false; }
                return value, true;
            }
        }
        prev = estimate;
        h *= 0.5;
        level += 1;
    }
    let value = estimate * half;
    if !finite(value) { return 0.0, false; }
    return value, true;
}

fn b_node(u: f64, tau: f64, b: f64, r: f64, q: f64, vol: f64, t_mat: f64, xm: f64, z: f64[:], y: f64[:], lam: f64[:], points: i64, want_dm: bool) -> f64, bool {
    var rate = q;
    if want_dm { rate = r; }
    let df = exp(rate * u);
    let b_u = exercise_at(u, t_mat, xm, z, y, lam, points);
    if u >= tau * (1.0 - 5.0 * EPS) {
        if close_enough(b, b_u) { return 0.5 * df, true; }
        if b < b_u { return 0.0, true; }
        return df, true;
    }
    if !(b_u > 0.0) { return 0.0, false; }
    let dp, dm, ok = d_pm(vol, r, q, tau - u, b / b_u);
    if !ok { return 0.0, false; }
    if want_dm { return df * normal::cdf(dm), true; }
    return df * normal::cdf(dp), true;
}

fn a_node(y: f64, tau: f64, b: f64, r: f64, q: f64, vol: f64, t_mat: f64, xm: f64, z: f64[:], nodes: f64[:], lam: f64[:], points: i64, want_k3: bool) -> f64, bool {
    let m = 0.25 * tau * (1.0 + y) * (1.0 + y);
    var rate = q;
    if want_k3 { rate = r; }
    let df = exp(rate * tau - rate * m);
    let stv = sqrt(tau) / vol;
    let b_m = exercise_at(tau - m, t_mat, xm, z, nodes, lam, points);
    if y <= 5.0 * EPS - 1.0 {
        if close_enough(b, b_m) { return df * stv * normal::pdf(0.0), true; }
        return 0.0, true;
    }
    if !(b_m > 0.0) { return 0.0, false; }
    let dp, dm, ok = d_pm(vol, r, q, m, b / b_m);
    if !ok { return 0.0, false; }
    if want_k3 { return df * stv * normal::pdf(dm), true; }
    return df * (0.5 * tau * (y + 1.0) * normal::cdf(dp) + stv * normal::pdf(dp)), true;
}

fn eq_b(tau: f64, b: f64, strike: f64, r: f64, q: f64, vol: f64, t_mat: f64, xm: f64, z: f64[:], y: f64[:], lam: f64[:], points: i64, qx: f64[:], qw: f64[:], order: i64, tol: f64) -> f64, f64, f64, bool {
    let tiny = tau < EPS * EPS;
    var n_val = 0.0;
    var d_val = 0.0;
    if tiny {
        if close_enough(b, strike) {
            n_val = 0.5;
            d_val = 0.5;
        } else if b < strike {
            n_val = 0.0;
            d_val = 0.0;
        } else {
            n_val = 1.0;
            d_val = 1.0;
        }
        let fv, fok = tiny_fv(tau, b, strike, r, q, true);
        return n_val, d_val, fv, fok && finite(fv);
    }
    let c = 0.5 * tau;
    var ni = 0.0;
    var di = 0.0;
    if tol > 0.0 {
        var bad = false;
        let raw_n, nok = tanh_sinh(0.0, tau, tol) {
            let v, vok = b_node(it, tau, b, r, q, vol, t_mat, xm, z, y, lam, points, true);
            if !vok { bad = true; }
            if vok { v } else { 0.0 }
        };
        let raw_d, dok = tanh_sinh(0.0, tau, tol) {
            let v, vok = b_node(it, tau, b, r, q, vol, t_mat, xm, z, y, lam, points, false);
            if !vok { bad = true; }
            if vok { v } else { 0.0 }
        };
        if !nok || !dok || bad { return 0.0, 0.0, 0.0, false; }
        ni = raw_n;
        di = raw_d;
    } else {
        var i: i64 = 0;
        while i < order {
            let u = c * qx[i] + c;
            let left = tau - u;
            let b_u = exercise_at(u, t_mat, xm, z, y, lam, points);
            if !(b_u > 0.0) { return 0.0, 0.0, 0.0, false; }
            let dp, dm, ok = d_pm(vol, r, q, left, b / b_u);
            if !ok { return 0.0, 0.0, 0.0, false; }
            ni += qw[i] * exp(r * u) * normal::cdf(dm);
            di += qw[i] * exp(q * u) * normal::cdf(dp);
            i += 1;
        }
        ni *= c;
        di *= c;
    }
    let dp, dm, ok = d_pm(vol, r, q, tau, b / strike);
    if !ok { return 0.0, 0.0, 0.0, false; }
    n_val = normal::cdf(dm) + r * ni;
    d_val = normal::cdf(dp) + q * di;
    if d_val == 0.0 || !finite(n_val) || !finite(d_val) { return 0.0, 0.0, 0.0, false; }
    let fv = strike * exp(-(r - q) * tau) * n_val / d_val;
    return n_val, d_val, fv, finite(fv);
}

fn ndd_b(tau: f64, b: f64, strike: f64, r: f64, q: f64, vol: f64) -> f64, f64, bool {
    if !(tau > 0.0) || !(b > 0.0) { return 0.0, 0.0, false; }
    let dp, dm, ok = d_pm(vol, r, q, tau, b / strike);
    if !ok { return 0.0, 0.0, false; }
    let scale = b * vol * sqrt(tau);
    if scale == 0.0 { return 0.0, 0.0, false; }
    let nd = normal::pdf(dm) / scale;
    let dd = normal::pdf(dp) / scale;
    return nd, dd, finite(nd) && finite(dd);
}

fn eq_a(tau: f64, b: f64, strike: f64, r: f64, q: f64, vol: f64, t_mat: f64, xm: f64, z: f64[:], y: f64[:], lam: f64[:], points: i64, qx: f64[:], qw: f64[:], order: i64, tol: f64) -> f64, f64, f64, bool {
    let tiny = tau < EPS * EPS;
    if tiny {
        var n_val = 0.0;
        var d_val = 0.0;
        let vv = vol * sqrt(tau);
        if close_enough(b, strike) {
            if !(vv > 0.0) { return 0.0, 0.0, 0.0, false; }
            n_val = normal::pdf(0.0) / vv;
            d_val = n_val + 0.5;
        } else if b > strike {
            d_val = 1.0;
        }
        let fv, fok = tiny_fv(tau, b, strike, r, q, false);
        return n_val, d_val, fv, fok && finite(fv);
    }
    let vv = vol * sqrt(tau);
    let stv = sqrt(tau) / vol;
    var k12 = 0.0;
    var k3 = 0.0;
    if tol > 0.0 {
        var bad = false;
        let i12, ok12 = tanh_sinh(-1.0, 1.0, tol) {
            let v, vok = a_node(it, tau, b, r, q, vol, t_mat, xm, z, y, lam, points, false);
            if !vok { bad = true; }
            if vok { v } else { 0.0 }
        };
        let i3, ok3 = tanh_sinh(-1.0, 1.0, tol) {
            let v, vok = a_node(it, tau, b, r, q, vol, t_mat, xm, z, y, lam, points, true);
            if !vok { bad = true; }
            if vok { v } else { 0.0 }
        };
        if !ok12 || !ok3 || bad { return 0.0, 0.0, 0.0, false; }
        k12 = i12;
        k3 = i3;
    } else {
        var i: i64 = 0;
        while i < order {
            let node = qx[i];
            let m = 0.25 * tau * (1.0 + node) * (1.0 + node);
            let b_m = exercise_at(tau - m, t_mat, xm, z, y, lam, points);
            if !(b_m > 0.0) { return 0.0, 0.0, 0.0, false; }
            let dp, dm, ok = d_pm(vol, r, q, m, b / b_m);
            if !ok { return 0.0, 0.0, 0.0, false; }
            let df_q = exp(q * tau - q * m);
            let df_r = exp(r * tau - r * m);
            k12 += qw[i] * df_q * (0.5 * tau * (node + 1.0) * normal::cdf(dp) + stv * normal::pdf(dp));
            k3 += qw[i] * stv * df_r * normal::pdf(dm);
            i += 1;
        }
    }
    let dp, dm, ok = d_pm(vol, r, q, tau, b / strike);
    if !ok || !(vv > 0.0) { return 0.0, 0.0, 0.0, false; }
    let n_val = normal::pdf(dm) / vv + r * k3;
    let d_val = normal::pdf(dp) / vv + normal::cdf(dp) + q * k12;
    if d_val == 0.0 || !finite(n_val) || !finite(d_val) { return 0.0, 0.0, 0.0, false; }
    let fv = strike * exp(-(r - q) * tau) * n_val / d_val;
    return n_val, d_val, fv, finite(fv);
}

fn ndd_a(tau: f64, b: f64, strike: f64, r: f64, q: f64, vol: f64) -> f64, f64, bool {
    if !(b > 0.0) { return 0.0, 0.0, false; }
    if tau < EPS * EPS {
        if !close_enough(b, strike) { return 0.0, 0.0, true; }
        let sq = sqrt(tau);
        let vol2 = vol * vol;
        if !(sq > 0.0) || vol2 == 0.0 { return 0.0, 0.0, false; }
        let phi0 = normal::pdf(0.0);
        let dd = phi0 * (-(0.5 * vol2 + r - q) / (b * vol * vol2 * sq) + 1.0 / (b * vol * sq));
        let nd = phi0 * (-0.5 * vol2 + r - q) / (b * vol * vol2 * sq);
        return nd, dd, finite(nd) && finite(dd);
    }
    let dp, dm, ok = d_pm(vol, r, q, tau, b / strike);
    if !ok { return 0.0, 0.0, false; }
    let vol2 = vol * vol;
    let phi_p = normal::pdf(dp);
    let phi_m = normal::pdf(dm);
    let dd = -phi_p * dp / (b * vol2 * tau) + phi_p / (b * vol * sqrt(tau));
    let nd = -phi_m * dm / (b * vol2 * tau);
    return nd, dd, finite(nd) && finite(dd);
}

fn eq_at(use_a: bool, tau: f64, b: f64, strike: f64, r: f64, q: f64, vol: f64, t_mat: f64, xm: f64, z: f64[:], y: f64[:], lam: f64[:], points: i64, qx: f64[:], qw: f64[:], order: i64, tol: f64) -> f64, f64, f64, bool {
    if use_a {
        return eq_a(tau, b, strike, r, q, vol, t_mat, xm, z, y, lam, points, qx, qw, order, tol);
    }
    return eq_b(tau, b, strike, r, q, vol, t_mat, xm, z, y, lam, points, qx, qw, order, tol);
}

fn ndd_at(use_a: bool, tau: f64, b: f64, strike: f64, r: f64, q: f64, vol: f64) -> f64, f64, bool {
    if use_a { return ndd_a(tau, b, strike, r, q, vol); }
    return ndd_b(tau, b, strike, r, q, vol);
}

fn forward_intrinsic(strike: f64, spot: f64, r: f64, q: f64, t: f64) -> f64 {
    var v = strike * exp(-r * t) - spot * exp(-q * t);
    if v < 0.0 { v = 0.0; }
    return v;
}

fn put_floor(price: f64, spot: f64, strike: f64) -> f64 {
    var out = price;
    if out < 0.0 { out = 0.0; }
    var intrinsic = strike - spot;
    if intrinsic < 0.0 { intrinsic = 0.0; }
    if out < intrinsic { out = intrinsic; }
    return out;
}

fn european_put(spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64) -> f64, bool {
    let forward = spot * exp((r - q) * t);
    let df = exp(-r * t);
    let std = vol * sqrt(t);
    return black::black(black::PUT, strike, forward, std, df, 0.0);
}

fn zero_vol(spot: f64, strike: f64, r: f64, q: f64, t: f64) -> f64, bool {
    var best = forward_intrinsic(strike, spot, r, q, 0.0);
    let at_t = forward_intrinsic(strike, spot, r, q, t);
    if at_t > best { best = at_t; }
    if !close_enough(r, q) && q != 0.0 && spot > 0.0 {
        let ratio = r * strike / (q * spot);
        if ratio > 0.0 {
            let extrem = log(ratio) / (r - q);
            if extrem > 0.0 && extrem < t {
                let at_e = forward_intrinsic(strike, spot, r, q, extrem);
                if at_e > best { best = at_e; }
            }
        }
    }
    return put_floor(best, spot, strike), true;
}

fn addon_at(zz: f64, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, xm: f64, z: f64[:], y: f64[:], lam: f64[:], points: i64) -> f64, bool {
    let t_i = zz * zz;
    var remain = t - t_i;
    if remain < 0.0 { remain = 0.0; }
    let arg = 2.0 * sqrt(remain / t) - 1.0;
    var qv = lagrange(z, y, lam, points, arg);
    if qv < 0.0 { qv = 0.0; }
    let b_t = xm * exp(-sqrt(qv));
    let dr = exp(-r * t_i);
    let dq = exp(-q * t_i);
    let vv = vol * sqrt(t_i);
    var piece = 0.0;
    if vv >= EPS {
        if b_t > EPS {
            let dp = log(spot * dq / (b_t * dr)) / vv + 0.5 * vv;
            piece = 2.0 * zz * (r * strike * dr * normal::cdf(-dp + vv) - q * spot * dq * normal::cdf(-dp));
        }
    } else if close_enough(spot * dq, b_t * dr) {
        piece = zz * (r * strike * dr - q * spot * dq);
    } else if b_t * dr > spot * dq {
        piece = 2.0 * zz * (r * strike * dr - q * spot * dq);
    }
    if !finite(piece) { return 0.0, false; }
    return piece, true;
}

fn npv_legendre(spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, l: i64, m: i64, n: i64, p: i64, fp_tol: f64, price_tol: f64) -> f64, bool {
    if strike < 0.0 || spot < 0.0 || vol < 0.0 || t < 0.0 { return 0.0, false; }
    if t == 0.0 { return put_floor(0.0, spot, strike), true; }
    if close(strike, 0.0) { return put_floor(0.0, spot, strike), true; }
    if close(spot, 0.0) {
        var held = strike * exp(-r * t);
        if held < strike { held = strike; }
        return put_floor(held, spot, strike), true;
    }
    if r <= 0.0 && r <= q {
        let euro, eok = european_put(spot, strike, r, q, vol, t);
        if !eok { return 0.0, false; }
        var px = euro;
        if px < 0.0 { px = 0.0; }
        return put_floor(px, spot, strike), true;
    }
    if close(vol, 0.0) { return zero_vol(spot, strike, r, q, t); }
    if r < 0.0 && q < r { return 0.0, false; }
    if m < 1 || n < 1 || fp_tol < 0.0 || price_tol < 0.0 { return 0.0, false; }
    if fp_tol == 0.0 && (l < 1 || l > MAX) { return 0.0, false; }
    if price_tol == 0.0 && (p < 1 || p > MAX) { return 0.0, false; }
    let points = n + 1;
    if points > MAX { return 0.0, false; }

    let xm, xok = xmax_of(strike, r, q);
    if !xok || !(xm > 0.0) { return 0.0, false; }
    let use_a = abs(r - q) < 0.001;

    var z: f64[64] = [0.0; 64];
    var y: f64[64] = [0.0; 64];
    var lam: f64[64] = [0.0; 64];
    var qx: f64[64] = [0.0; 64];
    var qw: f64[64] = [0.0; 64];
    var px: f64[64] = [0.0; 64];
    var pw: f64[64] = [0.0; 64];
    if fp_tol == 0.0 && !legendre(l, qx, qw) { return 0.0, false; }
    if price_tol == 0.0 && !legendre(p, px, pw) { return 0.0, false; }
    chebyshev(z, points);
    if !barycentric(z, lam, points) { return 0.0, false; }

    var i: i64 = 0;
    while i < points {
        let tau = 0.25 * t * (1.0 + z[i]) * (1.0 + z[i]);
        let b, bok = boundary_tau(spot, strike, r, q, vol, tau, 1.0e-8);
        if !bok { return 0.0, false; }
        let yy, yok = sqlog(b, xm);
        if !yok { return 0.0, false; }
        y[i] = yy;
        i += 1;
    }

    var pass: i64 = 0;
    while pass < m {
        let newton = pass == 0;
        var yn: f64[64] = [0.0; 64];
        i = 1;
        while i < points {
            let xt = 0.5 * sqrt(t) * (1.0 + z[i]);
            let tau = xt * xt;
            let b = exercise_at(tau, t, xm, z, y, lam, points);
            let n_val, d_val, fv, fok = eq_at(use_a, tau, b, strike, r, q, vol, t, xm, z, y, lam, points, qx, qw, l, fp_tol);
            if !fok { return 0.0, false; }
            var nxt = fv;
            if newton && !(tau < EPS) {
                let nd, dd, dok = ndd_at(use_a, tau, b, strike, r, q, vol);
                if !dok || d_val == 0.0 { return 0.0, false; }
                let fd = strike * exp(-(r - q) * tau) * (nd / d_val - dd * n_val / (d_val * d_val));
                if fd == 1.0 || !finite(fd) { return 0.0, false; }
                nxt = b - (fv - b) / (fd - 1.0);
            }
            let yy, yok = sqlog(nxt, xm);
            if !yok { return 0.0, false; }
            yn[i] = yy;
            i += 1;
        }
        i = 1;
        while i < points {
            y[i] = yn[i];
            i += 1;
        }
        pass += 1;
    }

    let upper = sqrt(t);
    var addon = 0.0;
    if price_tol > 0.0 {
        var bad = false;
        let raw, rok = tanh_sinh(0.0, upper, price_tol) {
            let piece, pok = addon_at(it, spot, strike, r, q, vol, t, xm, z, y, lam, points);
            if !pok { bad = true; }
            if pok { piece } else { 0.0 }
        };
        if !rok || bad { return 0.0, false; }
        addon = raw;
    } else {
        let c1 = 0.5 * upper;
        i = 0;
        while i < p {
            let zz = c1 * px[i] + c1;
            let piece, pok = addon_at(zz, spot, strike, r, q, vol, t, xm, z, y, lam, points);
            if !pok { return 0.0, false; }
            addon += pw[i] * piece;
            i += 1;
        }
        addon *= c1;
    }
    if !finite(addon) || addon < -1.0e-8 { return 0.0, false; }
    if addon < 0.0 { addon = 0.0; }

    let euro, eok = european_put(spot, strike, r, q, vol, t);
    if !eok { return 0.0, false; }
    var price = euro;
    if price < 0.0 { price = 0.0; }
    price += addon;
    price = put_floor(price, spot, strike);
    if !finite(price) { return 0.0, false; }
    return price, true;
}

fn npv_fast(spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64) -> f64, bool {
    return npv_legendre(spot, strike, r, q, vol, t, 7, 2, 7, 27, 0.0, 0.0);
}

fn npv_accurate(spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64) -> f64, bool {
    return npv_legendre(spot, strike, r, q, vol, t, 25, 5, 13, 0, 0.0, 1.0e-8);
}

fn npv_high(spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64) -> f64, bool {
    return npv_legendre(spot, strike, r, q, vol, t, 0, 10, 30, 0, 1.0e-10, 1.0e-10);
}
