// European Heston and the Gatheral integral Bates builds on.
// AnalyticHestonEngine's EquityOption constructor: Gauss-Laguerre
// of order 144 and OptimalCV. Those inputs take the angled contour.
// ponytail: AsymptoticChF, the other OptimalCV branch, is not priced.

import math;
import black;

namespace heston;

struct Cx { re: f64, im: f64 }

fn re(x: f64) -> Cx { Cx { re: x, im: 0.0 } }

fn add(a: Cx, b: Cx) -> Cx { Cx { re: a.re + b.re, im: a.im + b.im } }

fn sub(a: Cx, b: Cx) -> Cx { Cx { re: a.re - b.re, im: a.im - b.im } }

fn scale(a: Cx, s: f64) -> Cx { Cx { re: a.re * s, im: a.im * s } }

fn mul(a: Cx, b: Cx) -> Cx {
    Cx { re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re }
}

fn div(a: Cx, b: Cx) -> Cx {
    let den = b.re * b.re + b.im * b.im;
    Cx { re: (a.re * b.re + a.im * b.im) / den, im: (a.im * b.re - a.re * b.im) / den }
}

fn modulus(a: Cx) -> f64 {
    let x = abs(a.re);
    let y = abs(a.im);
    if x == 0.0 { return y; }
    if y == 0.0 { return x; }
    if x > y {
        let q = y / x;
        return x * sqrt(1.0 + q * q);
    }
    let q = x / y;
    return y * sqrt(1.0 + q * q);
}

fn sqrt_cx(a: Cx) -> Cx {
    if a.re == 0.0 {
        let t = sqrt(abs(a.im) / 2.0);
        if a.im < 0.0 { return Cx { re: t, im: -t }; }
        return Cx { re: t, im: t };
    }
    let t = sqrt(2.0 * (modulus(a) + abs(a.re)));
    let u = t / 2.0;
    if a.re > 0.0 { return Cx { re: u, im: a.im / t }; }
    if a.im < 0.0 { return Cx { re: abs(a.im) / t, im: -u }; }
    Cx { re: abs(a.im) / t, im: u }
}

fn exp_cx(a: Cx) -> Cx {
    let e = exp(a.re);
    Cx { re: e * cos(a.im), im: e * sin(a.im) }
}

fn log_cx(a: Cx) -> Cx {
    Cx { re: log(modulus(a)), im: atan2(a.im, a.re) }
}

fn expm1_real(x: f64) -> f64 {
    if x == 0.0 { return 0.0; }
    let u = exp(x);
    if u == 1.0 { return x; }
    return (u - 1.0) * x / log(u);
}

fn log1p_real(x: f64) -> f64 {
    if x == 0.0 { return 0.0; }
    let u = 1.0 + x;
    if u == 1.0 { return x; }
    return log(u) * x / (u - 1.0);
}

fn expm1_cx(z: Cx) -> Cx {
    if modulus(z) < 1.0 {
        let exp_1 = expm1_real(z.re);
        let cos_1 = -2.0 * sin(0.5 * z.im) * sin(0.5 * z.im);
        return Cx { re: exp_1 * cos_1 + exp_1 + cos_1, im: sin(z.im) * exp(z.re) };
    }
    sub(exp_cx(z), re(1.0))
}

fn log1p_cx(z: Cx) -> Cx {
    if abs(z.re) < 0.5 && abs(z.im) < 0.5 {
        let arg = z.re * z.re + 2.0 * z.re + z.im * z.im;
        return Cx { re: 0.5 * log1p_real(arg), im: atan2(z.im, 1.0 + z.re) };
    }
    log_cx(add(re(1.0), z))
}

fn bad(x: f64) -> bool { is_nan(x) || is_inf(x) }

