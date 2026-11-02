// Binomial trees from QuantLib's binomialtree.cpp, rolled back like
// BlackScholesLattice: one discount exp(-r dt) and a constant up probability.
// European exercise is the terminal payoff. American exercise is every step.
// Bermudan exercise is the grid time closest to each stop.

import math;
import black;

namespace tree;

const EUROPEAN: i32 = 0;
const AMERICAN: i32 = 1;
const BERMUDAN: i32 = 2;

fn roll(option: i32, spot: f64, strike: f64, r: f64, t: f64, steps: i32, up: f64, down: f64, pu: f64, style: i32, stops: f64[:]) -> f64, bool {
    if option != black::CALL && option != black::PUT { return 0.0, false; }
    if spot <= 0.0 || strike <= 0.0 || t <= 0.0 || steps < 2 || up <= 0.0 || down <= 0.0 { return 0.0, false; }
    if pu < 0.0 || pu > 1.0 { return 0.0, false; }
    let pd = 1.0 - pu;
    let dt = t / steps;
    let df = exp(-r * dt);
    let n = steps as i64;
    let ratio = up / down;
    var value: f64[>..] = [];
    var s = spot * pow(down, n);
    var j: i64 = 0;
    while j <= n {
        var payoff = (s - strike) * option;
        if payoff < 0.0 { payoff = 0.0; }
        value.push(payoff);
        s *= ratio;
        j += 1;
    }
    var i = n;
    while i > 0 {
        i -= 1;
        s = spot * pow(down, i);
        j = 0;
        var exercise_here = style == AMERICAN;
        if style == BERMUDAN {
            var k: i64 = 0;
            while k < stops.len {
                let step = (stops[k] / dt + 0.5) as i64;
                if step == i { exercise_here = true; }
                k += 1;
            }
        }
        while j <= i {
            var held = (pd * value[j] + pu * value[j + 1]) * df;
            if exercise_here {
                var exercise = (s - strike) * option;
                if exercise < 0.0 { exercise = 0.0; }
                if exercise > held { held = exercise; }
            }
            value[j] = held;
            s *= ratio;
            j += 1;
        }
    }
    return value[0], true;
}

fn crr_factors(r: f64, q: f64, vol: f64, t: f64, steps: i32) -> f64, f64, f64, bool {
    if vol <= 0.0 || t <= 0.0 || steps < 2 { return 0.0, 0.0, 0.0, false; }
    let dt = t / steps;
    let dx = vol * sqrt(dt);
    let drift = (r - q - 0.5 * vol * vol) * dt;
    let pu = 0.5 + 0.5 * drift / dx;
    return exp(dx), exp(-dx), pu, true;
}

fn crr(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, steps: i32, american: bool) -> f64, bool {
    let up, down, pu, ok = crr_factors(r, q, vol, t, steps);
    if !ok { return 0.0, false; }
    var style = EUROPEAN;
    if american { style = AMERICAN; }
    var hole: f64[1] = [0.0];
    return roll(option, spot, strike, r, t, steps, up, down, pu, style, hole[0..0]);
}

fn jr(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, steps: i32, style: i32, stops: f64[:]) -> f64, bool {
    if vol <= 0.0 || t <= 0.0 { return 0.0, false; }
    let dt = t / steps;
    let dx = vol * sqrt(dt);
    let drift = (r - q - 0.5 * vol * vol) * dt;
    return roll(option, spot, strike, r, t, steps, exp(drift + dx), exp(drift - dx), 0.5, style, stops);
}

fn crr_style(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, steps: i32, style: i32, stops: f64[:]) -> f64, bool {
    let up, down, pu, ok = crr_factors(r, q, vol, t, steps);
    if !ok { return 0.0, false; }
    return roll(option, spot, strike, r, t, steps, up, down, pu, style, stops);
}

fn additive(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, steps: i32, style: i32, stops: f64[:]) -> f64, bool {
    if vol <= 0.0 || t <= 0.0 { return 0.0, false; }
    let dt = t / steps;
    let drift = (r - q - 0.5 * vol * vol) * dt;
    let radicand = 4.0 * vol * vol * dt - 3.0 * drift * drift;
    if radicand < 0.0 { return 0.0, false; }
    let jump = -0.5 * drift + 0.5 * sqrt(radicand);
    return roll(option, spot, strike, r, t, steps, exp(drift + jump), exp(drift - jump), 0.5, style, stops);
}

