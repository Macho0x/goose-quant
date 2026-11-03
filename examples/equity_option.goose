import os;
import quant from "..";
import quant.date;
import quant.period;
import quant.black;
import quant.european;
import quant.tree;
import quant.baw;
import quant.bjerk;
import quant.qd;
import quant.vasicek;
import quant.heston;
import quant.bates;
import quant.vanilla_integral;
import quant.fd;
import quant.mc;
import quant.qmc;
import quant.lsmc;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn fixed6(out: u8[>..]&, x: f64) {
    var scaled = (x * 1000000.0 + 0.5) as i64;
    if scaled < 0 { scaled = 0; }
    format_int(out, scaled / 1000000, 10, 1, ' ');
    format(out, ".");
    format_int(out, scaled % 1000000, 10, 6, '0');
    format(out, "      ");
}

fn row(name: u8[:], euro: f64, berm: f64, amer: f64, european: bool, bermudan: bool, american: bool) {
    var line: u8[>..] = [];
    format(line, name);
    var i = name.len;
    while i < 35 {
        format(line, " ");
        i += 1;
    }
    if european { fixed6(line, euro); } else { format(line, "N/A           "); }
    if bermudan { fixed6(line, berm); } else { format(line, "N/A           "); }
    if american { fixed6(line, amer); } else { format(line, "N/A"); }
    format(line, "\n");
    write_stdout(line);
}

fn ::main() {
    let settlement, sok = date::from_ymd(17, date::MAY, 1998);
    if !sok { fail("date"); }
    var stops: f64[4] = [0.0, 0.0, 0.0, 0.0];
    var i: i32 = 1;
    while i <= 4 {
        let when, ok = date::advance(settlement, 3 * i, period::MONTHS);
        if !ok { fail("stop"); }
        stops[(i - 1) as i64] = (when.serial - settlement.serial) / 365.0;
        i += 1;
    }
    let spot = 36.0;
    let strike = 40.0;
    let r = 0.06;
    let q = 0.0;
    let vol = 0.20;
    let t = stops[3];
    let bs, bok = european::npv(black::PUT, spot, strike, r, q, vol, t);
    if !bok { fail("black"); }
    write_stdout("Method                             European        Bermudan        American\n");
    row("Black-Scholes", bs, 0.0, 0.0, true, false, false);
    let vas, vok = vasicek::npv(black::PUT, spot, strike, r, q, vol, t, 0.3, 0.3, 0.15, 0.0, 0.5);
    if !vok { fail("vasicek"); }
    row("Black Vasicek Model", vas, 0.0, 0.0, true, false, false);
    let hest, hok = heston::npv(black::PUT, spot, strike, r, q, vol * vol, 1.0, vol * vol, 0.001, 0.0, t);
    if !hok { fail("heston"); }
    row("Heston semi-analytic", hest, 0.0, 0.0, true, false, false);
    let bat, batok = bates::npv(black::PUT, spot, strike, r, q, vol * vol, 1.0, vol * vol, 0.001, 0.0, 1.0e-14, 1.0e-14, 1.0e-14, t);
    if !batok { fail("bates"); }
    row("Bates semi-analytic", bat, 0.0, 0.0, true, false, false);
    let integ, iok = vanilla_integral::npv(black::PUT, spot, strike, r, q, vol, t);
    if !iok { fail("integral"); }
    row("Integral", integ, 0.0, 0.0, true, false, false);
    let baw, wok = baw::npv(black::PUT, spot, strike, r, q, vol, t);
    if !wok { fail("baw"); }
    row("Barone-Adesi/Whaley", 0.0, 0.0, baw, false, false, true);
    let bj, jok = bjerk::npv(black::PUT, spot, strike, r, q, vol, t);
    if !jok { fail("bjerk"); }
    row("Bjerksund/Stensland", 0.0, 0.0, bj, false, false, true);
    let qd_fast, qdok = qd::npv_fast(spot, strike, r, q, vol, t);
    if !qdok { fail("qd"); }
    row("QD+ fixed-point (fast)", 0.0, 0.0, qd_fast, false, false, true);
    let fde, fdok = fd::npv(black::PUT, spot, strike, r, q, vol, t, 801, 800, fd::EUROPEAN, stops);
    let fdb, fdbok = fd::npv(black::PUT, spot, strike, r, q, vol, t, 801, 800, fd::BERMUDAN, stops);
    let fda, fdaok = fd::npv(black::PUT, spot, strike, r, q, vol, t, 801, 800, fd::AMERICAN, stops);
    if !fdok || !fdbok || !fdaok { fail("fd"); }
    row("Finite differences", fde, fdb, fda, true, true, true);
    let steps: i32 = 801;
    let e, b, a, ok = triple(spot, strike, r, q, vol, t, steps, stops, 0);
    if !ok { fail("jr"); }
    row("Binomial Jarrow-Rudd", e, b, a, true, true, true);
    let e2, b2, a2, ok2 = triple(spot, strike, r, q, vol, t, steps, stops, 1);
    if !ok2 { fail("crr"); }
    row("Binomial Cox-Ross-Rubinstein", e2, b2, a2, true, true, true);
    let e3, b3, a3, ok3 = triple(spot, strike, r, q, vol, t, steps, stops, 2);
    if !ok3 { fail("additive"); }
    row("Additive equiprobabilities", e3, b3, a3, true, true, true);
    let e4, b4, a4, ok4 = triple(spot, strike, r, q, vol, t, steps, stops, 3);
    if !ok4 { fail("trigeorgis"); }
    row("Binomial Trigeorgis", e4, b4, a4, true, true, true);
    let e5, b5, a5, ok5 = triple(spot, strike, r, q, vol, t, steps, stops, 4);
    if !ok5 { fail("tian"); }
    row("Binomial Tian", e5, b5, a5, true, true, true);
    let e6, b6, a6, ok6 = triple(spot, strike, r, q, vol, t, steps, stops, 5);
    if !ok6 { fail("leisen"); }
    row("Binomial Leisen-Reimer", e6, b6, a6, true, true, true);
    let e7, b7, a7, ok7 = triple(spot, strike, r, q, vol, t, steps, stops, 6);
    if !ok7 { fail("joshi"); }
    row("Binomial Joshi", e7, b7, a7, true, true, true);
    let crude, samples, mok = mc::european_put(spot, strike, r, q, vol, t, 0.02, 42);
    if !mok || samples < 1 { fail("mc"); }
    row("MC (crude)", crude, 0.0, 0.0, true, false, false);
    let sobol, qok = qmc::european_put(spot, strike, r, q, vol, t, 32768);
    if !qok { fail("qmc"); }
    row("QMC (Sobol)", sobol, 0.0, 0.0, true, false, false);
    let ls, paths, lsok = lsmc::american_put(spot, strike, r, q, vol, t, 0.02, 42);
    if !lsok || paths < 1 { fail("lsmc"); }
    row("MC (Longstaff Schwartz)", 0.0, 0.0, ls, false, false, true);
    if a2 + 1.0e-8 < e2 { fail("exercise"); }
}

