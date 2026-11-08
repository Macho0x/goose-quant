import os;
import quant from "..";
import quant.latent;

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

fn show(x: f64) {
    var line: u8[>..] = [];
    format(line, x);
    format(line, "\n");
    write_stdout(line);
}

fn tail3(need: i64, p: f64) -> f64 {
    let q = 1.0 - p;
    let c1 = 3.0 * p * q * q;
    let c2 = 3.0 * p * p * q;
    let c3 = p * p * p;
    if need <= 0 { return 1.0; }
    if need == 1 { return c1 + c2 + c3; }
    if need == 2 { return c2 + c3; }
    if need == 3 { return c3; }
    return 0.0;
}

fn ::main() {
    let pd, ok = latent::default_probability(1.0);
    if !ok { fail("hazard"); }
    var same: f64[3] = [pd, pd, pd];
    let indep, iok = latent::joint_survival(same, 0.0);
    let s = 1.0 - pd;
    if !iok || indep != s * s * s { fail("independence"); }

    let p2, a2 = latent::default_probability(2.0);
    let p5, a5 = latent::default_probability(5.0);
    if !a2 || !a5 { fail("tenor"); }
    var book: f64[3] = [pd, p2, p5];
    let survived, sok = latent::joint_survival(book, 1.0);
    var worst = pd;
    if p2 > worst { worst = p2; }
    if p5 > worst { worst = p5; }
    if !sok || survived != 1.0 - worst { fail("perfect"); }

    let got, gok = latent::integrated_default(pd, latent::factor_weight());
    if !gok { fail("integral"); }
    if gap(got, pd) > 1.0e-8 { fail("marginal"); }

    let mid, mok = latent::joint_survival(same, latent::factor_weight());
    if !mok || mid <= s * s * s || mid >= s { fail("copula"); }

    let t, tok = latent::horizon();
    if !tok { fail("date"); }
    let hp, hok = latent::default_probability(t);
    if !hok { fail("horizon"); }
    let w = latent::factor_weight();

    var n: i64 = 0;
    while n <= latent::NAMES {
        let z, zok = latent::prob_at_least(n, hp, w, latent::NAMES);
        if !zok { fail("events"); }
        if n == 0 && z != 1.0 { fail("none"); }
        let indep_p, iok2 = latent::prob_at_least(n, hp, 0.0, latent::NAMES);
        if !iok2 || gap(indep_p, tail3(n, hp)) > 1.0e-6 { fail("binomial"); }
        let one, ook = latent::prob_at_least(n, hp, 1.0, latent::NAMES);
        if !ook { fail("comonotonic"); }
        if n == 0 && one != 1.0 { fail("comonotonic"); }
        if n > 0 && one != hp { fail("comonotonic"); }
        n += 1;
    }

    let link, lok = latent::prob_at_least(1, hp, w, 1);
    if !lok || gap(link, hp) > 1.0e-6 { fail("link"); }

    var tn: i64 = 0;
    while tn <= latent::NAMES {
        let tz, tzok = latent::prob_at_least_t(tn, hp, 0.0, latent::NAMES);
        if !tzok || gap(tz, tail3(tn, hp)) > 1.0e-6 { fail("t-binomial"); }
        let tc, tcok = latent::prob_at_least_t(tn, hp, 1.0, latent::NAMES);
        if !tcok { fail("t-comonotonic"); }
        if tn == 0 && tc != 1.0 { fail("t-comonotonic"); }
        if tn > 0 && tc != hp { fail("t-comonotonic"); }
        tn += 1;
    }
    let tm, tmok = latent::prob_at_least_t(1, hp, w, 1);
    if !tmok || gap(tm, hp) > 1.0e-6 { fail("t-marginal"); }

    var probs: f64[>..] = [];
    var errs: f64[>..] = [];
    if !latent::mc_at_least(hp, w, latent::NAMES, false, latent::MC_SEED, latent::MC_PATHS, probs, errs) { fail("mc"); }
    n = 0;
    while n <= latent::NAMES {
        let p, pok = latent::prob_at_least(n, hp, w, latent::NAMES);
        if !pok || n >= probs.len { fail("print"); }
        if gap(probs[n], p) > 4.0 * errs[n] { fail("mc gauss"); }
        show(p);
        n += 1;
    }
    if !latent::mc_at_least(hp, w, latent::NAMES, true, latent::MC_SEED, latent::MC_PATHS, probs, errs) { fail("mc t"); }
    n = 0;
    while n <= latent::NAMES {
        let p, pok = latent::prob_at_least_t(n, hp, w, latent::NAMES);
        if !pok || gap(probs[n], p) > 4.0 * errs[n] { fail("mc student"); }
        n += 1;
    }
    if !latent::mc_at_least(hp, 0.0, latent::NAMES, false, latent::MC_SEED, latent::MC_PATHS, probs, errs) { fail("mc zero"); }
    n = 0;
    while n <= latent::NAMES {
        if gap(probs[n], tail3(n, hp)) > 4.0 * errs[n] { fail("mc binomial"); }
        n += 1;
    }
    if !latent::mc_at_least(hp, 0.0, latent::NAMES, true, latent::MC_SEED, latent::MC_PATHS, probs, errs) { fail("mc t zero"); }
    n = 0;
    while n <= latent::NAMES {
        if gap(probs[n], tail3(n, hp)) > 4.0 * errs[n] { fail("mc t binomial"); }
        n += 1;
    }
    write_stdout("latent ok\n");
}
