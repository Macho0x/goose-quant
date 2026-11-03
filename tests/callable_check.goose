import os;
import quant from "..";
import quant.callable;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    let px, ok = callable::price();
    if !ok { fail("price"); }
    var d = px - 74.54521578;
    if d < 0.0 { d = -d; }
    if d > 1.0e-4 { fail("clean"); }
    let hw, hok = callable::tree_clean();
    if !hok { fail("tree"); }
    var e = hw - 110.60975477;
    if e < 0.0 { e = -e; }
    if e > 1.0e-8 { fail("hw"); }
    let put, putok = callable::tree_put();
    if !putok { fail("put"); }
    var p = put - 115.16559362;
    if p < 0.0 { p = -p; }
    if p > 1.0e-8 { fail("put price"); }
    let both, bok = callable::tree_both();
    if !bok { fail("both"); }
    var b = both - 110.97509625;
    if b < 0.0 { b = -b; }
    if b > 1.0e-8 { fail("both price"); }
    write_stdout("callable ok\n");
}
