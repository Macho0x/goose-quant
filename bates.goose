// BatesEngine: Gatheral's characteristic function plus a lognormal jump.
// EquityOption uses Gauss-Laguerre of order 144, the BatesEngine default.

import heston;

namespace bates;

fn npv(option: i32, spot: f64, strike: f64, r: f64, q: f64, v0: f64, kappa: f64, theta: f64, sigma: f64, rho: f64, lam: f64, nu: f64, delta: f64, t: f64) -> f64, bool {
    return heston::gatheral(option, spot, strike, r, q, v0, kappa, theta, sigma, rho, lam, nu, delta, t);
}
