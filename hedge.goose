// Discrete hedging replication error from QuantLib's DiscreteHedging example.
// The hedge sells the Black-Scholes call and rebalances delta on a lognormal
// path. Uniforms are MT19937; normals are Acklam's inverse cdf. Seed 0 draws
// from QuantLib's clock-based SeedGenerator, the same rule as
// MersenneTwisterUniformRng(0).

import os;
import math;
import black;
import normal;

namespace hedge;

const N: i64 = 624;
const M: i64 = 397;
const MATRIX_A: u32 = 0x9908b0df;
const UPPER: u32 = 0x80000000;
const LOWER: u32 = 0x7fffffff;
const EPS: f64 = 2.2204460492503131e-16;

const TOP: u8[:] = "         |          |      P&L |      P&L | Derman&Kamal |      P&L |      P&L";
const COLUMNS: u8[:] = " samples |   trades |     mean | std.dev. |      formula | skewness | kurtosis";

struct Mt {
    mt: u32[624],
    mti: i64,
}

struct Stats {
    mean: f64,
    dev: f64,
    skew: f64,
    kurt: f64,
    formula: f64,
}

var seed_rng: Mt = Mt { mt: [0; 624], mti: 624 };
var seed_on = false;

fn finite(x: f64) -> bool {
    if is_nan(x) || is_inf(x) { return false; }
    return true;
}

fn close_to(got: f64, want: f64, tol: f64) -> bool {
    var d = got - want;
    if d < 0.0 { d = -d; }
    return d <= tol;
}

fn near_eq(x: f64, y: f64) -> bool {
    if x == y { return true; }
    var diff = x - y;
    if diff < 0.0 { diff = -diff; }
    let tol = 42.0 * EPS;
    if x == 0.0 || y == 0.0 { return diff < tol * tol; }
    var ax = x;
    if ax < 0.0 { ax = -ax; }
    var ay = y;
    if ay < 0.0 { ay = -ay; }
    return diff <= tol * ax && diff <= tol * ay;
}

fn blank() -> Stats {
    return Stats { mean: 0.0, dev: 0.0, skew: 0.0, kurt: 0.0, formula: 0.0 };
}

fn fresh() -> Mt {
    return Mt { mt: [0; 624], mti: N };
}

fn mag(y: u32) -> u32 {
    if (y & 1) == 1 { return MATRIX_A; }
    return 0;
}

fn init_seed(rng: Mt&, seed: u32) {
    rng.mt[0] = seed;
    var i: i64 = 1;
    while i < N {
        let prev = rng.mt[i - 1];
        rng.mt[i] = 1812433253 * (prev ^ (prev >> 30)) + (i as u32);
        i += 1;
    }
    rng.mti = N;
}

fn init_array(rng: Mt&, seeds: u32[:]) {
    init_seed(rng, 19650218);
    var i: i64 = 1;
    var j: i64 = 0;
    var k = N;
    if seeds.len > N { k = seeds.len; }
    while k != 0 {
        let prev = rng.mt[i - 1];
        rng.mt[i] = (rng.mt[i] ^ ((prev ^ (prev >> 30)) * 1664525)) + seeds[j] + (j as u32);
        i += 1;
        j += 1;
        if i >= N {
            rng.mt[0] = rng.mt[N - 1];
            i = 1;
        }
        if j >= seeds.len { j = 0; }
        k -= 1;
    }
    k = N - 1;
    while k != 0 {
        let prev = rng.mt[i - 1];
        rng.mt[i] = (rng.mt[i] ^ ((prev ^ (prev >> 30)) * 1566083941)) - (i as u32);
        i += 1;
        if i >= N {
            rng.mt[0] = rng.mt[N - 1];
            i = 1;
        }
        k -= 1;
    }
    rng.mt[0] = UPPER;
    rng.mti = N;
}

fn twist(rng: Mt&) {
    var kk: i64 = 0;
    while kk < N - M {
        let y = (rng.mt[kk] & UPPER) | (rng.mt[kk + 1] & LOWER);
        rng.mt[kk] = rng.mt[kk + M] ^ (y >> 1) ^ mag(y);
        kk += 1;
    }
    while kk < N - 1 {
        let y = (rng.mt[kk] & UPPER) | (rng.mt[kk + 1] & LOWER);
        rng.mt[kk] = rng.mt[kk + M - N] ^ (y >> 1) ^ mag(y);
        kk += 1;
    }
    let y = (rng.mt[N - 1] & UPPER) | (rng.mt[0] & LOWER);
    rng.mt[N - 1] = rng.mt[M - 1] ^ (y >> 1) ^ mag(y);
    rng.mti = 0;
}

