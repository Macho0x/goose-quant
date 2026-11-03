// LatentModel example, 19 March 2014, three names, notional 100,
// flat hazard -ln(0.99). Horizon is the sample's 120-month date.
// Expected loss is notional times the default probability. The factor
// loading cancels in that sum; the copula is checked in the test.
// The four lines after the loss are prob_at_least for N = 0, 1, 2, 3
// on that date, Gaussian direct integration, then the T_3 integral.

import os;
import quant from "..";
import quant.latent;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn show(x: f64) {
    var line: u8[>..] = [];
    format(line, x);
    format(line, "\n");
    write_stdout(line);
}

fn ::main() {
    let t, tok = latent::horizon();
    if !tok { fail("date"); }
    let loss, ok = latent::expected_loss(latent::NOTIONAL, t, latent::NAMES);
    if !ok { fail("loss"); }
    show(loss);
    let pd, pok = latent::default_probability(t);
    if !pok { fail("pd"); }
    let w = latent::factor_weight();
    var n: i64 = 0;
    while n <= latent::NAMES {
        let p, aok = latent::prob_at_least(n, pd, w, latent::NAMES);
        if !aok { fail("gauss"); }
        show(p);
        n += 1;
    }
    n = 0;
    while n <= latent::NAMES {
        let p, aok = latent::prob_at_least_t(n, pd, w, latent::NAMES);
        if !aok { fail("student"); }
        show(p);
        n += 1;
    }
    write_stdout("latent ok\n");
}
