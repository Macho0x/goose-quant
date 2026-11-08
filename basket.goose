// Gaussian large-homogeneous-pool expected tranche loss, plus the
// BasketLosses one-factor Gaussian random-default and random-loss
// tranche means. West's bivariate normal and Acklam's inverse are in
// normal.goose. Flat hazards use Actual/365 Fixed, as the example's
// curves do. Both simulators draw Box-Muller normals from mt.goose,
// QuantLib's Mersenne Twister, which is the example's random-default
// generator. The example's random-loss generator is Sobol; the package
// Sobol is one-dimensional, so random loss draws the same Gaussian
// factors from the twister. A full tranche (attachment 0, detachment 1)
// has mean notional * (1 - recovery) * average default probability.
// The Gaussian binomial is the Poisson-binomial tranche of the conditional
// defaults, integrated over the factor. Inhomogeneous, Student-t, and base
// correlation stay out.

import math;
import normal;
import gauss;
import mt;
import date;
import period;
import daycount;
import calendar;
import markets;

namespace basket;

// Abramowitz and Stegun nodes, the positive half QuantLib tabulates.
// Orders 6, 12, and 20 are the ones West's routine selects.
const X6: f64[3] = [0.238619186083197, 0.661209386466265, 0.932469514203152];
const W6: f64[3] = [0.467913934572691, 0.360761573048139, 0.171324492379170];
const X12: f64[6] = [
    0.125233408511469, 0.367831498998180, 0.587317954286617,
    0.769902674194305, 0.904117256370475, 0.981560634246719,
];
const W12: f64[6] = [
    0.249147045813403, 0.233492536538355, 0.203167426723066,
    0.160078328543346, 0.106939325995318, 0.047175336386512,
];
const X20: f64[10] = [
    0.076526521133497, 0.227785851141645, 0.373706088715420,
    0.510867001950827, 0.636053680726515, 0.746331906460151,
    0.839116971822219, 0.912234428251326, 0.963971927277914,
    0.993128599185095,
];
const W20: f64[10] = [
    0.152753387130726, 0.149172986472604, 0.142096109318382,
    0.131688638449177, 0.118194531961518, 0.101930119817240,
    0.083276741576704, 0.062672048334109, 0.040601429800387,
    0.017614007139152,
];

const EPS: f64 = 2.2204460492503131e-16;
const ONE: f64 = 1.0 - 1.0e-12;

fn bad(x: f64) -> bool { is_nan(x) || is_inf(x) }

fn nodes<F>(x: f64[:], w: f64[:]) -> f64 {
    var sum = 0.0;
    var i: i64 = 0;
    while i < x.len {
        sum += w[i] * F(x[i]);
        sum += w[i] * F(-x[i]);
        i += 1;
    }
    return sum;
}

fn legendre<F>(order: i64) -> f64 {
    if order == 6 { return nodes(X6, W6, F); }
    if order == 12 { return nodes(X12, W12, F); }
    return nodes(X20, W20, F);
}