fn next_u32(rng: Mt&) -> u32 {
    if rng.mti >= N { twist(rng); }
    var y = rng.mt[rng.mti];
    rng.mti += 1;
    y ^= y >> 11;
    y ^= (y << 7) & 0x9d2c5680;
    y ^= (y << 15) & 0xefc60000;
    y ^= y >> 18;
    return y;
}

fn next_unit(rng: Mt&) -> f64 {
    return (next_u32(rng) + 0.5) / 4294967296.0;
}

fn next_gauss(rng: Mt&) -> f64, bool {
    return normal::inv_cdf(next_unit(rng));
}

fn mt_word(seed: u32, index: i64) -> u32 {
    var rng = fresh();
    init_seed(rng, seed);
    var i: i64 = 0;
    var y: u32 = 0;
    while i <= index {
        y = next_u32(rng);
        i += 1;
    }
    return y;
}

fn draw_seed() -> u32 {
    if !seed_on {
        let seconds = (clock_ns() / 1000000000) as u32;
        var first = fresh();
        init_seed(first, seconds);
        let second_seed = next_u32(first);
        var second = fresh();
        init_seed(second, second_seed);
        let skip = next_u32(second) % 1000;
        var key: u32[4] = [0, 0, 0, 0];
        key[0] = next_u32(second);
        key[1] = next_u32(second);
        key[2] = next_u32(second);
        key[3] = next_u32(second);
        init_array(seed_rng, key);
        var i: u32 = 0;
        while i < skip {
            next_u32(seed_rng);
            i += 1;
        }
        seed_on = true;
    }
    return next_u32(seed_rng);
}

fn open_rng(rng: Mt&, seed: u32) {
    var s = seed;
    if s == 0 { s = draw_seed(); }
    init_seed(rng, s);
}

fn call_delta(spot: f64, strike: f64, r: f64, sigma: f64, tau: f64) -> f64, bool {
    if spot <= 0.0 || strike <= 0.0 || tau < 0.0 || sigma < 0.0 || r < 0.0 { return 0.0, false; }
    let df = exp(-r * tau);
    if df == 0.0 { return 0.0, false; }
    let forward = spot / df;
    let std = sqrt(sigma * sigma * tau);
    if std <= EPS {
        if near_eq(forward, strike) { return df * 0.5 * forward / spot, true; }
        if forward > strike { return df * forward / spot, true; }
        return 0.0, true;
    }
    let d1 = log(forward / strike) / std + 0.5 * std;
    return normal::cdf(d1) * df * forward / spot, true;
}

fn call_vega(spot: f64, strike: f64, r: f64, sigma: f64, maturity: f64) -> f64, bool {
    if spot <= 0.0 || strike <= 0.0 || sigma <= 0.0 || maturity <= 0.0 || r < 0.0 { return 0.0, false; }
    let df = exp(-r * maturity);
    if df == 0.0 { return 0.0, false; }
    let forward = spot / df;
    let std = sqrt(sigma * sigma * maturity);
    let variance = std * std;
    if variance == 0.0 { return 0.0, false; }
    let d1 = log(forward / strike) / std + 0.5 * std;
    let d2 = d1 - std;
    let temp = log(strike / forward) / variance;
    let da = normal::pdf(d1) * (temp + 0.5);
    let db = -normal::pdf(d2) * (temp - 0.5);
    return df * sqrt(maturity) * (da * forward + db * strike), true;
}

fn kamal(steps: i64, spot: f64, strike: f64, r: f64, sigma: f64, maturity: f64) -> f64, bool {
    if steps <= 0 { return 0.0, false; }
    let v, ok = call_vega(spot, strike, r, sigma, maturity);
    if !ok { return 0.0, false; }
    return sqrt(PI / 4.0 / steps) * v * sigma, true;
}

