import os;
import quant from "..";
import quant.normal;
import quant.black;
import quant.curve;
import quant.european;
import quant.rate;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn near(got: f64, want: f64, tol: f64) -> bool {
    var d = got - want;
    if d < 0.0 { d = -d; }
    return d <= tol;
}

fn ::main() {
    if !near(normal::cdf(0.0), 0.5, 1.0e-15) { fail("cdf 0"); }
    if !near(normal::cdf(1.0), 0.841344746068543, 1.0e-12) { fail("cdf 1"); }
    if !near(normal::erf(1.0), 0.8427007929497149, 1.0e-12) { fail("erf 1"); }
    let inv, iok = normal::inv_cdf(0.975);
    if !iok || !near(inv, 1.959963984540054, 1.0e-8) { fail("inv"); }

    let call, cok = black::black(black::CALL, 100.0, 100.0, 0.2, 1.0, 0.0);
    if !cok || !near(call, 7.965567455405804, 1.0e-10) { fail("black call"); }
    let put, pok = black::black(black::PUT, 100.0, 100.0, 0.2, 1.0, 0.0);
    if !pok || !near(put, 7.965567455405804, 1.0e-10) { fail("black put"); }
    let zero, zok = black::black(black::CALL, 100.0, 100.0, 0.0, 1.0, 0.0);
    if !zok || zero != 0.0 { fail("black zero"); }
    let eu, euok = european::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    if !euok || !near(eu, 3.84430779159684, 1.0e-10) { fail("european"); }
    let df, dfok = curve::flat_discount(0.05, rate::CONTINUOUS, 1, 1.0);
    if !dfok || !near(df, 0.951229424500714, 1.0e-12) { fail("flat"); }

    let cf, cfok = rate::compound_factor(0.05, rate::COMPOUNDED, 2, 1.0);
    if !cfok || !near(cf, 1.050625, 1.0e-12) { fail("compound"); }
    let back, bok = rate::implied_rate(cf, rate::COMPOUNDED, 2, 1.0);
    if !bok || !near(back, 0.05, 1.0e-12) { fail("implied"); }
    let cont, tok = rate::equivalent(0.05, rate::COMPOUNDED, 2, rate::CONTINUOUS, 0, 1.0);
    if !tok || !near(cont, 0.049385225, 1.0e-8) { fail("equivalent"); }

    write_stdout("black ok\n");
}
