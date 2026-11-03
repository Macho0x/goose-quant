import os;
import quant from "..";
import quant.black;
import quant.date;
import quant.daycount;
import quant.european;
import quant.heston;
import quant.bates;

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

fn ::main() {
    let euro, eok = european::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    if !eok { fail("european"); }
    let h, hok = heston::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.04, 1.0, 0.04, 0.001, 0.0, 1.0);
    if !hok { fail("heston"); }
    let b, bok = bates::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.04, 1.0, 0.04, 0.001, 0.0, 1.0e-14, 1.0e-14, 1.0e-14, 1.0);
    if !bok { fail("bates"); }

    var line: u8[>..] = [];
    format(line, h);
    format(line, "\n");
    format(line, b);
    format(line, "\n");
    write_stdout(line);

    if gap(h, euro) >= 1.0e-3 { fail("heston bs"); }
    if gap(b, h) >= 1.0e-3 { fail("bates heston"); }

    // test-suite testAllIntegrationMethods, angled contour and Gatheral,
    // Gauss-Laguerre. Tolerance 1e-8. Expected 10.147041515497.
    let suite, sok = heston::npv(black::PUT, 100.0, 100.0, 0.05, 0.075, 0.1, 4.0, 0.05, 0.4, -0.75, 1.0);
    if !sok || gap(suite, 10.147041515497) > 1.0e-8 { fail("angled"); }
    let plain, pok = bates::npv(black::PUT, 100.0, 100.0, 0.05, 0.075, 0.1, 4.0, 0.05, 0.4, -0.75, 0.0, 0.0, 0.0, 1.0);
    if !pok || gap(plain, 10.147041515497) > 1.0e-8 { fail("gatheral"); }

    // testAnalyticVsCached, AnalyticHestonEngine price 0.0404774515,
    // tolerance 1e-8. Actual/Actual ISDA, 27 Dec 2004 to 28 Mar 2005.
    let d1, ok1 = date::from_ymd(27, date::DECEMBER, 2004);
    let d2, ok2 = date::from_ymd(28, date::MARCH, 2005);
    if !ok1 || !ok2 { fail("date"); }
    let blank = date::blank();
    let t, tok = daycount::year_fraction(daycount::actual_actual_isda(), d1, d2, blank, blank);
    if !tok { fail("year"); }
    let cached, cok = heston::npv(black::CALL, 1.0, 1.05, 0.0225, 0.02, 0.1, 3.16, 0.09, 0.4, -0.2, t);
    if !cok || gap(cached, 0.0404774515) > 1.0e-8 { fail("cached"); }

    write_stdout("heston ok\n");
}
