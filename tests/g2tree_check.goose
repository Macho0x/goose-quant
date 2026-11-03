import os;
import quant from "..";
import quant.g2tree;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    var m: f64[5] = [0.5, 0.75, 1.0, 1.25, 1.5];
    var want: f64[5] = [103.248, 54.6726, 20.1685, 5.44118, 1.12737];
    var i = 0;
    while i < m.len {
        let px, ok = g2tree::price(m[i]);
        if !ok { fail("price"); }
        var gap = px - want[i];
        if gap < 0.0 { gap = -gap; }
        if gap > 0.005 {
            var line: u8[>..] = [];
            format_flt(line, px, 8);
            format(line, "\n");
            write_stdout(line);
            fail("tol");
        }
        i += 1;
    }
    write_stdout("g2tree ok\n");
}
