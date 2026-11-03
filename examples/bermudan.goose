import os;
import quant from "..";
import quant.hullwhite;

fn ::main() {
    let quote = 94.0;
    let sigma = 0.015;
    let t = 5.0;
    let implied = (100.0 - quote) / 100.0;
    var maturity: f64[5] = [5.25, 5.25, 5.25, 5.001, 5.0];
    var reversion: f64[5] = [0.03, 1.0e-4, 0.0, 0.03, 0.03];
    var i = 0;
    while i < maturity.len {
        let bias, ok = hullwhite::convexity_bias(quote, t, maturity[i], sigma, reversion[i]);
        if !ok { exit(1); }
        var line: u8[>..] = [];
        format_flt(line, implied - bias, 7);
        format(line, "\n");
        write_stdout(line);
        i += 1;
    }
    write_stdout("bermudan ok\n");
}
