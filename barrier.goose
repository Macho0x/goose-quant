// Analytic barrier, QuantLib's AnalyticBarrierEngine (Haug).
// A knocked-out rebate is paid at the hit. A knocked-in rebate is paid at expiry.
// Spot on the barrier is already triggered, so the caller gets false.

import math;
import normal;
import black;

namespace barrier;

const DOWN_IN: i32 = 1;
const UP_IN: i32 = 2;
const DOWN_OUT: i32 = 3;
const UP_OUT: i32 = 4;

fn piece(phi: f64, spot: f64, strike: f64, df_q: f64, df_r: f64, n1: f64, n2: f64) -> f64 {
    return phi * (spot * df_q * n1 - strike * df_r * n2);
}

fn safe(pow_hs: f64, n: f64) -> f64 {
    if n == 0.0 { return 0.0; }
    return pow_hs * n;
}

fn reflected(phi: f64, eta: f64, y: f64, std: f64, spot: f64, strike: f64, df_q: f64, df_r: f64, pow1: f64, pow0: f64) -> f64 {
    let n1 = safe(pow1, normal::cdf(eta * y));
    let n2 = safe(pow0, normal::cdf(eta * (y - std)));
    return piece(phi, spot, strike, df_q, df_r, n1, n2);
}

fn npv(option: i32, kind: i32, h: f64, rebate: f64, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64) -> f64, bool {
    if option != black::CALL && option != black::PUT { return 0.0, false; }
    if spot <= 0.0 || strike <= 0.0 || h <= 0.0 || vol < 0.0 || t < 0.0 { return 0.0, false; }
    let down = kind == DOWN_IN || kind == DOWN_OUT;
    let up = kind == UP_IN || kind == UP_OUT;
    if !down && !up { return 0.0, false; }
    if down && spot <= h { return 0.0, false; }
    if up && spot >= h { return 0.0, false; }
    let df_r = exp(-r * t);
    let df_q = exp(-q * t);
    let variance = vol * vol * t;
    if variance < 2.2204460492503131e-16 {
        let forward = spot * df_q / df_r;
        var hit = spot == h;
        if down && forward <= h { hit = true; }
        if up && forward >= h { hit = true; }
        var vanilla = (forward - strike) * option;
        if vanilla < 0.0 { vanilla = 0.0; }
        vanilla *= df_r;
        let knock_in = kind == DOWN_IN || kind == UP_IN;
        if knock_in {
            if hit { return vanilla, true; }
            return rebate * df_r, true;
        }
        if hit { return rebate * df_r, true; }
        return vanilla, true;
    }
    let std = sqrt(variance);
    let mu = (r - q) / (vol * vol) - 0.5;
    let mu_sigma = (1.0 + mu) * std;
    let hs = h / spot;
    let pow0 = pow(hs, 2.0 * mu);
    let pow1 = pow0 * hs * hs;

    let x1 = log(spot / strike) / std + mu_sigma;
    let a = piece(1.0, spot, strike, df_q, df_r, normal::cdf(x1), normal::cdf(x1 - std));
    let am = piece(-1.0, spot, strike, df_q, df_r, normal::cdf(-x1), normal::cdf(-(x1 - std)));

    let x2 = log(spot / h) / std + mu_sigma;
    let b = piece(1.0, spot, strike, df_q, df_r, normal::cdf(x2), normal::cdf(x2 - std));
    let bm = piece(-1.0, spot, strike, df_q, df_r, normal::cdf(-x2), normal::cdf(-(x2 - std)));

    let y1 = log(h * hs / strike) / std + mu_sigma;
    let y2 = log(h / spot) / std + mu_sigma;
    let c11 = reflected(1.0, 1.0, y1, std, spot, strike, df_q, df_r, pow1, pow0);
    let c1m = reflected(-1.0, 1.0, y1, std, spot, strike, df_q, df_r, pow1, pow0);
    let cm1 = reflected(1.0, -1.0, y1, std, spot, strike, df_q, df_r, pow1, pow0);
    let cmm = reflected(-1.0, -1.0, y1, std, spot, strike, df_q, df_r, pow1, pow0);
    let d11 = reflected(1.0, 1.0, y2, std, spot, strike, df_q, df_r, pow1, pow0);
    let d1m = reflected(-1.0, 1.0, y2, std, spot, strike, df_q, df_r, pow1, pow0);
    let dm1 = reflected(1.0, -1.0, y2, std, spot, strike, df_q, df_r, pow1, pow0);
    let dmm = reflected(-1.0, -1.0, y2, std, spot, strike, df_q, df_r, pow1, pow0);

    var e = 0.0;
    var em = 0.0;
    var f = 0.0;
    var fm = 0.0;
    if rebate > 0.0 {
        let n1 = normal::cdf(x2 - std);
        let n2 = normal::cdf(y2 - std);
        e = rebate * df_r * (n1 - safe(pow0, n2));
        let n1m = normal::cdf(-(x2 - std));
        let n2m = normal::cdf(-(y2 - std));
        em = rebate * df_r * (n1m - safe(pow0, n2m));
        let lambda = sqrt(mu * mu + 2.0 * r / (vol * vol));
        let plus = pow(hs, mu + lambda);
        let minus = pow(hs, mu - lambda);
        let z = log(h / spot) / std + lambda * std;
        f = rebate * (safe(plus, normal::cdf(z)) + safe(minus, normal::cdf(z - 2.0 * lambda * std)));
        fm = rebate * (safe(plus, normal::cdf(-z)) + safe(minus, normal::cdf(-(z - 2.0 * lambda * std))));
    }

    let above = strike >= h;
    if option == black::CALL {
        if kind == DOWN_IN {
            if above { return c11 + e, true; }
            return a - b + d11 + e, true;
        }
        if kind == UP_IN {
            if above { return a + em, true; }
            return b - cm1 + dm1 + em, true;
        }
        if kind == DOWN_OUT {
            if above { return a - c11 + f, true; }
            return b - d11 + f, true;
        }
        if above { return fm, true; }
        return a - b + cm1 - dm1 + fm, true;
    }
    if kind == DOWN_IN {
        if above { return bm - c1m + d1m + e, true; }
        return am + e, true;
    }
    if kind == UP_IN {
        if above { return am - bm + dmm + em, true; }
        return cmm + em, true;
    }
    if kind == DOWN_OUT {
        if above { return am - bm + c1m - d1m + f, true; }
        return f, true;
    }
    if above { return bm - dmm + fm, true; }
    return am - cmm + fm, true;
}
