import os;
import quant from "..";
import quant.black;
import quant.european;
import quant.sobol;
import quant.qmc;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    // Gray code of N = index+1 against direction integers 1<<(31-j),
    // then times 0.5/(1<<31). Point 42 is the same recurrence.
    var g = sobol::open();
    var want: f64[16] = [
        0.5, 0.75, 0.25, 0.375, 0.875, 0.625, 0.125, 0.1875,
        0.6875, 0.9375, 0.4375, 0.3125, 0.8125, 0.5625, 0.0625, 0.09375,
    ];
    var i: i64 = 0;
    while i < 16 {
        let u = sobol::next_uniform(g);
        if u != want[i] {
            print(i);
            print(u);
            fail("uniform");
        }
        i += 1;
    }
    while i < 42 {
        sobol::next_uniform(g);
        i += 1;
    }
    let u42 = sobol::next_uniform(g);
    if u42 != 0.484375 {
        print(u42);
        fail("uniform 42");
    }

    let analytic, aok = european::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    if !aok { fail("analytic"); }
    let price, ok = qmc::european_put(36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 32768);
    print(price);
    if !ok { fail("qmc"); }
    var gap = price - analytic;
    if gap < 0.0 { gap = -gap; }
    if !(gap < 0.02) { fail("tolerance"); }
    write_stdout("qmc ok\n");
}
