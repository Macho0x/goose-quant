import os;
import math;
import quant from "..";
import quant.gauss;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn apart(got: f64, want: f64) -> bool {
    var d = got - want;
    if d < 0.0 { d = -d; }
    return d > 1.0e-4;
}

fn ::main() {
    let one = gauss::integrate() { exp(-it * it) * cos(it) };
    let three = one * one * one;
    if apart(one, exp(-0.25) * sqrt(PI)) { fail("gauss 1d"); }
    if apart(three, 2.630291900394673) { fail("gauss 3d"); }
    var line: u8[>..] = [];
    format(line, one);
    format(line, "\n");
    write_stdout(line);
    write_stdout("gauss ok\n");
}
