// One-factor latent model from QuantLib's LatentModel example.
// Three names, notional 100, flat hazard -ln(0.99), factor weight
// sqrt(0.1). The sample's recovery does not enter.
//
// Conditional default probability is the Gaussian copula
//   Phi((Phi^{-1}(p) - w*M) / sqrt(1-w*w)).
// Expected loss is notional times the unconditional default probability.
// prob_at_least integrates the conditional binomial of that probability,
// the example's direct integration. gauss::integrate is physicist
// Gauss-Hermite with the exp(-y*y) weight divided out of the nodes. A
// normal expectation puts that weight back:
// integrand exp(-y*y) * g(sqrt(2)*y) / sqrt(pi).
// ponytail: order 15. Raise it if a factor loading near 1 gets steep.
//
// The Student-t section is the example's T_3 copula: one systemic factor
// and one idiosyncratic factor, each Student-t with 3 degrees of freedom,
// divided by sqrt(nu/(nu-2)) so the variance is 1. The normalized density
// is 2/(pi (1+m*m)^2). m = tan(pi*u/2) turns an expectation into the
// integral of g(m(u)) cos^2(pi*u/2) on [-1, 1].
// ponytail: 4096 Simpson panels. Raise it if a loading near 1 gets steep.
//
// mc_at_least samples those factors with mt. A name defaults when
// Y = w*M + sqrt(1-w*w)*Z is at most the marginal quantile. probs[n]
// is that frequency and errs[n] is sqrt(p*(1-p)/paths).

import math;
import mt;
import normal;
import gauss;
import solver;
import date;
import period;
import calendar;
import markets;
import daycount;
import schedule;

namespace latent;

const NOTIONAL: f64 = 100.0;
const NAMES: i64 = 3;
const T_PANELS: i64 = 4096;

fn hazard_rate() -> f64 {
    return -log(1.0 - 0.01);
}

fn factor_weight() -> f64 {
    return sqrt(0.1);
}

fn horizon() -> f64, bool {
    let raw, ok = date::from_ymd(19, date::MARCH, 2014);
    if !ok { return 0.0, false; }
    let today, tok = schedule::adjusted(markets::TARGET, raw, calendar::FOLLOWING);
    if !tok { return 0.0, false; }
    let calc, cok = calendar::advance_span(markets::TARGET, today, period::months(120), calendar::FOLLOWING, false);
    if !cok { return 0.0, false; }
    return daycount::year_fraction(daycount::actual365_fixed(), today, calc, date::blank(), date::blank());
}

fn default_probability(t: f64) -> f64, bool {
    if t < 0.0 { return 0.0, false; }
    return 1.0 - exp(-hazard_rate() * t), true;
}

fn conditional_default(pd: f64, weight: f64, factor: f64) -> f64, bool {
    if pd < 0.0 || pd > 1.0 { return 0.0, false; }
    if pd < 1.0e-10 { return 0.0, true; }
    if 1.0 - pd < 1.0e-10 { return 1.0, true; }
    let w2 = weight * weight;
    if w2 > 1.0 { return 0.0, false; }
    let inv, ok = normal::inv_cdf(pd);
    if !ok { return 0.0, false; }
    if w2 >= 1.0 {
        if weight * factor < inv { return 1.0, true; }
        return 0.0, true;
    }
    if w2 == 0.0 { return pd, true; }
    return normal::cdf((inv - weight * factor) / sqrt(1.0 - w2)), true;
}

fn joint_survival(pd: f64[:], weight: f64) -> f64, bool {
    if pd.len == 0 { return 0.0, false; }
    var i: i64 = 0;
    while i < pd.len {
        if pd[i] < 0.0 || pd[i] > 1.0 { return 0.0, false; }
        i += 1;
    }
    let w2 = weight * weight;
    if w2 > 1.0 { return 0.0, false; }
    if w2 == 0.0 {
        var prod = 1.0;
        i = 0;
        while i < pd.len {
            prod *= 1.0 - pd[i];
            i += 1;
        }
        return prod, true;
    }
    if w2 >= 1.0 {
        var worst = pd[0];
        i = 1;
        while i < pd.len {
            if pd[i] > worst { worst = pd[i]; }
            i += 1;
        }
        return 1.0 - worst, true;
    }
    let alive = gauss::integrate() {
        let mkt = it * sqrt(2.0);
        var live = 1.0;
        var k: i64 = 0;
        while k < pd.len {
            let c, cok = conditional_default(pd[k], weight, mkt);
            if cok { live *= 1.0 - c; }
            k += 1;
        }
        exp(-it * it) * live / sqrt(PI)
    };
    return alive, true;
}