fn triple(spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64, steps: i32, stops: f64[:], which: i32) -> f64, f64, f64, bool {
    if which == 0 {
        let e, a = tree::jr(black::PUT, spot, strike, r, q, vol, t, steps, tree::EUROPEAN, stops);
        let b, c = tree::jr(black::PUT, spot, strike, r, q, vol, t, steps, tree::BERMUDAN, stops);
        let m, d = tree::jr(black::PUT, spot, strike, r, q, vol, t, steps, tree::AMERICAN, stops);
        return e, b, m, a && c && d;
    }
    if which == 1 {
        let e, a = tree::crr_style(black::PUT, spot, strike, r, q, vol, t, steps, tree::EUROPEAN, stops);
        let b, c = tree::crr_style(black::PUT, spot, strike, r, q, vol, t, steps, tree::BERMUDAN, stops);
        let m, d = tree::crr_style(black::PUT, spot, strike, r, q, vol, t, steps, tree::AMERICAN, stops);
        return e, b, m, a && c && d;
    }
    if which == 2 {
        let e, a = tree::additive(black::PUT, spot, strike, r, q, vol, t, steps, tree::EUROPEAN, stops);
        let b, c = tree::additive(black::PUT, spot, strike, r, q, vol, t, steps, tree::BERMUDAN, stops);
        let m, d = tree::additive(black::PUT, spot, strike, r, q, vol, t, steps, tree::AMERICAN, stops);
        return e, b, m, a && c && d;
    }
    if which == 3 {
        let e, a = tree::trigeorgis(black::PUT, spot, strike, r, q, vol, t, steps, tree::EUROPEAN, stops);
        let b, c = tree::trigeorgis(black::PUT, spot, strike, r, q, vol, t, steps, tree::BERMUDAN, stops);
        let m, d = tree::trigeorgis(black::PUT, spot, strike, r, q, vol, t, steps, tree::AMERICAN, stops);
        return e, b, m, a && c && d;
    }
    if which == 4 {
        let e, a = tree::tian(black::PUT, spot, strike, r, q, vol, t, steps, tree::EUROPEAN, stops);
        let b, c = tree::tian(black::PUT, spot, strike, r, q, vol, t, steps, tree::BERMUDAN, stops);
        let m, d = tree::tian(black::PUT, spot, strike, r, q, vol, t, steps, tree::AMERICAN, stops);
        return e, b, m, a && c && d;
    }
    if which == 5 {
        let e, a = tree::leisen(black::PUT, spot, strike, r, q, vol, t, steps, tree::EUROPEAN, stops);
        let b, c = tree::leisen(black::PUT, spot, strike, r, q, vol, t, steps, tree::BERMUDAN, stops);
        let m, d = tree::leisen(black::PUT, spot, strike, r, q, vol, t, steps, tree::AMERICAN, stops);
        return e, b, m, a && c && d;
    }
    let e, a = tree::joshi(black::PUT, spot, strike, r, q, vol, t, steps, tree::EUROPEAN, stops);
    let b, c = tree::joshi(black::PUT, spot, strike, r, q, vol, t, steps, tree::BERMUDAN, stops);
    let m, d = tree::joshi(black::PUT, spot, strike, r, q, vol, t, steps, tree::AMERICAN, stops);
    return e, b, m, a && c && d;
}
