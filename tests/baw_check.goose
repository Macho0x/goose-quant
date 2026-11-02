import os;
import quant from "..";
import quant.black;
import quant.baw;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    let px, ok = baw::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    if !ok { fail("price"); }
    var scaled = (px * 1000000.0 + 0.5) as i64;
    if scaled != 4459628 { fail("published"); }
    var line: u8[>..] = [];
    format(line, "baw ");
    format(line, px);
    format(line, "\nbaw ok\n");
    write_stdout(line);
}
