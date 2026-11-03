import os;
import quant from "..";
import quant.hullwhite;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    let quote = 94.0;
    let sigma = 0.015;
    let t = 5.0;
    let implied = (100.0 - quote) / 100.0;
    var maturity: f64[5] = [5.25, 5.25, 5.25, 5.001, 5.0];
    var reversion: f64[5] = [0.03, 1.0e-4, 0.0, 0.03, 0.03];
    var want: f64[5] = [0.0573037, 0.0568627, 0.0568611, 0.0575736, 0.0575747];
    var i = 0;
    while i < maturity.len {
        let bias, ok = hullwhite::convexity_bias(quote, t, maturity[i], sigma, reversion[i]);
        if !ok || abs(implied - bias - want[i]) >= 1.0e-7 { fail("forward"); }
        i += 1;
    }
    write_stdout("hullwhite ok\n");
}