// BivariateCumulativeNormalDistributionWe04DP. rho is the correlation.
fn biv_cdf(rho: f64, x: f64, y: f64) -> f64 {
    var order: i64 = 20;
    if abs(rho) < 0.3 {
        order = 6;
    } else if abs(rho) < 0.75 {
        order = 12;
    }
    var h = -x;
    var k = -y;
    var hk = h * k;
    var bvn = 0.0;
    if abs(rho) < 0.925 {
        if abs(rho) > 0.0 {
            let asr = asin(rho);
            let hs = (h * h + k * k) / 2.0;
            bvn = legendre(order) {
                let sn = sin(asr * (-it + 1.0) * 0.5);
                exp((sn * hk - hs) / (1.0 - sn * sn))
            };
            bvn *= asr * (0.25 / PI);
        }
        bvn += normal::cdf(-h) * normal::cdf(-k);
        return bvn;
    }
    if rho < 0.0 {
        k = -k;
        hk = -hk;
    }
    if abs(rho) < 1.0 {
        let complement = (1.0 - rho) * (1.0 + rho);
        var a = sqrt(complement);
        let bs = (h - k) * (h - k);
        let c = (4.0 - hk) / 8.0;
        let d = (12.0 - hk) / 16.0;
        let series = -(bs / complement + hk) / 2.0;
        if series > -100.0 {
            bvn = a * exp(series) * (1.0 - c * (bs - complement) * (1.0 - d * bs / 5.0) / 3.0 + c * d * complement * complement / 5.0);
        }
        if -hk < 100.0 {
            let big = sqrt(bs);
            bvn -= exp(-hk / 2.0) * 2.506628274631 * normal::cdf(-big / a) * big * (1.0 - c * bs * (1.0 - d * bs / 5.0) / 3.0);
        }
        a = a / 2.0;
        bvn += legendre(20) {
            let span = a * (-it + 1.0);
            let xs = abs(span * span);
            let rs = sqrt(1.0 - xs);
            let tail = -(bs / xs + hk) / 2.0;
            if tail > -100.0 {
                a * exp(tail) * (exp(-hk * (1.0 - rs) / (2.0 * (1.0 + rs))) / rs - (1.0 + c * xs * (1.0 + d * xs)))
            } else {
                0.0
            }
        };
        bvn = bvn / (-2.0 * PI);
    }
    if rho > 0.0 {
        var peak = h;
        if k > peak { peak = k; }
        bvn += normal::cdf(-peak);
    } else {
        bvn = -bvn;
        if k > h {
            if h >= 0.0 {
                bvn += normal::cdf(-h) - normal::cdf(-k);
            } else {
                bvn += normal::cdf(k) - normal::cdf(h);
            }
        }
    }
    return bvn;
}

// Closed form. notional is the live pool. probability is the notional-weighted
// average default probability. attach and detach are fractions of that notional.
// correlation is the one-factor asset correlation, in (0, 1].
fn expected_tranche_loss(notional: f64, probability: f64, recovery: f64, attach: f64, detach: f64, correlation: f64) -> f64, bool {
    if bad(notional) || bad(probability) || bad(recovery) || bad(attach) || bad(detach) || bad(correlation) {
        return 0.0, false;
    }
    if notional < 0.0 || probability < 0.0 || probability > 1.0 { return 0.0, false; }
    if recovery < 0.0 || recovery >= 1.0 { return 0.0, false; }
    if correlation <= 0.0 || correlation > 1.0 { return 0.0, false; }
    if attach >= detach { return 0.0, true; }
    if notional == 0.0 || probability == 0.0 { return 0.0, true; }

    let loss_given = 1.0 - recovery;
    var k1 = attach / loss_given;
    if k1 > ONE { k1 = ONE; }
    k1 += EPS;
    var k2 = detach / loss_given;
    if k2 > ONE { k2 = ONE; }
    k2 += EPS;

    let ip, iok = normal::inv_cdf(probability);
    let z1, z1ok = normal::inv_cdf(k1);
    let z2, z2ok = normal::inv_cdf(k2);
    if !iok || !z1ok || !z2ok { return 0.0, false; }

    let beta = sqrt(correlation);
    let width = sqrt(1.0 - correlation);
    let d1 = (ip - width * z1) / beta;
    let d2 = (ip - width * z2) / beta;
    let upper = biv_cdf(-beta, ip, -d2);
    let lower = biv_cdf(-beta, ip, -d1);
    let loss = notional * (detach * normal::cdf(d2) - attach * normal::cdf(d1) + loss_given * (upper - lower));
    if bad(loss) { return 0.0, false; }
    return loss, true;
}

// Notional-weighted mean of 1 - exp(-hazard * horizon). Flat hazard, continuous.
fn average_probability(notionals: f64[:], hazards: f64[:], horizon: f64) -> f64, bool {
    if bad(horizon) || horizon < 0.0 || notionals.len == 0 || notionals.len != hazards.len {
        return 0.0, false;
    }
    var notional = 0.0;
    var acc = 0.0;
    var i: i64 = 0;
    while i < notionals.len {
        if bad(notionals[i]) || bad(hazards[i]) || notionals[i] < 0.0 || hazards[i] < 0.0 {
            return 0.0, false;
        }
        let p = 1.0 - exp(-hazards[i] * horizon);
        acc += notionals[i] * p;
        notional += notionals[i];
        i += 1;
    }
    if notional == 0.0 { return 0.0, true; }
    return acc / notional, true;
}

