// Gaussian large-homogeneous-pool expected tranche loss.
// QuantLib GaussianLHPLossModel::expectedTrancheLossImpl, with West's
// bivariate normal (the library's default) and Acklam's inverse already
// in normal.goose. Flat hazards use Actual/365 Fixed, as the example's
// curves do. The example's random-default and random-loss sections are
// not in this file.

import math;
import normal;
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
