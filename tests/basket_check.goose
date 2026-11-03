import os;
import math;
import quant from "..";
import quant.basket;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn show_fail(msg: u8[:], got: f64, want: f64, se: f64) {
    var line: u8[>..] = [];
    format(line, msg);
    format(line, " ");
    format(line, got);
    format(line, " ");
    format(line, want);
    format(line, " ");
    format(line, se);
    fail(line);
}

fn gap(a: f64, b: f64) -> f64 {
    var d = a - b;
    if d < 0.0 { d = -d; }
    return d;
}

fn ::main() {
    // The tranche from 0 to 1-R covers every loss the pool can produce.
    // A Gaussian copula keeps the marginal default probability, so the
    // expected loss is notional * (1 - recovery) * probability at every
    // correlation in (0, 1). The formula caps the strike at 1-1e-12, which
    // leaves a few billionths, so the check is 1e-8.
    let notional = 1000.0;
    let recovery = 0.4;
    let probability = 0.25;
    let want = notional * (1.0 - recovery) * probability;
    let low, lok = basket::expected_tranche_loss(notional, probability, recovery, 0.0, 1.0 - recovery, 0.05);
    let mid, mok = basket::expected_tranche_loss(notional, probability, recovery, 0.0, 1.0 - recovery, 0.25);
    let high, hok = basket::expected_tranche_loss(notional, probability, recovery, 0.0, 1.0 - recovery, 0.9);
    if !lok || !mok || !hok { fail("identity"); }
    if gap(low, want) > 1.0e-8 || gap(mid, want) > 1.0e-8 || gap(high, want) > 1.0e-8 { fail("identity"); }

    // BasketLosses inputs: notionals 100, those hazards, recovery 0.4,
    // correlation 0.05, attachment 0.03, detachment 0.06, five-year horizon.
    let horizon, yok = basket::example_horizon();
    let notionals: f64[10] = [100.0; 10];
    let hazards: f64[10] = [0.001, 0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09];
    let p, pok = basket::average_probability(notionals, hazards, horizon);
    let loss, lok2 = basket::expected_tranche_loss(1000.0, p, 0.4, 0.03, 0.06, 0.05);
    let printed, ok = basket::five_year_loss();
    if !yok || !pok || !lok2 || !ok { fail("example"); }
    if gap(loss, printed) > 0.0 { fail("example"); }
    if is_nan(printed) || is_inf(printed) || !(printed > 0.0) || printed > 1000.0 * (0.06 - 0.03) {
        fail("example");
    }

    // Correlation 1 is not a Gaussian copula factor loading.
    let rejected, rse, rok = basket::random_default_tranche(notionals, hazards, horizon, 0.0, 0.0, 1.0, 1.0, 2, basket::RANDOM_SEED);
    if rok || rse != 0.0 || rejected != 0.0 { fail("reject"); }

    // Correlation 0, recovery 0, attachment 0, detachment 1: every default
    // is a full notional loss and the tranche keeps it, so the mean is
    // notional times the average default probability.
    let rd_got, rd_se, rd_ok = basket::random_default_tranche(notionals, hazards, horizon, 0.0, 0.0, 1.0, 0.0, basket::SIMULATIONS, basket::RANDOM_SEED);
    let rd_want = 1000.0 * p;
    if !rd_ok { fail("random default"); }
    if gap(rd_got, rd_want) > 4.0 * rd_se { show_fail("random default", rd_got, rd_want, rd_se); }
    let analytic = bernoulli_se(notionals, hazards, horizon, 1.0, basket::SIMULATIONS);
    if analytic == 0.0 || gap(rd_se, analytic) / analytic > 0.05 { show_fail("random default se", rd_se, analytic, rd_got - rd_want); }

    // Spot recovery keeps the single-name expected loss, so the same full
    // tranche with the example recovery is notional * (1 - 0.4) * probability.
    let rl_got, rl_se, rl_ok = basket::random_loss_tranche(notionals, hazards, horizon, 0.4, 0.0, 1.0, 0.0, basket::SIMULATIONS, basket::RANDOM_SEED, basket::SPOT_A);
    let rl_want = 1000.0 * (1.0 - 0.4) * p;
    if !rl_ok { fail("random loss"); }
    if gap(rl_got, rl_want) > 4.0 * rl_se { show_fail("random loss", rl_got, rl_want, rl_se); }
    let loss_analytic = bernoulli_se(notionals, hazards, horizon, 0.6, basket::SIMULATIONS);
    if rl_se < 0.5 * loss_analytic || rl_se > 3.0 * loss_analytic { show_fail("random loss se", rl_se, loss_analytic, rl_got - rl_want); }

    write_stdout("basket ok\n");
}

fn bernoulli_se(notionals: f64[:], hazards: f64[:], horizon: f64, lgd: f64, sims: i64) -> f64 {
    var v = 0.0;
    var i: i64 = 0;
    while i < notionals.len {
        let prob = 1.0 - exp(-hazards[i] * horizon);
        let loss = notionals[i] * lgd;
        v += loss * loss * prob * (1.0 - prob);
        i += 1;
    }
    return sqrt(v / sims);
}
