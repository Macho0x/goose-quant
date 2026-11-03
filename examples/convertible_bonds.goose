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
    // European zero-coupon. The example's calls, puts, coupons, and
    // dividends are the binomial and have no locked price.
    let spot = 36.0;
    let redemption = 100.0;
    let px, ok = convertible::npv(spot, redemption, redemption / spot, 0.06, 0.02, 0.20, 5.0, 0.005);
    if !ok { fail("price"); }
    var line: u8[>..] = [];
    format(line, px);
    format(line, "\nconvertible bonds ok\n");
    write_stdout(line);
}
