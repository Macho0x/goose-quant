import os;
import math;
import quant from "..";
import quant.date;
import quant.period;
import quant.black;
import quant.european;
import quant.barrier;
import quant.normal;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn year(a: i32, b: i32) -> f64 {
    return (b - a) / 365.0;
}

fn vanilla(spot: f64, strike: f64, eval: i32, maturity: i32, r: f64, vol: f64) -> f64, bool {
    if maturity <= eval { return 0.0, true; }
    return european::npv(black::PUT, spot, strike, r, 0.0, vol, year(eval, maturity));
}

fn digital(spot: f64, strike: f64, cash: f64, eval: i32, maturity: i32, r: f64, vol: f64) -> f64, bool {
    if maturity <= eval { return 0.0, true; }
    let t = year(eval, maturity);
    if spot <= 0.0 || strike <= 0.0 || vol < 0.0 { return 0.0, false; }
    let df = exp(-r * t);
    let forward = spot * exp(r * t);
    let std = vol * sqrt(t);
    if std == 0.0 {
        if forward < strike { return df * cash, true; }
        return 0.0, true;
    }
    let d2 = log(forward / strike) / std - 0.5 * std;
    return df * cash * normal::cdf(-d2), true;
}

fn book(spot: f64, eval: i32, r: f64, vol: f64, kind: i32[:], strike: f64[:], cash: f64[:], maturity: i32[:], notional: f64[:]) -> f64, bool {
    var sum = 0.0;
    var i: i64 = 0;
    while i < kind.len {
        var px = 0.0;
        var ok = true;
        if kind[i] == 0 {
            px, ok = vanilla(spot, strike[i], eval, maturity[i], r, vol);
        } else {
            px, ok = digital(spot, strike[i], cash[i], eval, maturity[i], r, vol);
        }
        if !ok { return 0.0, false; }
        sum += notional[i] * px;
        i += 1;
    }
    return sum, true;
}

fn push(kind: i32[>..]&, strike: f64[>..]&, cash: f64[>..]&, maturity: i32[>..]&, notional: f64[>..]&, k: i32, s: f64, c: f64, m: i32, n: f64) {
    kind.push(k);
    strike.push(s);
    cash.push(c);
    maturity.push(m);
    notional.push(n);
}

fn kill(today: date::Date, step: i32, unit: i32, count: i32, barrier: f64, r: f64, vol: f64, kind: i32[>..]&, strike: f64[>..]&, cash: f64[>..]&, maturity: i32[>..]&, notional: f64[>..]&) -> bool {
    var i = count;
    while i >= 1 {
        let inner, iok = date::advance(today, i * step, unit);
        let when, wok = date::advance(today, (i - 1) * step, unit);
        if !iok || !wok { return false; }
        let portfolio, pok = book(barrier, when.serial, r, vol, kind, strike, cash, maturity, notional);
        let hedge, hok = vanilla(barrier, barrier, when.serial, inner.serial, r, vol);
        if !pok || !hok || hedge == 0.0 { return false; }
        push(kind, strike, cash, maturity, notional, 0, barrier, 0.0, inner.serial, -(portfolio / hedge));
        i -= 1;
    }
    return true;
}

fn show(label: u8[:], value: f64, err: f64) {
    var line: u8[>..] = [];
    format(line, label);
    format(line, " ");
    format(line, value);
    format(line, " ");
    format(line, err);
    format(line, "\n");
    write_stdout(line);
}

fn scene(spot: f64, today: i32, maturity: i32, r: f64, vol: f64, barrier: f64, a: i32[:], b: i32[:], c: i32[:], ak: i32[:], bk: i32[:], ck: i32[:], as_: f64[:], bs: f64[:], cs: f64[:], ac: f64[:], bc: f64[:], cc: f64[:], an: f64[:], bn: f64[:], cn: f64[:]) -> f64, f64, f64, bool {
    let reference, rok = barrier::npv(black::PUT, barrier::DOWN_OUT, barrier, 0.0, spot, 100.0, r, 0.0, vol, year(today, maturity));
    let p1, aok = book(spot, today, r, vol, ak, as_, ac, a, an);
    let p2, bok = book(spot, today, r, vol, bk, bs, bc, b, bn);
    let p3, cok = book(spot, today, r, vol, ck, cs, cc, c, cn);
    if !rok || !aok || !bok || !cok { return 0.0, 0.0, 0.0, false; }
    show("Original barrier option", reference, 0.0);
    show("Replicating portfolio (12 dates)", p1, p1 - reference);
    show("Replicating portfolio (26 dates)", p2, p2 - reference);
    show("Replicating portfolio (52 dates)", p3, p3 - reference);
    return p1 - reference, p2 - reference, p3 - reference, true;
}

