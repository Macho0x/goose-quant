import os;
import quant from "..";
import quant.black;
import quant.european;
import quant.mt;
import quant.mc;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    var g = default<mt::Twister>();
    mt::seed(g, 42);
    if mt::next_u32(g) != 1608637542 { fail("twister"); }

    let analytic, aok = european::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    if !aok { fail("analytic"); }
    let price, samples, ok = mc::european_put(36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 0.02, 42);
    print(price);
    print(samples);
    if !ok { fail("mc"); }
    var gap = price - analytic;
    if gap < 0.0 { gap = -gap; }
    if !(gap < 0.02) { fail("tolerance"); }
    write_stdout("mc ok\n");
}
