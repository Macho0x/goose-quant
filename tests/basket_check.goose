import os;
import math;
import quant from "..";
import quant.basket;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
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
    write_stdout("basket ok\n");
}
