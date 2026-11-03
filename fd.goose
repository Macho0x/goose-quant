// Log-spot Crank-Nicolson for a Black-Scholes-Merton vanilla.
// FdBlackScholesVanillaEngine defaults to Douglas with theta 1/2, which is
// this scheme in one factor. Grid ends are that engine's mesher: the inverse
// normal at 1 - 0.0001, scaled by 1.5 around the forward. European exercise
// is the terminal payoff. American exercise is every step. Bermudan exercise
// is the step that crosses each stop before expiry.

import math;
import black;
import normal;

namespace fd;

const EUROPEAN: i32 = 0;
const AMERICAN: i32 = 1;
const BERMUDAN: i32 = 2;

fn crossed(stops: f64[:], now: f64, prev: f64, maturity: f64) -> bool {
    var k: i64 = 0;
    while k < stops.len {
        let when = stops[k];
        if when < maturity && now <= when && when < prev { return true; }
        k += 1;
    }
    return false;
}

fn npv(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, time_steps: i32, x_steps: i32, style: i32, stops: f64[:]) -> f64, bool {
    if option != black::CALL && option != black::PUT { return 0.0, false; }
    if spot <= 0.0 || strike <= 0.0 || vol <= 0.0 || t <= 0.0 { return 0.0, false; }
    if time_steps < 1 || x_steps < 3 { return 0.0, false; }
    if style != EUROPEAN && style != AMERICAN && style != BERMUDAN { return 0.0, false; }

    let z, zok = normal::inv_cdf(1.0 - 0.0001);
    if !zok { return 0.0, false; }
    let fwd = spot * exp((r - q) * t);
    var lo_s = spot;
    var hi_s = spot;
    if fwd < lo_s { lo_s = fwd; }
    if fwd > hi_s { hi_s = fwd; }
    let width = vol * sqrt(t) * z * 1.5;
    let x_min = log(lo_s) - width;
    let x_max = log(hi_s) + width;
    if x_max <= x_min { return 0.0, false; }

    let n = x_steps as i64;
    let steps = time_steps as i64;
    let dx = (x_max - x_min) / (n - 1);
    let dt = t / steps;
    let mu = r - q - 0.5 * vol * vol;
    let nu = 0.5 * vol * vol;
    let alpha = nu / (dx * dx) - mu / (2.0 * dx);
    let beta = -2.0 * nu / (dx * dx) - r;
    let gamma = nu / (dx * dx) + mu / (2.0 * dx);
    let th = 0.5 * dt;
    let a = -th * alpha;
    let b = 1.0 - th * beta;
    let c = -th * gamma;
    let ar = th * alpha;
    let br = 1.0 + th * beta;
    let cr = th * gamma;
    if b == 0.0 { return 0.0, false; }

    let m = n - 2;
    var value: f64[>..] = [];
    var intr: f64[>..] = [];
    var work: f64[>..] = [];
    var cprime: f64[>..] = [];
    var inv: f64[>..] = [];
    var s_lo = 0.0;
    var s_hi = 0.0;
    var i: i64 = 0;
    while i < n {
        let level = exp(x_min + i * dx);
        var payoff = (level - strike) * option;
        if payoff < 0.0 { payoff = 0.0; }
        if i == 0 { s_lo = level; }
        s_hi = level;
        value.push(payoff);
        intr.push(payoff);
        i += 1;
    }
    i = 0;
    while i < m {
        work.push(0.0);
        cprime.push(0.0);
        inv.push(0.0);
        i += 1;
    }

    inv[0] = 1.0 / b;
    cprime[0] = c * inv[0];
    if m > 1 {
        i = 1;
        while i < m - 1 {
            let denom = b - a * cprime[i - 1];
            if denom == 0.0 { return 0.0, false; }
            inv[i] = 1.0 / denom;
            cprime[i] = c * inv[i];
            i += 1;
        }
        let last = b - a * cprime[m - 2];
        if last == 0.0 { return 0.0, false; }
        inv[m - 1] = 1.0 / last;
        cprime[m - 1] = 0.0;
    }

    var step: i64 = 1;
    while step <= steps {
        let tau = step * dt;
        let now = t - tau;
        let prev = now + dt;
        let df_r = exp(-r * tau);
        let df_q = exp(-q * tau);
        var v_lo = (s_lo * df_q - strike * df_r) * option;
        if v_lo < 0.0 { v_lo = 0.0; }
        var v_hi = (s_hi * df_q - strike * df_r) * option;
        if v_hi < 0.0 { v_hi = 0.0; }

        i = 1;
        while i < n - 1 {
            work[i - 1] = ar * value[i - 1] + br * value[i] + cr * value[i + 1];
            i += 1;
        }
        work[0] = work[0] - a * v_lo;
        work[m - 1] = work[m - 1] - c * v_hi;

        work[0] = work[0] * inv[0];
        i = 1;
        while i < m {
            work[i] = (work[i] - a * work[i - 1]) * inv[i];
            i += 1;
        }
        i = m - 2;
        while i >= 0 {
            work[i] = work[i] - cprime[i] * work[i + 1];
            i -= 1;
        }

        value[0] = v_lo;
        value[n - 1] = v_hi;
        i = 0;
        while i < m {
            value[i + 1] = work[i];
            i += 1;
        }

        var exercise = style == AMERICAN;
        if style == BERMUDAN && crossed(stops, now, prev, t) { exercise = true; }
        if exercise {
            i = 0;
            while i < n {
                if intr[i] > value[i] { value[i] = intr[i]; }
                i += 1;
            }
        }
        step += 1;
    }

    let x = log(spot);
    if x <= x_min { return value[0], true; }
    if x >= x_max { return value[n - 1], true; }
    let pos = (x - x_min) / dx;
    var idx = pos as i64;
    if idx < 0 { idx = 0; }
    if idx > n - 2 { idx = n - 2; }
    let w = pos - idx;
    return value[idx] * (1.0 - w) + value[idx + 1] * w, true;
}