fn ln_chf(z: Cx, t: f64, kappa: f64, sigma: f64, theta: f64, rho: f64, v0: f64) -> Cx {
    let sigma2 = sigma * sigma;
    let g = add(re(kappa), scale(Cx { re: z.im, im: -z.re }, rho * sigma));
    let extra = add(mul(z, z), Cx { re: -z.im, im: z.re });
    let d = sqrt_cx(add(mul(g, g), scale(extra, sigma2)));
    var r = sub(g, d);
    if g.re * d.re + g.im * d.im > 0.0 {
        r = div(scale(mul(z, Cx { re: z.re, im: z.im + 1.0 }), -sigma2), add(g, d));
    }
    var y = re(-0.5 * t);
    if d.re != 0.0 || d.im != 0.0 {
        y = div(expm1_cx(scale(d, -t)), scale(d, 2.0));
    }
    let ry = mul(r, y);
    let a = scale(sub(scale(r, t), scale(log1p_cx(scale(ry, -1.0)), 2.0)), kappa * theta / sigma2);
    let b = div(mul(mul(z, Cx { re: z.re, im: z.im + 1.0 }), y), sub(re(1.0), ry));
    add(a, scale(b, v0))
}

fn vanished(k: i64, d: f64[:], e: f64[:]) -> bool {
    let left = abs(d[k - 1]) + abs(d[k]);
    return left == left + abs(e[k]);
}