fn integrated_default(pd: f64, weight: f64) -> f64, bool {
    if pd < 0.0 || pd > 1.0 { return 0.0, false; }
    let w2 = weight * weight;
    if w2 > 1.0 { return 0.0, false; }
    if w2 == 0.0 || w2 >= 1.0 || pd < 1.0e-10 || 1.0 - pd < 1.0e-10 { return pd, true; }
    let inv, ok = normal::inv_cdf(pd);
    if !ok { return 0.0, false; }
    let idio = sqrt(1.0 - w2);
    let got = gauss::integrate() {
        exp(-it * it) * normal::cdf((inv - weight * it * sqrt(2.0)) / idio) / sqrt(PI)
    };
    return got, true;
}

fn expected_loss(notional: f64, t: f64, names: i64) -> f64, bool {
    if names <= 0 || notional < 0.0 { return 0.0, false; }
    let pd, ok = default_probability(t);
    if !ok { return 0.0, false; }
    return names * notional * pd, true;
}

fn binom_at_least(need: i64, names: i64, p: f64) -> f64 {
    if need <= 0 { return 1.0; }
    if need > names || p <= 0.0 { return 0.0; }
    if p >= 1.0 { return 1.0; }
    let q = 1.0 - p;
    var sum = 0.0;
    var choose = 1.0;
    var k: i64 = 0;
    while k <= names {
        if k >= need {
            var pk = 1.0;
            var qk = 1.0;
            var i: i64 = 0;
            while i < k {
                pk *= p;
                i += 1;
            }
            while i < names {
                qk *= q;
                i += 1;
            }
            sum += choose * pk * qk;
        }
        choose = choose * (names - k) / (k + 1);
        k += 1;
    }
    return sum;
}

fn prob_at_least(n: i64, pd: f64, weight: f64, names: i64) -> f64, bool {
    if names <= 0 || n < 0 { return 0.0, false; }
    if pd < 0.0 || pd > 1.0 { return 0.0, false; }
    let w2 = weight * weight;
    if w2 > 1.0 { return 0.0, false; }
    if n == 0 { return 1.0, true; }
    if n > names { return 0.0, true; }
    if pd == 0.0 { return 0.0, true; }
    if pd == 1.0 { return 1.0, true; }
    if w2 >= 1.0 { return pd, true; }
    let got = gauss::integrate() {
        let mkt = it * sqrt(2.0);
        let c, cok = conditional_default(pd, weight, mkt);
        var tail = 0.0;
        if cok { tail = binom_at_least(n, names, c); }
        exp(-it * it) * tail / sqrt(PI)
    };
    return got, true;
}

fn t3_z_cdf(z: f64) -> f64 {
    let a = atan(z);
    let q = z / (1.0 + z * z);
    return 0.5 + (a + q) / PI;
}

fn t3_mean<F>() -> f64 {
    let h = 2.0 / (T_PANELS as f64);
    var sum = 0.0;
    var i: i64 = 0;
    while i <= T_PANELS {
        var y = 0.0;
        if i > 0 && i < T_PANELS {
            let u = -1.0 + (i as f64) * h;
            let ang = u * (PI * 0.5);
            let c = cos(ang);
            y = F(tan(ang)) * c * c;
        }
        var coef = 2.0;
        if i == 0 || i == T_PANELS {
            coef = 1.0;
        } else if (i % 2) == 1 {
            coef = 4.0;
        }
        sum += coef * y;
        i += 1;
    }
    return sum * h / 3.0;
}

fn t3_cdf_y(y: f64, weight: f64) -> f64 {
    let s = sqrt(1.0 - weight * weight);
    return t3_mean() { t3_z_cdf((y - weight * it) / s) };
}

fn t3_quantile(pd: f64, weight: f64) -> f64, bool {
    if pd <= 0.0 || pd >= 1.0 { return 0.0, false; }
    let w2 = weight * weight;
    if w2 >= 1.0 { return 0.0, false; }
    if w2 == 0.0 {
        return solver::brent(0.0, -80.0, 80.0, 1.0e-14, 100) {
            t3_z_cdf(it) - pd
        };
    }
    return solver::brent(0.0, -80.0, 80.0, 1.0e-12, 80) {
        t3_cdf_y(it, weight) - pd
    };
}

