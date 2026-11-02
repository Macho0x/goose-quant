import os;
import quant from "..";
import quant.fitted;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    let today, ok = fitted::example_date();
    if !ok { fail("today"); }
    let report, rok = fitted::splines(today);
    if !rok { fail("fit"); }
    var out: u8[>..] = [];
    fitted::format_report(out, report);
    write_stdout(out);
}
