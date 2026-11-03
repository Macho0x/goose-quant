// One-step European put from MakeMCEuropeanEngine<LowDiscrepancy>.
// Each path is one Sobol uniform through Acklam's inverse normal,
// then the exact Black-Scholes step. The price is the mean payoff.

import math;
import normal;
import sobol;

namespace qmc;

fn european_put(spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, samples: i64) -> f64, bool {
    if spot <= 0.0 || strike < 0.0 || vol < 0.0 || t <= 0.0 || samples < 1 { return 0.0, false; }
    let variance = vol * vol * t;
    let drift = (r - q) * t - 0.5 * variance;
    let sig = sqrt(variance);
    let df = exp(-r * t);
    var g = sobol::open();
    var sum = 0.0;
    var i: i64 = 0;
    while i < samples {
        let z, ok = normal::inv_cdf(sobol::next_uniform(g));
        if !ok { return 0.0, false; }
        let terminal = spot * exp(sig * z + drift);
        var payoff = strike - terminal;
        if payoff < 0.0 { payoff = 0.0; }
        sum += payoff * df;
        i += 1;
    }
    return sum / samples, true;
}
