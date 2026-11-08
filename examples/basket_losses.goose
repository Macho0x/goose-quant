import os;
import quant from "..";
import quant.basket;

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

fn emit(label: u8[:], got: f64, want: f64, se: f64, ok: bool) {
    if !ok { return; }
    var gap = got - want;
    if gap < 0.0 { gap = -gap; }
    if gap > 4.0 * se { return; }
    var line: u8[>..] = [];
    format(line, label);
    format(line, " ");
    format(line, got);
    format(line, "\n");
    write_stdout(line);
}

fn ::main() {
    let loss, ok = basket::five_year_loss();
    if !ok { fail("loss"); }
    var line: u8[>..] = [];
    format(line, loss);
    format(line, "\n");
    write_stdout(line);

    let horizon, hok = basket::example_horizon();
    let notionals: f64[10] = [100.0; 10];
    let hazards: f64[10] = [0.001, 0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09];
    if hok {
        let bin, bok = basket::gaussian_binomial_tranche(notionals, hazards, horizon, 0.4, 0.03, 0.06, 0.05);
        if bok { show(bin); }
        let rd, rdse, rdok = basket::random_default_tranche(notionals, hazards, horizon, 0.4, 0.03, 0.06, 0.05, basket::SIMULATIONS, basket::RANDOM_SEED);
        if rdok && bok {
            var rgap = rd - bin;
            if rgap < 0.0 { rgap = -rgap; }
            if rgap <= 4.0 * rdse { show(rd); }
        }
    }
    let p, pok = basket::average_probability(notionals, hazards, horizon);
    let gate, gse, gok = basket::random_default_tranche(notionals, hazards, horizon, 0.0, 0.0, 1.0, 0.0, basket::SIMULATIONS, basket::RANDOM_SEED);
    if hok && pok && gok {
        let want0 = 1000.0 * p;
        var ggap = gate - want0;
        if ggap < 0.0 { ggap = -ggap; }
        if ggap <= 4.0 * gse {
            let recovery = 0.4;
            let want = 1000.0 * (1.0 - recovery) * p;
            let got, se, rok = basket::random_default_tranche(notionals, hazards, horizon, recovery, 0.0, 1.0, 0.0, basket::SIMULATIONS, basket::RANDOM_SEED);
            emit("random default Gaussian", got, want, se, rok);
            let lgot, lse, lok = basket::random_loss_tranche(notionals, hazards, horizon, recovery, 0.0, 1.0, 0.0, basket::SIMULATIONS, basket::RANDOM_SEED, basket::SPOT_A);
            emit("random loss Gaussian", lgot, want, lse, lok);
        }
    }
    write_stdout("basket losses ok\n");
}