// 19 March 2014, TARGET Following, plus 60 months. Actual/365 Fixed.
fn example_horizon() -> f64, bool {
    let raw, ok = date::from_ymd(19, date::MARCH, 2014);
    if !ok { return 0.0, false; }
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    let today, tok = calendar::adjust(markets::TARGET, raw, calendar::FOLLOWING, empty, empty);
    if !tok { return 0.0, false; }
    let calc, cok = calendar::advance(markets::TARGET, today, 60, period::MONTHS, calendar::FOLLOWING, false, empty, empty);
    if !cok { return 0.0, false; }
    return daycount::year_fraction(daycount::actual365_fixed(), today, calc, date::blank(), date::blank());
}

// BasketLosses GLHP line. Ten names at 100, recovery 0.4, correlation 0.05,
// attachment 0.03, detachment 0.06, flat hazards, five-year horizon.
fn five_year_loss() -> f64, bool {
    let horizon, hok = example_horizon();
    if !hok { return 0.0, false; }
    let notionals: f64[10] = [100.0; 10];
    let hazards: f64[10] = [0.001, 0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09];
    let probability, pok = average_probability(notionals, hazards, horizon);
    if !pok { return 0.0, false; }
    return expected_tranche_loss(10.0 * 100.0, probability, 0.4, 0.03, 0.06, 0.05);
}

// BasketLosses numSimulations and the Mersenne Twister seed in that file.
const SIMULATIONS: i64 = 100000;
const RANDOM_SEED: u32 = 2863311530;
// GaussianSpotLossLM modelA in BasketLosses.
const SPOT_A: f64 = 2.2;
// ponytail: 64 names. A growable scratch array if a basket is wider.
const NAME_CAP: i64 = 64;

struct GaussGen {
    gen: mt::Twister,
    hold: bool,
    spare: f64,
}

fn next_normal(g: GaussGen&) -> f64 {
    if g.hold {
        g.hold = false;
        return g.spare;
    }
    var draw = 0.0;
    var found = false;
    while !found {
        let u = mt::next_real(g.gen);
        let v = mt::next_real(g.gen);
        let x = u * 2.0 - 1.0;
        let y = v * 2.0 - 1.0;
        let r = x * x + y * y;
        if r < 1.0 && r > 0.0 {
            let scale = sqrt(-2.0 * log(r) / r);
            g.spare = y * scale;
            g.hold = true;
            draw = x * scale;
            found = true;
        }
    }
    return draw;
}

fn clamp_tranche(loss: f64, attach_amt: f64, detach_amt: f64) -> f64 {
    var x = loss - attach_amt;
    if x < 0.0 { x = 0.0; }
    let width = detach_amt - attach_amt;
    if x > width { x = width; }
    return x;
}

// QuantLib simEvent recovery, quantized to 1/256. pdef is the flat-curve
// probability at the default time, which is the Gaussian draw.
fn spot_recovery(latent: f64, pdef: f64, inv_r: f64, root_cross: f64, denom: f64, scale_r: f64) -> f64 {
    if pdef < 1.0e-10 { return 0.0; }
    var inv_p = 0.0;
    if root_cross > 0.0 {
        var p = pdef;
        if p > 1.0 - 1.0e-12 { p = 1.0 - 1.0e-12; }
        let iv, ok = normal::inv_cdf(p);
        if !ok { return 0.0; }
        inv_p = iv;
    }
    let z = (latent - root_cross * inv_p) / denom + scale_r * inv_r;
    var grains = floor(normal::cdf(z) * 256.0 + 0.5);
    if grains < 0.0 { grains = 0.0; }
    if grains > 256.0 { grains = 256.0; }
    return grains / 256.0;
}

