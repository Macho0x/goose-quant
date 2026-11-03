// Gaussian1dModels prints tree NPVs and does not lock a literal.
// This is the analytic G2 zero bond from testG2DiscountBondForSmallMeanReversion.

import os;
import quant from "..";
import quant.gauss1d;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    let px, ok = gauss1d::discount_bond(0.03, 1e-9, 0.01, 0.1, 0.005, -0.5, 1.0, 5.0, 0.01, -0.01);
    if !ok { fail("bond"); }
    var line: u8[>..] = [];
    format(line, px);
    format(line, "\ngaussian1d ok\n");
    write_stdout(line);
}
