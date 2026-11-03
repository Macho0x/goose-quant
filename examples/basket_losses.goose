import os;
import quant from "..";
import quant.basket;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    let loss, ok = basket::five_year_loss();
    if !ok { fail("loss"); }
    var line: u8[>..] = [];
    format(line, loss);
    format(line, "\n");
    write_stdout(line);
    write_stdout("basket losses ok\n");
}
