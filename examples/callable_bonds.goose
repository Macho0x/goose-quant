import os;
import quant from "..";
import quant.callable;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn show(x: f64) {
    var v = x;
    var neg = false;
    if v < 0.0 {
        neg = true;
        v = -v;
    }
    let scaled = (v * 100000000.0 + 0.5) as i64;
    var line: u8[>..] = [];
    if neg { format(line, "-"); }
    format_int(line, scaled / 100000000, 10, 1, '0');
    format(line, ".");
    format_int(line, scaled % 100000000, 10, 8, '0');
    format(line, "\n");
    write_stdout(line);
}

fn ::main() {
    let px, ok = callable::price();
    if !ok { fail("price"); }
    show(px);
    let hw, hok = callable::tree_clean();
    if !hok { fail("tree"); }
    show(hw);
    let put, pok = callable::tree_put();
    if !pok { fail("put"); }
    show(put);
    let both, bok = callable::tree_both();
    if !bok { fail("both"); }
    show(both);
    write_stdout("callable bonds ok\n");
}