// spot is false for deterministic recovery (random default) and true for
// the spot-recovery latent model (random loss). correlation is the
// one-factor asset correlation in [0, 1). Returns the tranche-loss mean
// and its sample standard error.
fn gaussian_tranche(notionals: f64[:], hazards: f64[:], horizon: f64, recovery: f64, attach: f64, detach: f64, correlation: f64, sims: i64, seed: u32, spot: bool, model_a: f64) -> f64, f64, bool {
    if bad(horizon) || horizon < 0.0 || notionals.len == 0 || notionals.len != hazards.len { return 0.0, 0.0, false; }
    if notionals.len > NAME_CAP { return 0.0, 0.0, false; }
    if bad(recovery) || recovery < 0.0 || recovery >= 1.0 { return 0.0, 0.0, false; }
    if bad(attach) || bad(detach) || attach < 0.0 || detach > 1.0 || attach > detach { return 0.0, 0.0, false; }
    if bad(correlation) || correlation < 0.0 || correlation >= 1.0 { return 0.0, 0.0, false; }
    if sims < 2 || seed == 0 { return 0.0, 0.0, false; }
    if spot && (bad(model_a) || model_a <= 0.0) { return 0.0, 0.0, false; }

    var pd: f64[64] = [0.0; 64];
    var total = 0.0;
    var i: i64 = 0;
    while i < notionals.len {
        if bad(notionals[i]) || bad(hazards[i]) || notionals[i] < 0.0 || hazards[i] < 0.0 { return 0.0, 0.0, false; }
        pd[i] = 1.0 - exp(-hazards[i] * horizon);
        total += notionals[i];
        i += 1;
    }
    if attach == detach || total == 0.0 { return 0.0, 0.0, true; }

    var inv_r = 0.0;
    var root_cross = 0.0;
    var denom = 1.0;
    var scale_r = 0.0;
    if spot {
        let iv, iok = normal::inv_cdf(recovery);
        if !iok { return 0.0, 0.0, false; }
        inv_r = iv;
        let cross = correlation * correlation;
        root_cross = sqrt(cross);
        denom = model_a * sqrt(1.0 - cross);
        if denom == 0.0 || bad(denom) { return 0.0, 0.0, false; }
        scale_r = sqrt(1.0 + 1.0 / (model_a * model_a));
    }

    let weight = sqrt(correlation);
    let idio = sqrt(1.0 - correlation);
    let attach_amt = total * attach;
    let detach_amt = total * detach;
    let lgd = 1.0 - recovery;
    var g = default<GaussGen>();
    mt::seed(g.gen, seed);
    var mark: f64[64] = [-1.0; 64];

    var mean = 0.0;
    var m2 = 0.0;
    var seen: i64 = 0;
    while seen < sims {
        let mkt = next_normal(g);
        var loss = 0.0;
        if !spot {
            i = 0;
            while i < notionals.len {
                let z = next_normal(g);
                let y = weight * mkt + idio * z;
                // ponytail: Phi(Y) against the horizon probability. QuantLib
                // inverts a default day and uses a strict serial compare, one
                // Actual/365 day shorter. Flat curves keep that inside the
                // Monte Carlo error of the full-tranche identity.
                if normal::cdf(y) <= pd[i] { loss += notionals[i] * lgd; }
                i += 1;
            }
        } else {
            i = 0;
            while i < notionals.len {
                let z = next_normal(g);
                let y = weight * mkt + idio * z;
                let u = normal::cdf(y);
                if u <= pd[i] { mark[i] = u; } else { mark[i] = -1.0; }
                i += 1;
            }
            i = 0;
            while i < notionals.len {
                let z = next_normal(g);
                if mark[i] >= 0.0 {
                    let y = weight * mkt + idio * z;
                    let rr = spot_recovery(y, mark[i], inv_r, root_cross, denom, scale_r);
                    loss += notionals[i] * (1.0 - rr);
                }
                i += 1;
            }
        }
        let x = clamp_tranche(loss, attach_amt, detach_amt);
        seen += 1;
        let delta = x - mean;
        mean += delta / seen;
        m2 += delta * (x - mean);
    }
    if m2 < 0.0 { m2 = 0.0; }
    let se = sqrt((m2 / (sims - 1.0)) / sims);
    if bad(mean) || bad(se) { return 0.0, 0.0, false; }
    return mean, se, true;
}

