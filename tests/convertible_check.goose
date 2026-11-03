import os;
import quant from "..";
import quant.black;
import quant.european;
import quant.rate;
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

fn ::main() {
    // ConvertibleBonds.cpp market, length 5. Conversion is at the money.
    // testOption: a zero credit spread is the straight bond plus the call.
    let spot = 36.0;
    let redemption = 100.0;
    let ratio = redemption / spot;
    let r = 0.06;
    let q = 0.02;
    let vol = 0.20;
    let t = 5.0;
    let spread = 0.005;
    let px, ok = convertible::npv(spot, redemption, ratio, r, q, vol, t, 0.0);
    let call, cok = european::npv(black::CALL, spot, spot, r, q, vol, t);
    let df, dok = rate::discount_factor(r, rate::CONTINUOUS, 0, t);
    if !ok || !cok || !dok { fail("spread zero"); }
    if gap(px, df * redemption + ratio * call) > 1.0e-9 { fail("spread zero"); }

    // No conversion: only the risky redemption remains.
    let buried, bok = convertible::npv(1.0, redemption, ratio, r, q, vol, t, spread);
    let risky, rok = rate::discount_factor(r + spread, rate::CONTINUOUS, 0, t);
    if !bok || !rok || gap(buried, risky * redemption) > 1.0e-9 { fail("no conversion"); }

    // Certain conversion: the shares, whatever the credit spread.
    // A zero strike is that prepaid forward.
    let high = 100000.0;
    let equity, eok = convertible::npv(high, redemption, ratio, r, q, vol, t, spread);
    let stock, sok = european::npv(black::CALL, high, 0.0, r, q, vol, t);
    if !eok || !sok || gap(equity, ratio * stock) > 1.0e-6 { fail("certain conversion"); }

    let dead, ddok = convertible::npv(1.0, redemption, ratio, r, q, 0.0, t, spread);
    if !ddok || gap(dead, risky * redemption) > 1.0e-12 { fail("zero vol"); }

    let bad, reject = convertible::npv(0.0, redemption, ratio, r, q, vol, t, spread);
    if reject || bad != 0.0 { fail("reject"); }

    write_stdout("convertible ok\n");
}