fn trigeorgis(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, steps: i32, style: i32, stops: f64[:]) -> f64, bool {
    if vol <= 0.0 || t <= 0.0 { return 0.0, false; }
    let dt = t / steps;
    let drift = (r - q - 0.5 * vol * vol) * dt;
    let dx = sqrt(vol * vol * dt + drift * drift);
    if dx == 0.0 { return 0.0, false; }
    let pu = 0.5 + 0.5 * drift / dx;
    return roll(option, spot, strike, r, t, steps, exp(dx), exp(-dx), pu, style, stops);
}

fn tian(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, steps: i32, style: i32, stops: f64[:]) -> f64, bool {
    if vol <= 0.0 || t <= 0.0 { return 0.0, false; }
    let dt = t / steps;
    let drift = (r - q - 0.5 * vol * vol) * dt;
    let v = exp(vol * vol * dt);
    let growth = exp(drift) * sqrt(v);
    let width = sqrt(v * v + 2.0 * v - 3.0);
    let up = 0.5 * growth * v * (v + 1.0 + width);
    let down = 0.5 * growth * v * (v + 1.0 - width);
    if up == down { return 0.0, false; }
    let pu = (growth - down) / (up - down);
    return roll(option, spot, strike, r, t, steps, up, down, pu, style, stops);
}

fn peizer(z: f64, n: f64) -> f64 {
    let denom = n + 1.0 / 3.0 + 0.1 / (n + 1.0);
    let result = exp(-(z / denom) * (z / denom) * (n + 1.0 / 6.0));
    let root = sqrt(1.0 - result);
    if z > 0.0 { return 0.5 * (1.0 + root); }
    return 0.5 * result / (1.0 + root);
}

fn odd(steps: i32) -> i32 {
    if steps % 2 == 0 { return steps + 1; }
    return steps;
}

fn leisen(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, steps: i32, style: i32, stops: f64[:]) -> f64, bool {
    if vol <= 0.0 || t <= 0.0 || spot <= 0.0 || strike <= 0.0 { return 0.0, false; }
    let n = odd(steps);
    let dt = t / n;
    let drift = (r - q - 0.5 * vol * vol) * dt;
    let variance = vol * vol * t;
    let width = sqrt(variance);
    let nf = n;
    let d2 = (log(spot / strike) + drift * nf) / width;
    let pu = peizer(d2, nf);
    if pu <= 0.0 || pu >= 1.0 { return 0.0, false; }
    let growth = exp((r - q) * dt);
    let up = growth * peizer(d2 + width, nf) / pu;
    let down = (growth - pu * up) / (1.0 - pu);
    return roll(option, spot, strike, r, t, n, up, down, pu, style, stops);
}

fn joshi_p(k: f64, dj: f64) -> f64 {
    let alpha = dj / sqrt(8.0);
    let alpha2 = alpha * alpha;
    let alpha3 = alpha * alpha2;
    let alpha5 = alpha3 * alpha2;
    let alpha7 = alpha5 * alpha2;
    let beta = -0.375 * alpha - alpha3;
    let gamma = (5.0 / 6.0) * alpha5 + (13.0 / 12.0) * alpha3 + (25.0 / 128.0) * alpha;
    let delta = -0.1025 * alpha - 0.9285 * alpha3 - 1.43 * alpha5 - 0.5 * alpha7;
    let rootk = sqrt(k);
    return 0.5 + alpha / rootk + beta / (k * rootk) + gamma / (k * k * rootk) + delta / (k * k * k * rootk);
}

fn joshi(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, steps: i32, style: i32, stops: f64[:]) -> f64, bool {
    if vol <= 0.0 || t <= 0.0 || spot <= 0.0 || strike <= 0.0 { return 0.0, false; }
    let n = odd(steps);
    let dt = t / n;
    let drift = (r - q - 0.5 * vol * vol) * dt;
    let variance = vol * vol * t;
    let width = sqrt(variance);
    let nf = n;
    let d2 = (log(spot / strike) + drift * nf) / width;
    let k = (nf - 1.0) / 2.0;
    let pu = joshi_p(k, d2);
    if pu <= 0.0 || pu >= 1.0 { return 0.0, false; }
    let growth = exp((r - q) * dt);
    let up = growth * joshi_p(k, d2 + width) / pu;
    let down = (growth - pu * up) / (1.0 - pu);
    return roll(option, spot, strike, r, t, n, up, down, pu, style, stops);
}