fn pnl(dw: f64[:], spot0: f64, strike: f64, r: f64, sigma: f64, maturity: f64) -> f64, bool {
    let n = dw.len;
    if n <= 0 || spot0 <= 0.0 || strike <= 0.0 || maturity <= 0.0 || sigma < 0.0 || r < 0.0 {
        return 0.0, false;
    }
    let dt = maturity / n;
    let df0 = exp(-r * maturity);
    if df0 == 0.0 { return 0.0, false; }
    let forward0 = spot0 / df0;
    let std0 = sqrt(sigma * sigma * maturity);
    let premium, pok = black::black(black::CALL, strike, forward0, std0, df0, 0.0);
    if !pok { return 0.0, false; }
    let delta0, d0ok = call_delta(spot0, strike, r, sigma, maturity);
    if !d0ok { return 0.0, false; }
    var money = premium - delta0 * spot0;
    var held = delta0;
    var stock = spot0;
    let var_dt = sigma * sigma * dt;
    let drift = r * dt - 0.5 * var_dt;
    let deviate = sqrt(var_dt);
    let accrue = exp(r * dt);
    var step: i64 = 0;
    var t = 0.0;
    while step < n - 1 {
        money *= accrue;
        t += dt;
        stock *= exp(drift + deviate * dw[step]);
        let delta, dok = call_delta(stock, strike, r, sigma, maturity - t);
        if !dok { return 0.0, false; }
        money -= (delta - held) * stock;
        held = delta;
        step += 1;
    }
    money *= accrue;
    stock *= exp(drift + deviate * dw[n - 1]);
    var payoff = stock - strike;
    if payoff < 0.0 { payoff = 0.0; }
    money -= payoff;
    money += held * stock;
    return money, true;
}

fn g6(out: u8[>..]&, x: f64) {
    if is_nan(x) {
        format(out, "nan");
        return;
    }
    if is_inf(x) {
        if x < 0.0 { format(out, "-inf"); } else { format(out, "inf"); }
        return;
    }
    if x == 0.0 {
        format(out, "0");
        return;
    }
    var neg = false;
    var v = x;
    if v < 0.0 {
        neg = true;
        v = -v;
    }
    var e: i64 = 0;
    while v >= 10.0 {
        v /= 10.0;
        e += 1;
    }
    while v < 1.0 {
        v *= 10.0;
        e -= 1;
    }
    var n = (v * 100000.0 + 0.5) as i64;
    if n >= 1000000 {
        n = 100000;
        e += 1;
    }
    if neg { format(out, "-"); }
    var digits: u8[>..] = [];
    format_int(digits, n, 10, 6, '0');
    if e < -4 || e >= 6 {
        format(out, digits[0..1]);
        var end = digits.len;
        while end > 1 && digits[end - 1] == '0' { end -= 1; }
        if end > 1 {
            format(out, ".");
            format(out, digits[1..end]);
        }
        var ee = e;
        if ee < 0 {
            format(out, "e-");
            ee = -ee;
        } else {
            format(out, "e+");
        }
        if ee < 10 { format(out, "0"); }
        format_int(out, ee, 10, 1, '0');
        return;
    }
    if e >= 0 {
        let cut = e + 1;
        format(out, digits[0..cut]);
        var end = digits.len;
        while end > cut && digits[end - 1] == '0' { end -= 1; }
        if end > cut {
            format(out, ".");
            format(out, digits[cut..end]);
        }
        return;
    }
    format(out, "0.");
    var z: i64 = 0;
    let zeros = -e - 1;
    while z < zeros {
        format(out, "0");
        z += 1;
    }
    var end = digits.len;
    while end > 1 && digits[end - 1] == '0' { end -= 1; }
    format(out, digits[0..end]);
}

fn write_fixed(out: u8[>..]&, x: f64, prec: i64, width: i64) {
    var v = x;
    var neg = false;
    if v < 0.0 {
        v = -v;
        neg = true;
    }
    var scale = 1.0;
    var p: i64 = 0;
    while p < prec {
        scale *= 10.0;
        p += 1;
    }
    let scaled = (v * scale + 0.5) as i64;
    let div = scale as i64;
    let whole = scaled / div;
    let frac = scaled % div;
    var text: u8[>..] = [];
    if neg && scaled != 0 { format(text, "-"); }
    format_int(text, whole, 10, 1, '0');
    format(text, ".");
    format_int(text, frac, 10, prec, '0');
    var gap = width - text.len;
    while gap > 0 {
        format(out, " ");
        gap -= 1;
    }
    format(out, text);
}

