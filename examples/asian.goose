import os;
import quant from "..";
import quant.date;
import quant.daycount;
import quant.black;
import quant.asian;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn label(out: u8[>..]&, name: u8[:], width: i64) {
    format(out, name);
    var i = name.len;
    while i < width {
        format(out, " ");
        i += 1;
    }
}

fn fixed6(out: u8[>..]&, x: f64) {
    var v = x;
    var sign = 0;
    if v < 0.0 {
        v = -v;
        sign = 1;
    }
    let scaled = (v * 1000000.0 + 0.5) as i64;
    let whole = scaled / 1000000;
    let frac = scaled % 1000000;
    if sign == 1 { format(out, "-"); }
    format_int(out, whole, 10, 1, '0');
    format(out, ".");
    format_int(out, frac, 10, 6, '0');
    var digits = 0;
    var w = whole;
    if w == 0 { digits = 1; }
    while w > 0 {
        digits += 1;
        w = w / 10;
    }
    var width = sign + digits + 7;
    while width < 16 {
        format(out, " ");
        width += 1;
    }
}

fn ::main() {
    let settlement, sok = date::from_ymd(17, date::NOVEMBER, 2025);
    let maturity, mok = date::from_ymd(17, date::NOVEMBER, 2026);
    if !sok || !mok { fail("date"); }
    let dc = daycount::actual365_fixed();
    let t, tok = daycount::year_fraction(dc, settlement, maturity, date::blank(), date::blank());
    if !tok || t <= 0.0 { fail("time"); }
    let px, ok = asian::npv(black::PUT, 100.0, 100.0, 0.06, 0.03, 0.20, t);
    if !ok { fail("asian"); }
    var line: u8[>..] = [];
    format(line, "\n");
    format(line, "CONTINUOUS AVERAGING - GEOMETRIC AVERAGE\n");
    format(line, "========================================\n");
    label(line, "Analytic (Continuous Geometric)", 40);
    fixed6(line, px);
    format(line, "\n");
    write_stdout(line);
}