// Probability of k defaults when the names are independent. Updating from
// the top keeps the previous count's mass intact.
fn cond_tranche(p: f64[:], n: i64, loss_each: f64, attach_amt: f64, detach_amt: f64) -> f64 {
    var dp: f64[65] = [0.0; 65];
    dp[0] = 1.0;
    var count: i64 = 0;
    var i: i64 = 0;
    var k: i64 = 0;
    while i < n {
        var pi = p[i];
        if pi < 0.0 { pi = 0.0; }
        if pi > 1.0 { pi = 1.0; }
        let qi = 1.0 - pi;
        k = count;
        while k >= 0 {
            dp[k + 1] = dp[k + 1] + dp[k] * pi;
            dp[k] = dp[k] * qi;
            k -= 1;
        }
        count += 1;
        i += 1;
    }
    var sum = 0.0;
    k = 0;
    while k <= count {
        sum += dp[k] * clamp_tranche(k * loss_each, attach_amt, detach_amt);
        k += 1;
    }
    return sum;
}

// One-factor Gaussian copula, constant recovery. Conditional on the factor,
// names default independently and the tranche is the Poisson-binomial
// expectation. Equal notionals share one loss amount, so the count recursion
// is exact. gauss::integrate is order 15.
// ponytail: equal loss per name, order 15. A subset convolution if notionals
// differ, and a higher order if a loading near 1 misses 1e-6.
fn gaussian_binomial_tranche(notionals: f64[:], hazards: f64[:], horizon: f64, recovery: f64, attach: f64, detach: f64, correlation: f64) -> f64, bool {
    if bad(horizon) || horizon < 0.0 || notionals.len == 0 || notionals.len != hazards.len { return 0.0, false; }
    if notionals.len > NAME_CAP { return 0.0, false; }
    if bad(recovery) || recovery < 0.0 || recovery >= 1.0 { return 0.0, false; }
    if bad(attach) || bad(detach) || attach < 0.0 || detach > 1.0 || attach > detach { return 0.0, false; }
    if bad(correlation) || correlation < 0.0 || correlation >= 1.0 { return 0.0, false; }

    let n = notionals.len;
    var pd: f64[64] = [0.0; 64];
    var total = 0.0;
    var i: i64 = 0;
    while i < n {
        if bad(notionals[i]) || bad(hazards[i]) || notionals[i] < 0.0 || hazards[i] < 0.0 { return 0.0, false; }
        if notionals[i] != notionals[0] { return 0.0, false; }
        pd[i] = 1.0 - exp(-hazards[i] * horizon);
        total += notionals[i];
        i += 1;
    }
    if attach == detach || total == 0.0 { return 0.0, true; }

    let loss_each = notionals[0] * (1.0 - recovery);
    let attach_amt = total * attach;
    let detach_amt = total * detach;
    if correlation == 0.0 {
        let loss = cond_tranche(pd, n, loss_each, attach_amt, detach_amt);
        if bad(loss) { return 0.0, false; }
        return loss, true;
    }

    var inv: f64[64] = [0.0; 64];
    i = 0;
    while i < n {
        if pd[i] >= 1.0e-10 {
            let iv, iok = normal::inv_cdf(pd[i]);
            if !iok { return 0.0, false; }
            inv[i] = iv;
        }
        i += 1;
    }
    let weight = sqrt(correlation);
    let idio = sqrt(1.0 - correlation);
    let got = gauss::integrate() {
        let mkt = it * sqrt(2.0);
        var cp: f64[64] = [0.0; 64];
        var k: i64 = 0;
        while k < n {
            if pd[k] < 1.0e-10 {
                cp[k] = 0.0;
            } else {
                cp[k] = normal::cdf((inv[k] - weight * mkt) / idio);
            }
            k += 1;
        }
        exp(-it * it) * cond_tranche(cp, n, loss_each, attach_amt, detach_amt) / sqrt(PI)
    };
    if bad(got) { return 0.0, false; }
    return got, true;
}

fn random_default_tranche(notionals: f64[:], hazards: f64[:], horizon: f64, recovery: f64, attach: f64, detach: f64, correlation: f64, sims: i64, seed: u32) -> f64, f64, bool {
    return gaussian_tranche(notionals, hazards, horizon, recovery, attach, detach, correlation, sims, seed, false, 0.0);
}

fn random_loss_tranche(notionals: f64[:], hazards: f64[:], horizon: f64, recovery: f64, attach: f64, detach: f64, correlation: f64, sims: i64, seed: u32, model_a: f64) -> f64, f64, bool {
    return gaussian_tranche(notionals, hazards, horizon, recovery, attach, detach, correlation, sims, seed, true, model_a);
}
