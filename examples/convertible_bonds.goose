import os;
import quant from "..";
import quant.convertible;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    // ConvertibleBonds.cpp: spot 36, redemption 100 at the money, r 0.06,
    // dividend yield 0.02, vol 0.20, credit spread 0.005, length 5.
    // The closed form is the European zero-coupon. The binomial is the
    // same bond with the spread set to 0, on the example's 801-step
    // Cox-Ross-Rubinstein tree. Calls, puts, coupons, and dividends have
    // no locked price.
    let spot = 36.0;
    let redemption = 100.0;
    let ratio = redemption / spot;
    let r = 0.06;
    let q = 0.02;
    let vol = 0.20;
    let t = 5.0;
    let closed, cok = convertible::npv(spot, redemption, ratio, r, q, vol, t, 0.0);
    if !cok { fail("closed"); }
    let bin, bok = convertible::crr(spot, redemption, ratio, r, q, vol, t, 0.0, 801);
    if !bok { fail("binomial"); }
    var line: u8[>..] = [];
    format(line, closed);
    format(line, " ");
    format(line, bin);
    format(line, "\nconvertible bonds ok\n");
    write_stdout(line);
}
