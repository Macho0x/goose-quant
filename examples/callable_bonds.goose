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
    write_stdout("callable bonds ok\n");
}
