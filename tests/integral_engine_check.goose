import os;
import quant from "..";
import quant.vanilla_integral;
import quant.european;
import quant.black;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn rel(got: f64, want: f64) -> f64 {
    var d = got - want;
    if d < 0.0 { d = -d; }
    var scale = want;
    if scale < 0.0 { scale = -scale; }
    if scale < 1.0 { scale = 1.0; }
    return d / scale;
}

fn check(option: i32, spot: f64, strike: f64, r: f64, q: f64, vol: f64, t: f64) -> f64 {
    let integral, iok = vanilla_integral::npv(option, spot, strike, r, q, vol, t);
    let analytic, aok = european::npv(option, spot, strike, r, q, vol, t);
    if !iok || !aok { fail("price"); }
    if rel(integral, analytic) >= 0.0001 { fail("tol"); }
    return integral;
}

fn ::main() {
    let put = check(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    check(black::CALL, 100.0, 100.0, 0.05, 0.02, 0.25, 0.75);
    check(black::CALL, 90.0, 100.0, 0.10, 0.10, 0.10, 0.5);
    var line: u8[>..] = [];
    format(line, put);
    format(line, "\nintegral engine ok\n");
    write_stdout(line);
}