fn prob_at_least_t(n: i64, pd: f64, weight: f64, names: i64) -> f64, bool {
    if names <= 0 || n < 0 { return 0.0, false; }
    if pd < 0.0 || pd > 1.0 { return 0.0, false; }
    let w2 = weight * weight;
    if w2 > 1.0 { return 0.0, false; }
    if n == 0 { return 1.0, true; }
    if n > names { return 0.0, true; }
    if pd == 0.0 { return 0.0, true; }
    if pd == 1.0 { return 1.0, true; }
    if w2 >= 1.0 { return pd, true; }
    let y, yok = t3_quantile(pd, weight);
    if !yok { return 0.0, false; }
    let s = sqrt(1.0 - w2);
    let got = t3_mean() {
        let c = t3_z_cdf((y - weight * it) / s);
        binom_at_least(n, names, c)
    };
    return got, true;
}

const MC_PATHS: i64 = 100000;
const MC_SEED: u32 = 2863311530;

fn draw_normal(g: mt::Twister &) -> f64, bool {
    return normal::inv_cdf(mt::next_real(g));
}

// Unit-variance Student-t with 3 degrees of freedom. The raw t has
// variance 3, so the divisor is the chi-square itself rather than chi-square/3.
fn draw_t3(g: mt::Twister &) -> f64, bool {
    let z, zok = draw_normal(g);
    if !zok { return 0.0, false; }
    var acc = 0.0;
    var i: i64 = 0;
    while i < 3 {
        let e, eok = draw_normal(g);
        if !eok { return 0.0, false; }
        acc += e * e;
        i += 1;
    }
    if acc == 0.0 { return 0.0, false; }
    return z / sqrt(acc), true;
}

// RandomDefaultLM. probs[n] is the fraction of paths with at least n defaults.
// ponytail: histogram of 8 counts. A growable tally if a basket is wider than 7.
fn mc_at_least(pd: f64, weight: f64, names: i64, student: bool, seed: u32, paths: i64, probs: f64[>..] &, errs: f64[>..] &) -> bool {
    if names <= 0 || names > 7 || paths < 2 { return false; }
    if pd < 0.0 || pd > 1.0 { return false; }
    let w2 = weight * weight;
    if w2 > 1.0 || seed == 0 { return false; }
    var threshold = 0.0;
    if pd > 0.0 && pd < 1.0 && w2 < 1.0 {
        if student {
            let y, yok = t3_quantile(pd, weight);
            if !yok { return false; }
            threshold = y;
        } else {
            let y, yok = normal::inv_cdf(pd);
            if !yok { return false; }
            threshold = y;
        }
    }
    let scale = sqrt(1.0 - w2);
    var hist: i64[8] = [0, 0, 0, 0, 0, 0, 0, 0];
    var g = default<mt::Twister>();
    mt::seed(g, seed);
    var path: i64 = 0;
    while path < paths {
        var factor = 0.0;
        if w2 > 0.0 {
            var fok = false;
            if student {
                let draw, dok = draw_t3(g);
                factor = draw;
                fok = dok;
            } else {
                let draw, dok = draw_normal(g);
                factor = draw;
                fok = dok;
            }
            if !fok { return false; }
        }
        var hits: i64 = 0;
        var name: i64 = 0;
        while name < names {
            var shock = 0.0;
            var sok = true;
            if w2 < 1.0 {
                if student {
                    let draw, dok = draw_t3(g);
                    shock = draw;
                    sok = dok;
                } else {
                    let draw, dok = draw_normal(g);
                    shock = draw;
                    sok = dok;
                }
            }
            if !sok { return false; }
            let asset = weight * factor + scale * shock;
            if pd >= 1.0 || (pd > 0.0 && asset <= threshold) { hits += 1; }
            name += 1;
        }
        hist[hits] += 1;
        path += 1;
    }
    probs.clear();
    errs.clear();
    var n: i64 = 0;
    while n <= names {
        var tail: i64 = 0;
        var k = n;
        while k <= names {
            tail += hist[k];
            k += 1;
        }
        let p = tail * 1.0 / paths;
        var v = p * (1.0 - p) / paths;
        if v < 0.0 { v = 0.0; }
        probs.push(p);
        errs.push(sqrt(v));
        n += 1;
    }
    return true;
}
