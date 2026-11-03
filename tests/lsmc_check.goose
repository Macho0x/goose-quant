import os;
import math;
import quant from "..";
import quant.lsmc;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    let price, paths, ok = lsmc::american_put(36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 0.02, 42);
    print(price);
    print(paths);
    if !ok { fail("tolerance"); }
    if is_nan(price) || is_inf(price) { fail("finite"); }
    if price < 3.8443077915968398 { fail("european"); }
    if price > 40.0 { fail("strike"); }
    write_stdout("lsmc ok\n");
}
