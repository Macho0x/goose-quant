import os;
import quant from "..";
import quant.fitted;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn milli(x: f64) -> i64 {
    if x >= 0.0 { return (x * 1000.0 + 0.5) as i64; }
    return (x * 1000.0 - 0.5) as i64;
}

fn ::main() {
    let today, ok = fitted::example_date();
    if !ok { fail("today"); }
    let report, rok = fitted::splines(today);
    if !rok { fail("fit"); }
    var out: u8[>..] = [];
    fitted::format_report(out, report);
    var i: i64 = 0;
    while i < 15 {
        var err = report.clean[i] - report.quote[i];
        if err < 0.0 { err = -err; }
        // The example prints par rates to 3 decimals and says they equal the
        // coupons. The spline's clean prices stay inside a cent of quote 100.
        if err > 1.0e-2 || milli(report.par[i]) != milli(report.coupon[i]) {
            format(out, "reprice ");
            format(out, report.clean[i]);
            format(out, " par ");
            format(out, report.par[i]);
            format(out, "\n");
            write_stdout(out);
            exit(1);
        }
        i += 1;
    }
    format(out, "fitted ok\n");
    write_stdout(out);
}
