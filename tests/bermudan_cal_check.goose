import os;
import quant from "..";
import quant.bermudan_cal;
import quant.hullwhite;
import quant.g2tree;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn gap(a: f64, b: f64) -> f64 {
    var d = a - b;
    if d < 0.0 { d = -d; }
    return d;
}

// calibrateModel's helper residual is the relative price error.
// The example's printed vol gaps are about one point on an 11-point vol.
const RESIDUAL: f64 = 0.15;

fn ::main() {
    let a, s, ok = bermudan_cal::calibrate_hw();
    if !ok { fail("hw"); }
    var i: i64 = 0;
    while i < 5 {
        let model, market, pok = bermudan_cal::hw_price(a, s, i);
        if !pok || market <= 0.0 || gap(model, market) > RESIDUAL * market { fail("hw price"); }
        i += 1;
    }
    let itm, iok = hullwhite::bermudan_at(0.8, a, s);
    let atm, aok = hullwhite::bermudan_at(1.0, a, s);
    let otm, ook = hullwhite::bermudan_at(1.2, a, s);
    if !iok || !aok || !ook || !(itm > atm && atm > otm && otm > 0.0) { fail("hw tree"); }

    let ga, gs, gb, ge, gr, gok = bermudan_cal::calibrate_g2();
    if !gok { fail("g2"); }
    i = 0;
    while i < 5 {
        let model, market, pok = bermudan_cal::g2_price(ga, gs, gb, ge, gr, i);
        if !pok || market <= 0.0 || gap(model, market) > RESIDUAL * market { fail("g2 price"); }
        i += 1;
    }
    let gitm, giok = g2tree::price_deal(0.8, 19, 2, 2002, ga, gs, gb, ge, gr);
    let gatm, gaok = g2tree::price_deal(1.0, 19, 2, 2002, ga, gs, gb, ge, gr);
    let gotm, gook = g2tree::price_deal(1.2, 19, 2, 2002, ga, gs, gb, ge, gr);
    if !giok || !gaok || !gook || !(gitm > gatm && gatm > gotm && gotm > 0.0) { fail("g2 tree"); }
    write_stdout("bermudan cal ok\n");
}
