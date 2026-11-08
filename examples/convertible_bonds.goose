import os;
import quant from "..";
import quant.convertible;

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

fn row(name: u8[:], euro: f64, amer: f64) {
    var line: u8[>..] = [];
    format(line, name);
    format(line, " ");
    format(line, euro);
    format(line, " ");
    format(line, amer);
    format(line, "\n");
    write_stdout(line);
}

fn show(name: u8[:], kind: i32, spot: f64, redemption: f64, ratio: f64, r: f64, q: f64, vol: f64, t: f64, spread: f64, closed: f64, coupon_t: f64[:], coupon_a: f64[:], div_t: f64[:], div_a: f64[:]) {
    var hole: f64[1] = [0.0];
    let none = hole[0..0];
    let zero, zok = convertible::binomial(spot, redemption, ratio, r, q, vol, t, 0.0, 801, kind, false, none, none, none, none);
    if !zok || gap(zero, closed) > 5.0e-2 { return; }
    let eu, eok = convertible::binomial(spot, redemption, ratio, r, q, vol, t, spread, 801, kind, false, coupon_t, coupon_a, div_t, div_a);
    let am, aok = convertible::binomial(spot, redemption, ratio, r, q, vol, t, spread, 801, kind, true, coupon_t, coupon_a, div_t, div_a);
    if !eok || !aok { return; }
    row(name, eu, am);
}

fn ::main() {
    // ConvertibleBonds.cpp: spot 36, redemption 100 at the money, r 0.06,
    // dividend yield 0.02, vol 0.20, credit spread 0.005, length 5.
    // The first line is the European zero-coupon at spread 0: closed form,
    // then the 801-step Cox-Ross-Rubinstein tree. Later rows are the 5%
    // annual coupon bond with a dividend of 1 each half-year. A tree is
    // printed only when that same zero-coupon check is within 0.05.
    // Additive equiprobabilities are outside that band at 801 steps.
    let spot = 36.0;
    let redemption = 100.0;
    let ratio = redemption / spot;
    let r = 0.06;
    let q = 0.02;
    let vol = 0.20;
    let t = 5.0;
    let spread = 0.005;
    let closed, cok = convertible::npv(spot, redemption, ratio, r, q, vol, t, 0.0);
    if !cok { fail("closed"); }
    let bin, bok = convertible::crr(spot, redemption, ratio, r, q, vol, t, 0.0, 801);
    if !bok { fail("binomial"); }
    var line: u8[>..] = [];
    format(line, closed);
    format(line, " ");
    format(line, bin);
    format(line, "\n");
    write_stdout(line);
    var coupon_t: f64[>..] = [];
    var coupon_a: f64[>..] = [];
    var div_t: f64[>..] = [];
    var div_a: f64[>..] = [];
    if !convertible::sample_flows(t, coupon_t, coupon_a, div_t, div_a) { fail("flows"); }
    show("Cox-Ross-Rubinstein", convertible::CRR, spot, redemption, ratio, r, q, vol, t, spread, closed, coupon_t, coupon_a, div_t, div_a);
    show("Jarrow-Rudd", convertible::JR, spot, redemption, ratio, r, q, vol, t, spread, closed, coupon_t, coupon_a, div_t, div_a);
    show("Trigeorgis", convertible::TRIGEORGIS, spot, redemption, ratio, r, q, vol, t, spread, closed, coupon_t, coupon_a, div_t, div_a);
    show("Tian", convertible::TIAN, spot, redemption, ratio, r, q, vol, t, spread, closed, coupon_t, coupon_a, div_t, div_a);
    show("Leisen-Reimer", convertible::LEISEN, spot, redemption, ratio, r, q, vol, t, spread, closed, coupon_t, coupon_a, div_t, div_a);
    show("Joshi", convertible::JOSHI, spot, redemption, ratio, r, q, vol, t, spread, closed, coupon_t, coupon_a, div_t, div_a);
    write_stdout("convertible bonds ok\n");
}
