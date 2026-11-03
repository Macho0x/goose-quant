import os;
import math;
import quant from "..";
import quant.black;
import quant.european;
import quant.qd;

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

fn boundary(tau: f64, expected: f64, tol: f64) {
    let got, ok = qd::put_boundary(100.0, 120.0, 0.1, 0.03, 0.25, tau);
    if !ok || is_nan(got) || is_inf(got) || gap(got, expected) > tol {
        var line: u8[>..] = [];
        format(line, "boundary ");
        format(line, tau);
        format(line, " got ");
        format(line, got);
        format(line, " expected ");
        format(line, expected);
        format(line, "\n");
        write_stdout(line);
        exit(1);
    }
}

fn ::main() {
    boundary(4.9, 87.76960949965387, 1.0e-12);
    boundary(4.0, 88.39053003614612, 1.0e-12);
    boundary(2.5, 90.14327315762256, 1.0e-12);
    boundary(1.0, 94.49793803095984, 1.0e-12);
    // tau 0.1 is about 1.5e-12 off the published root. Halley noise, inside 1e-10.
    boundary(0.1, 106.2588964442338, 1.0e-10);

    let euro, eok = european::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    if !eok { fail("european"); }
    if gap(euro, 3.8443077915968398) > 1.0e-12 { fail("euro ref"); }
    let px, pok = qd::npv_fast(36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    if !pok || is_nan(px) || is_inf(px) || px < euro { fail("fast"); }

    var line: u8[>..] = [];
    format(line, "qd ok ");
    format(line, px);
    format(line, "\n");
    write_stdout(line);
}
