// One-factor Gaussian latent model, the integrable half of QuantLib's
// LatentModel example. Three names, notional 100, flat hazard -ln(0.99),
// factor weight sqrt(0.1). The sample's recovery does not enter.
//
// Conditional default probability is the Gaussian copula
//   Phi((Phi^{-1}(p) - w*M) / sqrt(1-w*w)).
// Expected loss is notional times the unconditional default probability.
// gauss::integrate is physicist Gauss-Hermite with the exp(-y*y) weight
// divided out of the nodes. A normal expectation puts that weight back:
// integrand exp(-y*y) * g(sqrt(2)*y) / sqrt(pi).
// ponytail: order 15. Raise it if a factor loading near 1 gets steep.

import math;
import normal;
import gauss;

namespace latent;

const NOTIONAL: f64 = 100.0;
const NAMES: i64 = 3;

fn hazard_rate() -> f64 {
    return -log(1.0 - 0.01);
}

fn factor_weight() -> f64 {
    return sqrt(0.1);
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
