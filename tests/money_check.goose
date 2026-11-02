import os;
import quant from "..";
import quant.currency;
import quant.rounding;
import quant.money;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn near(got: f64, want: f64) -> bool {
    var d = got - want;
    if d < 0.0 { d = -d; }
    return d <= 1.0e-8;
}

fn ::main() {
    let eur, eok = currency::by_code("EUR");
    if !eok || eur.numeric != 978 || eur.fractions != 100 || eur.precision != 2 || eur.round != currency::CLOSEST {
        fail("eur");
    }
    let usd, uok = currency::by_code("USD");
    let gbp, gok = currency::by_code("GBP");
    let dash, dok = currency::by_code("DASH");
    if !uok || usd.numeric != 840 || !gok || gbp.numeric != 826 || !dok || dash.ncode != 4 {
        fail("codes");
    }
    let ename, nok = currency::name("EUR");
    if !nok || ename != "European Euro" { fail("name"); }
    let missing, mok = currency::by_code("ZZZ");
    if mok { fail("missing"); }

    if !near(rounding::apply(0.86313513, 5, rounding::CLOSEST, 5), 0.86314) { fail("closest"); }
    if !near(rounding::apply(-7.64555346, 1, rounding::UP, 5), -7.7) { fail("up"); }
    if !near(rounding::apply(-1.06228670, 1, rounding::DOWN, 5), -1.0) { fail("down"); }
    if !near(rounding::apply(0.13961605, 2, rounding::FLOOR, 5), 0.14) { fail("floor"); }
    if !near(rounding::apply(0.13961605, 2, rounding::CEILING, 5), 0.13) { fail("ceiling"); }
    if rounding::apply(1.234, 2, rounding::NONE, 5) != 1.234 { fail("none"); }

    let m1 = money::cash(50000.0, eur.numeric);
    let m2 = money::cash(100000.0, eur.numeric);
    let m3 = money::cash(500000.0, eur.numeric);
    let a = money::scale(m1, 3.0);
    let b = money::scale(m2, 2.5);
    let c = money::scale(m3, 0.2);
    let part, pok = money::ratio(m2, m3);
    if !pok { fail("ratio"); }
    let d = money::scale(m1, part);
    let s1, s1ok = money::add(a, b);
    let s2, s2ok = money::sub(s1, c);
    let s3, s3ok = money::add(s2, d);
    if !s1ok || !s2ok || !s3ok || !near(s3.amount, 310000.0) { fail("arithmetic"); }

    let pair = money::Pair { source: eur.numeric, target: usd.numeric, rate: 1.2042 };
    let bought, bok = money::exchange(100.0, eur.numeric, usd.numeric, pair);
    let sold, sok = money::exchange(bought, usd.numeric, eur.numeric, pair);
    if !bok || !sok || !near(bought, 120.42) || !near(sold, 100.0) { fail("fx"); }

    var pairs: money::Pair[2] = [
        money::Pair { source: eur.numeric, target: usd.numeric, rate: 1.2 },
        money::Pair { source: eur.numeric, target: gbp.numeric, rate: 0.8 },
    ];
    let usd_amt, cok = money::convert(100.0, gbp.numeric, usd.numeric, pairs);
    if !cok || !near(usd_amt, 150.0) { fail("chain"); }

    let mid, mok = money::mid_equivalent(1.0, 2.0, 0.0, 4.0);
    let bid_only, bok2 = money::mid_equivalent(1.0, 0.0, 3.0, 4.0);
    let last_only, lok = money::mid_equivalent(0.0, 0.0, 3.0, 4.0);
    let close_only, clok = money::mid_equivalent(0.0, 0.0, 0.0, 4.0);
    let none, nok2 = money::mid_equivalent(0.0, 0.0, 0.0, 0.0);
    let safe, sok2 = money::mid_safe(1.0, 2.0);
    let unsafe, uok = money::mid_safe(1.0, 0.0);
    if !mok || !near(mid, 1.5) || !bok2 || bid_only != 1.0 || !lok || last_only != 3.0 { fail("mid"); }
    if !clok || close_only != 4.0 || nok2 || !sok2 || !near(safe, 1.5) || uok { fail("mid safe"); }

    write_stdout("money ok\n");
}
