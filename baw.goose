// Barone-Adesi/Whaley American approximation.
// The critical price is the Newton loop in BaroneAdesiWhaleyApproximationEngine.

import math;
import black;
import normal;

namespace baw;

fn critical(option: i32, strike: f64, df_r: f64, df_q: f64, variance: f64) -> f64, bool {
    if df_r > 1.0 || variance <= 0.0 || strike <= 0.0 { return 0.0, false; }
    let n = 2.0 * log(df_q / df_r) / variance;
    let m = -2.0 * log(df_r) / variance;
    let b_t = log(df_q / df_r);
    let disc = sqrt((n - 1.0) * (n - 1.0) + 4.0 * m);
    var qu = 0.0;
    var si = 0.0;
    if option == black::CALL {
        qu = (-(n - 1.0) + disc) / 2.0;
        let su = strike / (1.0 - 1.0 / qu);
        let h = -(b_t + 2.0 * sqrt(variance)) * strike / (su - strike);
        si = strike + (su - strike) * (1.0 - exp(h));
        if !(si > strike) || is_nan(si) { si = su; }
    } else {
        qu = (-(n - 1.0) - disc) / 2.0;
        let su = strike / (1.0 - 1.0 / qu);
        let h = (b_t - 2.0 * sqrt(variance)) * strike / (strike - su);
        si = su + (strike - su) * exp(h);
        if !(si > 0.0 && si < strike) || is_nan(si) { si = su; }
    }
    var k = 2.0 / variance;
    let gap = df_r - 1.0;
    var agap = gap;
    if agap < 0.0 { agap = -agap; }
    if agap > 1000.0 * 2.2204460492503131e-16 {
        k = -2.0 * log(df_r) / (variance * (1.0 - df_r));
    }
    let std = sqrt(variance);
    var forward = si * df_q / df_r;
    var d1 = (log(forward / strike) + 0.5 * variance) / std;
    let temp, tok = black::black(option, strike, forward, std, df_r, 0.0);
    if !tok { return 0.0, false; }
    var q = 0.0;
    var lhs = 0.0;
    var rhs = 0.0;
    var bi = 0.0;
    let root = sqrt((n - 1.0) * (n - 1.0) + 4.0 * k);
    if option == black::CALL {
        q = (-(n - 1.0) + root) / 2.0;
        lhs = si - strike;
        rhs = temp + (1.0 - df_q * normal::cdf(d1)) * si / q;
        bi = df_q * normal::cdf(d1) * (1.0 - 1.0 / q) + (1.0 - df_q * normal::pdf(d1) / std) / q;
    } else {
        q = (-(n - 1.0) - root) / 2.0;
        lhs = strike - si;
        rhs = temp - (1.0 - df_q * normal::cdf(-d1)) * si / q;
        bi = -df_q * normal::cdf(-d1) * (1.0 - 1.0 / q) - (1.0 + df_q * normal::pdf(-d1) / std) / q;
    }
    var step: i32 = 0;
    while step < 80 {
        var diff = lhs - rhs;
        if diff < 0.0 { diff = -diff; }
        if diff / strike <= 1.0e-6 { return si, true; }
        if option == black::CALL {
            si = (strike + rhs - bi * si) / (1.0 - bi);
        } else {
            si = (strike - rhs + bi * si) / (1.0 + bi);
        }
        forward = si * df_q / df_r;
        d1 = (log(forward / strike) + 0.5 * variance) / std;
        let px, pok = black::black(option, strike, forward, std, df_r, 0.0);
        if !pok { return 0.0, false; }
        if option == black::CALL {
            lhs = si - strike;
            rhs = px + (1.0 - df_q * normal::cdf(d1)) * si / q;
            bi = df_q * normal::cdf(d1) * (1.0 - 1.0 / q) + (1.0 - df_q * normal::pdf(d1) / std) / q;
        } else {
            lhs = strike - si;
            rhs = px - (1.0 - df_q * normal::cdf(-d1)) * si / q;
            bi = -df_q * normal::cdf(-d1) * (1.0 - 1.0 / q) - (1.0 + df_q * normal::pdf(-d1) / std) / q;
        }
        step += 1;
    }
    return 0.0, false;
}

fn npv(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64) -> f64, bool {
    if option != black::CALL && option != black::PUT { return 0.0, false; }
    if spot <= 0.0 || strike <= 0.0 || vol < 0.0 || t < 0.0 { return 0.0, false; }
    let variance = vol * vol * t;
    let df_r = exp(-r * t);
    let df_q = exp(-q * t);
    let forward = spot * df_q / df_r;
    let euro, eok = black::black(option, strike, forward, vol * sqrt(t), df_r, 0.0);
    if !eok { return 0.0, false; }
    let call_holds = df_q >= 1.0 && df_q >= df_r && option == black::CALL;
    let put_holds = df_r >= 1.0 && df_r >= df_q && option == black::PUT;
    if call_holds || put_holds { return euro, true; }
    if variance < 2.2204460492503131e-16 {
        var intrinsic = (spot - strike) * option;
        if intrinsic < 0.0 { intrinsic = 0.0; }
        if intrinsic > euro { return intrinsic, true; }
        return euro, true;
    }
    let sk, sok = critical(option, strike, df_r, df_q, variance);
    if !sok { return 0.0, false; }
    let forward_sk = sk * df_q / df_r;
    let d1 = (log(forward_sk / strike) + 0.5 * variance) / sqrt(variance);
    let n = 2.0 * log(df_q / df_r) / variance;
    var big_k = 2.0 / variance;
    var agap = df_r - 1.0;
    if agap < 0.0 { agap = -agap; }
    if agap > 1000.0 * 2.2204460492503131e-16 {
        big_k = -2.0 * log(df_r) / (variance * (1.0 - df_r));
    }
    let root = sqrt((n - 1.0) * (n - 1.0) + 4.0 * big_k);
    if option == black::CALL {
        let qn = (-(n - 1.0) + root) / 2.0;
        let a = (sk / qn) * (1.0 - df_q * normal::cdf(d1));
        if spot < sk { return euro + a * pow(spot / sk, qn), true; }
        return spot - strike, true;
    }
    let qn = (-(n - 1.0) - root) / 2.0;
    let a = -(sk / qn) * (1.0 - df_q * normal::cdf(-d1));
    if spot > sk { return euro + a * pow(spot / sk, qn), true; }
    return strike - spot, true;
}
