import os;
import quant from "..";
import quant.hullwhite;
import quant.g2tree;
import quant.bermudan_cal;

fn ::main() {
    let quote = 94.0;
    let sigma = 0.015;
    let t = 5.0;
    let implied = (100.0 - quote) / 100.0;
    var maturity: f64[5] = [5.25, 5.25, 5.25, 5.001, 5.0];
    var reversion: f64[5] = [0.03, 1.0e-4, 0.0, 0.03, 0.03];
    var i = 0;
    while i < maturity.len {
        let bias, ok = hullwhite::convexity_bias(quote, t, maturity[i], sigma, reversion[i]);
        if !ok { exit(1); }
        var line: u8[>..] = [];
        format_flt(line, implied - bias, 7);
        format(line, "\n");
        write_stdout(line);
        i += 1;
    }
    let itm, iok = hullwhite::bermudan(0.8);
    let atm, aok = hullwhite::bermudan(1.0);
    let otm, ook = hullwhite::bermudan(1.2);
    if !iok || !aok || !ook { exit(1); }
    var price: u8[>..] = [];
    format_flt(price, itm, 6);
    format(price, "\n");
    format_flt(price, atm, 6);
    format(price, "\n");
    format_flt(price, otm, 6);
    format(price, "\n");
    write_stdout(price);
    var strike: f64[5] = [0.5, 0.75, 1.0, 1.25, 1.5];
    var g2: u8[>..] = [];
    var s = 0;
    while s < strike.len {
        let px, pok = g2tree::price(strike[s]);
        if !pok { exit(1); }
        format_flt(g2, px, 5);
        format(g2, "\n");
        s += 1;
    }
    write_stdout(g2);
    let ca, cs, cok = bermudan_cal::calibrate_hw();
    if !cok { exit(1); }
    var cal: u8[>..] = [];
    format(cal, ca);
    format(cal, " ");
    format(cal, cs);
    format(cal, "\n");
    let citm, ciok = hullwhite::bermudan_at(0.8, ca, cs);
    let catm, caok = hullwhite::bermudan_at(1.0, ca, cs);
    let cotm, cook = hullwhite::bermudan_at(1.2, ca, cs);
    if !ciok || !caok || !cook { exit(1); }
    format_flt(cal, citm, 6);
    format(cal, "\n");
    format_flt(cal, catm, 6);
    format(cal, "\n");
    format_flt(cal, cotm, 6);
    format(cal, "\n");
    let ga, gs, gb, ge, gr, gok = bermudan_cal::calibrate_g2();
    if !gok { exit(1); }
    format(cal, ga);
    format(cal, " ");
    format(cal, gs);
    format(cal, " ");
    format(cal, gb);
    format(cal, " ");
    format(cal, ge);
    format(cal, " ");
    format(cal, gr);
    format(cal, "\n");
    let gitm, giok = g2tree::price_deal(0.8, 19, 2, 2002, ga, gs, gb, ge, gr);
    let gatm, gaok = g2tree::price_deal(1.0, 19, 2, 2002, ga, gs, gb, ge, gr);
    let gotm, gook = g2tree::price_deal(1.2, 19, 2, 2002, ga, gs, gb, ge, gr);
    if !giok || !gaok || !gook { exit(1); }
    format_flt(cal, gitm, 6);
    format(cal, "\n");
    format_flt(cal, gatm, 6);
    format(cal, "\n");
    format_flt(cal, gotm, 6);
    format(cal, "\n");
    write_stdout(cal);
    write_stdout("bermudan ok\n");
}