// Roots of the Laguerre polynomial, QuantLib's tridiagonal QR with the
// over-relaxed shift GaussianQuadrature asks for. Weights already include
// exp(x), so the sum is the integral of the integrand from 0 to infinity.
fn nodes(x: f64[:], w: f64[:]) -> bool {
    if x.len != 144 || w.len != 144 { return false; }
    var d: f64[144] = [0.0; 144];
    var e: f64[144] = [0.0; 144];
    var ev: f64[144] = [0.0; 144];
    var i: i64 = 0;
    while i < 144 {
        d[i] = 2.0 * i + 1.0;
        i += 1;
    }
    i = 1;
    while i < 144 {
        e[i] = i;
        i += 1;
    }
    ev[0] = 1.0;

    var k: i64 = 143;
    while k >= 1 {
        var spins: i64 = 0;
        while !vanished(k, d, e) {
            spins += 1;
            if spins > 500 { return false; }
            var lo = k;
            while true {
                lo -= 1;
                if lo <= 0 || vanished(lo, d, e) { break; }
            }
            var q = d[lo];
            let t1 = sqrt(0.25 * (d[k] * d[k] + d[k - 1] * d[k - 1]) - 0.5 * d[k - 1] * d[k] + e[k] * e[k]);
            let t2 = 0.5 * (d[k] + d[k - 1]);
            var shift = t2 - t1;
            if abs(t2 + t1 - d[k]) < abs(t2 - t1 - d[k]) { shift = t2 + t1; }
            var relax = 1.0;
            if k == 143 { relax = 1.25; }
            q -= relax * shift;

            var sine = 1.0;
            var cosine = 1.0;
            var u = 0.0;
            var recover = false;
            var row = lo + 1;
            while row <= k && !recover {
                let h = cosine * e[row];
                let p = sine * e[row];
                e[row - 1] = sqrt(p * p + q * q);
                if e[row - 1] != 0.0 {
                    sine = p / e[row - 1];
                    cosine = q / e[row - 1];
                    let g = d[row - 1] - u;
                    let rot = (d[row] - g) * sine + 2.0 * cosine * h;
                    u = sine * rot;
                    d[row - 1] = g + u;
                    q = cosine * rot - h;
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
                e[k] = q;
                e[lo] = 0.0;
            }
        }
        k -= 1;
    }

    i = 0;
    while i < 143 {
        var m = i;
        var j = i + 1;
        while j < 144 {
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

    i = 0;
    while i < 144 {
        x[i] = d[i];
        let wx = exp(-d[i]);
        var wi = 0.0;
        if ev[i] != 0.0 {
            if wx > 0.0 {
                wi = ev[i] * ev[i] / wx;
            } else {
                wi = exp(2.0 * log(abs(ev[i])) + d[i]);
            }
        }
        if bad(wi) { wi = 0.0; }
        w[i] = wi;
        i += 1;
    }
    return true;
}

fn average_var(v0: f64, kappa: f64, theta: f64, t: f64) -> f64 {
    (1.0 - exp(-kappa * t)) * (v0 - theta) / (kappa * t) + theta
}

fn contour(u: f64, t: f64, fwd: f64, strike: f64, v0: f64, kappa: f64, theta: f64, sigma: f64, rho: f64) -> f64 {
    let alpha = -0.5;
    let freq = log(fwd / strike);
    let s_alpha = exp(alpha * freq);
    let v_avg = average_var(v0, kappa, theta, t);
    let rr = rho - sigma * freq / (v0 + kappa * theta * t);
    var tp = 0.0;
    if rr * freq < 0.0 {
        var sgn = 0.0;
        if freq > 0.0 { sgn = 1.0; }
        if freq < 0.0 { sgn = -1.0; }
        tp = tan(PI / 12.0 * sgn);
    }
    let h = Cx { re: u, im: u * tp - alpha };
    let hp = Cx { re: u, im: h.im - 1.0 };
    let inner = add(mul(hp, hp), Cx { re: -hp.im, im: hp.re });
    let phi_bs = exp_cx(add(re(-u * tp * freq), scale(inner, -0.5 * v_avg * t)));
    let v = ln_chf(hp, t, kappa, sigma, theta, rho, v0);
    var chf = re(0.0);
    if !(is_inf(v.re) && v.re < 0.0) {
        chf = exp_cx(add(re(-u * tp * freq), v));
    }
    let quot = div(sub(phi_bs, chf), mul(h, hp));
    let num = mul(mul(exp_cx(Cx { re: 0.0, im: u * freq }), Cx { re: 1.0, im: tp }), quot);
    num.re * s_alpha
}

fn market(option: i32, spot: f64, strike: f64, r: f64, q: f64, v0: f64, kappa: f64, theta: f64, sigma: f64, rho: f64, t: f64) -> bool {
    if option != black::CALL && option != black::PUT { return false; }
    if spot <= 0.0 || strike <= 0.0 || t <= 0.0 { return false; }
    if v0 < 0.0 || theta < 0.0 || sigma <= 0.0 || kappa == 0.0 { return false; }
    if rho < -1.0 || rho > 1.0 { return false; }
    if v0 + kappa * theta * t == 0.0 { return false; }
    return true;
}

fn npv(option: i32, spot: f64, strike: f64, r: f64, q: f64, v0: f64, kappa: f64, theta: f64, sigma: f64, rho: f64, t: f64) -> f64, bool {
    if !market(option, spot, strike, r, q, v0, kappa, theta, sigma, rho, t) { return 0.0, false; }
    let dr = exp(-r * t);
    let dq = exp(-q * t);
    if !(dr > 0.0) || !(dq > 0.0) { return 0.0, false; }
    let fwd = spot * dq / dr;
    if bad(fwd) || fwd <= 0.0 { return 0.0, false; }
    var xs: f64[144] = [0.0; 144];
    var ws: f64[144] = [0.0; 144];
    if !nodes(xs, ws) { return 0.0, false; }
    let cv, cok = black::black(black::CALL, strike, fwd, sqrt(average_var(v0, kappa, theta, t) * t), 1.0, 0.0);
    if !cok { return 0.0, false; }
    var acc = 0.0;
    var i: i64 = 0;
    while i < 144 {
        let f = contour(xs[i], t, fwd, strike, v0, kappa, theta, sigma, rho);
        if bad(f) { return 0.0, false; }
        acc += ws[i] * f;
        i += 1;
    }
    let h = fwd / PI * acc;
    var value = (cv + h - (fwd - strike)) * dr;
    if option == black::CALL { value = (cv + h) * dr; }
    if bad(value) { return 0.0, false; }
    return value, true;
}

fn jump(phi: f64, t: f64, j: i64, lam: f64, nu: f64, delta: f64) -> Cx {
    if lam == 0.0 { return re(0.0); }
    var ii = 0.0;
    if j == 1 { ii = 1.0; }
    let g = Cx { re: ii, im: phi };
    let delta2 = 0.5 * delta * delta;
    let expo = exp_cx(add(scale(g, nu), scale(mul(g, g), delta2)));
    let compensator = exp(nu + delta2) - 1.0;
    scale(sub(sub(expo, re(1.0)), scale(g, compensator)), t * lam)
}

fn zero_phi(j: i64, kappa: f64, theta: f64, v0: f64, rho: f64, sigma: f64, t: f64, log_fk: f64) -> f64 {
    if j == 1 {
        let kmr = rho * sigma - kappa;
        if abs(kmr) > 1.0e-7 {
            return log_fk + (exp(kmr * t) * kappa * theta - kappa * theta * (kmr * t + 1.0)) / (2.0 * kmr * kmr) - v0 * (1.0 - exp(kmr * t)) / (2.0 * kmr);
        }
        return log_fk + 0.25 * kappa * theta * t * t + 0.5 * v0 * t;
    }
    log_fk - (exp(-kappa * t) * kappa * theta + kappa * theta * (kappa * t - 1.0)) / (2.0 * kappa * kappa) - v0 * (1.0 - exp(-kappa * t)) / (2.0 * kappa)
}

fn fj(phi: f64, j: i64, kappa: f64, theta: f64, sigma: f64, v0: f64, rho: f64, t: f64, log_fk: f64, lam: f64, nu: f64, delta: f64) -> f64 {
    if phi == 0.0 { return zero_phi(j, kappa, theta, v0, rho, sigma, t, log_fk); }
    let sigma2 = sigma * sigma;
    var t0 = kappa;
    if j == 1 { t0 = kappa - rho * sigma; }
    let t1 = Cx { re: t0, im: -(rho * sigma * phi) };
    var imag = -1.0;
    if j == 1 { imag = 1.0; }
    let d = sqrt_cx(sub(mul(t1, t1), scale(Cx { re: -phi, im: imag }, sigma2 * phi)));
    let ex = exp_cx(scale(d, -t));
    let add_on = jump(phi, t, j, lam, nu, delta);
    let phase = Cx { re: 0.0, im: phi * log_fk };
    if sigma > 1.0e-5 {
        let p = div(sub(t1, d), add(t1, d));
        let g = log_cx(div(sub(re(1.0), mul(p, ex)), sub(re(1.0), p)));
        let exp_arg = add(add(add(
            div(scale(mul(sub(t1, d), sub(re(1.0), ex)), v0), scale(sub(re(1.0), mul(ex, p)), sigma2)),
            scale(sub(scale(sub(t1, d), t), scale(g, 2.0)), kappa * theta / sigma2)),
            phase), add_on);
        return exp_cx(exp_arg).im / phi;
    }
    let td = mul(div(re(phi), scale(t1, 2.0)), Cx { re: -phi, im: imag });
    let p = div(scale(td, sigma2), add(t1, d));
    let g = mul(p, sub(re(1.0), ex));
    let exp_arg = add(add(add(
        div(mul(scale(td, v0), sub(re(1.0), ex)), sub(re(1.0), mul(p, ex))),
        scale(sub(scale(td, t), scale(g, 2.0 / sigma2)), kappa * theta)),
        phase), add_on);
    exp_cx(exp_arg).im / phi
}

fn gatheral(option: i32, spot: f64, strike: f64, r: f64, q: f64, v0: f64, kappa: f64, theta: f64, sigma: f64, rho: f64, lam: f64, nu: f64, delta: f64, t: f64) -> f64, bool {
    if !market(option, spot, strike, r, q, v0, kappa, theta, sigma, rho, t) { return 0.0, false; }
    let dr = exp(-r * t);
    let dq = exp(-q * t);
    if !(dr > 0.0) || !(dq > 0.0) { return 0.0, false; }
    let fwd = spot * dq / dr;
    if bad(fwd) || fwd <= 0.0 { return 0.0, false; }
    let log_fk = log(fwd / strike);
    var xs: f64[144] = [0.0; 144];
    var ws: f64[144] = [0.0; 144];
    if !nodes(xs, ws) { return 0.0, false; }
    var p1 = 0.0;
    var p2 = 0.0;
    var i: i64 = 0;
    while i < 144 {
        let f1 = fj(xs[i], 1, kappa, theta, sigma, v0, rho, t, log_fk, lam, nu, delta);
        let f2 = fj(xs[i], 2, kappa, theta, sigma, v0, rho, t, log_fk, lam, nu, delta);
        if bad(f1) || bad(f2) { return 0.0, false; }
        p1 += ws[i] * f1;
        p2 += ws[i] * f2;
        i += 1;
    }
    p1 /= PI;
    p2 /= PI;
    var value = spot * dq * (p1 - 0.5) - strike * dr * (p2 - 0.5);
    if option == black::CALL { value = spot * dq * (p1 + 0.5) - strike * dr * (p2 + 0.5); }
    if bad(value) { return 0.0, false; }
    return value, true;
}