fn moments(xs: f64[:]) -> Stats, bool {
    let n = xs.len;
    if n <= 3 { return blank(), false; }
    var sum = 0.0;
    var i: i64 = 0;
    while i < n {
        sum += xs[i];
        i += 1;
    }
    let nf = n as f64;
    let mean = sum / nf;
    var m2 = 0.0;
    var m3 = 0.0;
    var m4 = 0.0;
    i = 0;
    while i < n {
        let d = xs[i] - mean;
        let d2 = d * d;
        m2 += d2;
        m3 += d2 * d;
        m4 += d2 * d2;
        i += 1;
    }
    let variance = m2 / (nf - 1.0);
    if !(variance > 0.0) { return blank(), false; }
    let dev = sqrt(variance);
    let e3 = m3 / nf;
    let e4 = m4 / nf;
    let skew = (e3 / (dev * dev * dev)) * (nf / (nf - 1.0)) * (nf / (nf - 2.0));
    let c1 = (nf / (nf - 1.0)) * (nf / (nf - 2.0)) * ((nf + 1.0) / (nf - 3.0));
    let c2 = 3.0 * ((nf - 1.0) / (nf - 2.0)) * ((nf - 1.0) / (nf - 3.0));
    let kurt = c1 * (e4 / (variance * variance)) - c2;
    return Stats { mean: mean, dev: dev, skew: skew, kurt: kurt, formula: 0.0 }, true;
}

fn simulate(rng: Mt&, steps: i64, paths: i64, spot0: f64, strike: f64, r: f64, sigma: f64, maturity: f64) -> Stats, bool {
    if steps <= 0 || paths <= 3 { return blank(), false; }
    var dw: f64[>..] = [];
    dw.resize(steps, 0.0);
    var samples: f64[>..] = [];
    samples.resize(paths, 0.0);
    var i: i64 = 0;
    while i < paths {
        var j: i64 = 0;
        while j < steps {
            let g, gok = next_gauss(rng);
            if !gok { return blank(), false; }
            dw[j] = g;
            j += 1;
        }
        let pl, pok = pnl(dw, spot0, strike, r, sigma, maturity);
        if !pok { return blank(), false; }
        samples[i] = pl;
        i += 1;
    }
    let st, ok = moments(samples);
    if !ok { return blank(), false; }
    let form, fok = kamal(steps, spot0, strike, r, sigma, maturity);
    if !fok { return blank(), false; }
    return Stats { mean: st.mean, dev: st.dev, skew: st.skew, kurt: st.kurt, formula: form }, true;
}

fn write_stats(paths: i64, steps: i64, st: Stats) {
    var line: u8[>..] = [];
    format_int(line, paths, 10, 8, ' ');
    format(line, " | ");
    format_int(line, steps, 10, 8, ' ');
    format(line, " | ");
    write_fixed(line, st.mean, 3, 8);
    format(line, " | ");
    write_fixed(line, st.dev, 2, 8);
    format(line, " | ");
    write_fixed(line, st.formula, 2, 12);
    format(line, " | ");
    write_fixed(line, st.skew, 2, 8);
    format(line, " | ");
    write_fixed(line, st.kurt, 2, 8);
    format(line, "\n");
    write_stdout(line);
}

fn stats_ok(st: Stats) -> bool {
    if !finite(st.mean) || !finite(st.dev) || !finite(st.skew) || !finite(st.kurt) || !finite(st.formula) {
        return false;
    }
    return st.dev > 0.0 && st.formula > 0.0;
}

