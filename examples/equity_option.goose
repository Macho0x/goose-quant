import os;
import quant from "..";
import quant.black;
import quant.european;

fn ::main() {
    let px, ok = european::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    if !ok { exit(1); }
    var line: u8[>..] = [];
    format(line, "Black-Scholes ");
    format(line, px);
    format(line, "\n");
    write_stdout(line);
}
