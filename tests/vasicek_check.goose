import os;
import math;
import quant from "..";
import quant.black;
import quant.european;
import quant.vasicek;

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
    let euro, eok = european::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    if !eok || gap(euro, 3.8443077915968398) > 1.0e-12 { fail("european"); }
    // Vanishing rate volatility and correlation, long-run mean equal to r0.
    // The short rate stays at r, so the price is the Black-Scholes put.
    let flat, fok = vasicek::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 0.3, 0.06, 0.0, 0.0, 0.0);
    if !fok || gap(flat, euro) > 1.0e-8 { fail("flat"); }
    // EquityOption: put, spot 36, strike 40, r0 0.06, q 0, vol 0.20, t 1,
    // a 0.3, b 0.3, sigma_r 0.15, risk premium 0, correlation 0.5.
    let px, ok = vasicek::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 0.3, 0.3, 0.15, 0.0, 0.5);
    if !ok || is_nan(px) || is_inf(px) || !(px > 0.0) { fail("example"); }
    var line: u8[>..] = [];
    format(line, px);
    format(line, "\nvasicek ok\n");
    write_stdout(line);
}