fn show() -> f64, f64, f64, f64, bool {
    let maturity = 1.0 / 12.0;
    let strike = 100.0;
    let s0 = 100.0;
    let sigma = 0.20;
    let r = 0.05;
    let df = exp(-r * maturity);
    if df == 0.0 { return 0.0, 0.0, 0.0, 0.0, false; }
    let forward = s0 / df;
    let std = sqrt(sigma * sigma * maturity);
    let value, vok = black::black(black::CALL, strike, forward, std, df, 0.0);
    if !vok || !finite(value) { return 0.0, 0.0, 0.0, 0.0, false; }
    var line: u8[>..] = [];
    format(line, "\nOption value: ");
    g6(line, value);
    format(line, "\n\n");
    format(line, TOP);
    format(line, "\n");
    format(line, COLUMNS);
    format(line, "\n");
    var d: i64 = 0;
    while d < 78 {
        format(line, "-");
        d += 1;
    }
    format(line, "\n");
    write_stdout(line);

    var rng = fresh();
    open_rng(rng, 0);
    let a, aok = simulate(rng, 21, 50000, s0, strike, r, sigma, maturity);
    if !aok || !stats_ok(a) { return 0.0, 0.0, 0.0, 0.0, false; }
    write_stats(50000, 21, a);
    open_rng(rng, 0);
    let b, bok = simulate(rng, 84, 50000, s0, strike, r, sigma, maturity);
    if !bok || !stats_ok(b) { return 0.0, 0.0, 0.0, 0.0, false; }
    write_stats(50000, 84, b);
    return a.dev, a.formula, b.dev, b.formula, true;
}

fn fail_at(msg: u8[:], got: f64, want: f64) -> bool {
    var line: u8[>..] = [];
    format(line, msg);
    format(line, " ");
    format(line, got);
    format(line, " ");
    format(line, want);
    format(line, "\n");
    write_stdout(line);
    return false;
}

fn prove() -> bool {
    if TOP.len != 78 || COLUMNS.len != 78 {
        write_stdout("labels\n");
        return false;
    }
    if mt_word(5489, 0) != 3499211612 { write_stdout("mt0\n"); return false; }
    if mt_word(5489, 1) != 581869302 { write_stdout("mt1\n"); return false; }
    if mt_word(5489, 624) != 4178893912 { write_stdout("mt twist\n"); return false; }
    if mt_word(5489, 999) != 1341017984 { write_stdout("mt1000\n"); return false; }

    let t = 1.0 / 12.0;
    let r = 0.05;
    let s0 = 100.0;
    let strike = 100.0;
    let n: i64 = 4;
    let dt = t / (n as f64);
    let df = exp(-r * t);
    let forward = s0 / df;
    let prem = df * (forward - strike);
    var growth = 1.0;
    let accrue = exp(r * dt);
    var i: i64 = 0;
    while i < n {
        growth *= accrue;
        i += 1;
    }
    let want0 = (prem - s0) * growth + strike;
    var zeros: f64[4] = [0.0, 0.0, 0.0, 0.0];
    let got0, ok0 = pnl(zeros, s0, strike, r, 0.0, t);
    if !ok0 || !close_to(got0, want0, 1.0e-9) { return fail_at("zero vol", got0, want0); }

    let sigma = 0.20;
    let var_t = sigma * sigma * t;
    let std = sqrt(var_t);
    let d1 = log(forward / strike) / std + 0.5 * std;
    let delta = normal::cdf(d1) * df * forward / s0;
    let premium, pok = black::black(black::CALL, strike, forward, std, df, 0.0);
    if !pok { write_stdout("premium\n"); return false; }
    let drift = r * t - 0.5 * var_t;
    let stock = s0 * exp(drift + sqrt(var_t) * 1.0);
    var payoff = stock - strike;
    if payoff < 0.0 { payoff = 0.0; }
    let want1 = exp(r * t) * (premium - delta * s0) - payoff + delta * stock;
    var shock: f64[1] = [1.0];
    let got1, ok1 = pnl(shock, s0, strike, r, sigma, t);
    if !ok1 || !close_to(got1, want1, 1.0e-9) { return fail_at("one step", got1, want1); }

    let simple = s0 * normal::pdf(d1) * sqrt(t);
    let theor21 = sqrt(PI / 4.0 / 21.0) * simple * sigma;
    let theor84 = sqrt(PI / 4.0 / 84.0) * simple * sigma;
    let form21, f21 = kamal(21, s0, strike, r, sigma, t);
    let form84, f84 = kamal(84, s0, strike, r, sigma, t);
    if !f21 || !close_to(form21, theor21, 1.0e-6) { return fail_at("formula 21", form21, theor21); }
    if !f84 || !close_to(form84, theor84, 1.0e-6) { return fail_at("formula 84", form84, theor84); }
    return true;
}

