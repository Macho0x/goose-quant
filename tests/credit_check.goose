import os;
import quant from "..";
import quant.credit;
import quant.date;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn gap(got: f64, want: f64) -> f64 {
    var d = got - want;
    if d < 0.0 { d = -d; }
    return d;
}

fn ::main() {
    let curve, ok = credit::calibrate(0.0);
    if !ok { fail("bootstrap"); }
    var i: i64 = 0;
    while i < curve.n {
        if gap(curve.hazard[i], 0.03) > 1.0e-5 { fail("hazard"); }
        i += 1;
    }
    let today, tok = credit::market_date();
    if !tok { fail("date"); }
    let y1, y1ok = date::plus_years(today, 1);
    let y2, y2ok = date::plus_years(today, 2);
    if !y1ok || !y2ok { fail("tenor"); }
    let s1, s1ok = credit::survival(curve, y1);
    let s2, s2ok = credit::survival(curve, y2);
    if !s1ok || !s2ok { fail("survival"); }
    if gap(s1, 0.9704) > 5.0e-4 || gap(s2, 0.9418) > 5.0e-4 { fail("survival"); }
    let priced, pok = credit::calibrate(0.01);
    if !pok { fail("discount"); }
    let p1, p1ok = credit::survival(priced, y1);
    let p2, p2ok = credit::survival(priced, y2);
    if !p1ok || !p2ok { fail("discount"); }
    if gap(p1, 0.970400774686221) > 1.0e-12 || gap(p2, 0.9417579597268261) > 1.0e-12 { fail("priced"); }
    write_stdout("credit ok\n");
}