fn ::main() {
    let today, tok = date::from_ymd(29, date::MAY, 2006);
    let maturity, mok = date::advance(today, 1, period::YEARS);
    if !tok || !mok { fail("dates"); }
    let r = 0.04;
    let vol = 0.20;
    let h = 70.0;
    var ak: i32[>..] = [];
    var bk: i32[>..] = [];
    var ck: i32[>..] = [];
    var as_: f64[>..] = [];
    var bs: f64[>..] = [];
    var cs: f64[>..] = [];
    var ac: f64[>..] = [];
    var bc: f64[>..] = [];
    var cc: f64[>..] = [];
    var am: i32[>..] = [];
    var bm: i32[>..] = [];
    var cm: i32[>..] = [];
    var an: f64[>..] = [];
    var bn: f64[>..] = [];
    var cn: f64[>..] = [];
    push(ak, as_, ac, am, an, 0, 100.0, 0.0, maturity.serial, 1.0);
    push(ak, as_, ac, am, an, 1, h, 1.0, maturity.serial, -(100.0 - h));
    push(ak, as_, ac, am, an, 0, h, 0.0, maturity.serial, -1.0);
    push(bk, bs, bc, bm, bn, 0, 100.0, 0.0, maturity.serial, 1.0);
    push(bk, bs, bc, bm, bn, 1, h, 1.0, maturity.serial, -(100.0 - h));
    push(bk, bs, bc, bm, bn, 0, h, 0.0, maturity.serial, -1.0);
    push(ck, cs, cc, cm, cn, 0, 100.0, 0.0, maturity.serial, 1.0);
    push(ck, cs, cc, cm, cn, 1, h, 1.0, maturity.serial, -(100.0 - h));
    push(ck, cs, cc, cm, cn, 0, h, 0.0, maturity.serial, -1.0);
    if !kill(today, 1, period::MONTHS, 12, h, r, vol, ak, as_, ac, am, an) { fail("12"); }
    if !kill(today, 2, period::WEEKS, 26, h, r, vol, bk, bs, bc, bm, bn) { fail("26"); }
    if !kill(today, 1, period::WEEKS, 52, h, r, vol, ck, cs, cc, cm, cn) { fail("52"); }

    write_stdout("Initial market conditions\n");
    let e1, e2, e3, ok = scene(100.0, today.serial, maturity.serial, r, vol, h, am, bm, cm, ak, bk, ck, as_, bs, cs, ac, bc, cc, an, bn, cn);
    if !ok { fail("spot 100"); }
    write_stdout("Modified market conditions: out of the money\n");
    let f1, f2, f3, ok2 = scene(110.0, today.serial, maturity.serial, r, vol, h, am, bm, cm, ak, bk, ck, as_, bs, cs, ac, bc, cc, an, bn, cn);
    if !ok2 { fail("spot 110"); }
    write_stdout("Modified market conditions: in the money\n");
    let g1, g2, g3, ok3 = scene(90.0, today.serial, maturity.serial, r, vol, h, am, bm, cm, ak, bk, ck, as_, bs, cs, ac, bc, cc, an, bn, cn);
    if !ok3 { fail("spot 90"); }
    var a1 = e1;
    if a1 < 0.0 { a1 = -a1; }
    var a3 = e3;
    if a3 < 0.0 { a3 = -a3; }
    if a3 >= a1 { fail("tighter"); }
    var b1 = f1;
    if b1 < 0.0 { b1 = -b1; }
    var b3 = f3;
    if b3 < 0.0 { b3 = -b3; }
    if b3 >= b1 { fail("tighter otm"); }
    var c1 = g1;
    if c1 < 0.0 { c1 = -c1; }
    var c3 = g3;
    if c3 < 0.0 { c3 = -c3; }
    if c3 >= c1 { fail("tighter itm"); }
    write_stdout("replication ok\n");
}
