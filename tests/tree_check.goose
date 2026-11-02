import os;
import quant from "..";
import quant.black;
import quant.european;
import quant.tree;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn near(px: f64, analytic: f64) -> bool {
    var d = px - analytic;
    if d < 0.0 { d = -d; }
    return d < 0.05;
}

fn ::main() {
    let analytic, aok = european::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    let coarse, cok = tree::crr(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 51, false);
    let fine, fok = tree::crr(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 801, false);
    let american, mok = tree::crr(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 801, true);
    if !aok || !cok || !fok || !mok { fail("price"); }
    var close = fine - analytic;
    if close < 0.0 { close = -close; }
    var far = coarse - analytic;
    if far < 0.0 { far = -far; }
    if close > 0.01 || close >= far { fail("converge"); }
    if american + 1.0e-10 < fine { fail("american"); }
    var stops: f64[4] = [0.25205479452054796, 0.5041095890410959, 0.7561643835616438, 1.0];
    let euro, eok = tree::jr(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 201, tree::EUROPEAN, stops);
    let berm, bok = tree::jr(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 201, tree::BERMUDAN, stops);
    let amer, uok = tree::jr(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 201, tree::AMERICAN, stops);
    if !eok || !bok || !uok || !near(euro, analytic) { fail("jr"); }
    if berm + 1.0e-8 < euro || amer + 1.0e-8 < berm { fail("jr exercise"); }
    let add, dok = tree::additive(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 201, tree::EUROPEAN, stops);
    let tri, tok = tree::trigeorgis(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 201, tree::EUROPEAN, stops);
    let tian, nok = tree::tian(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 201, tree::EUROPEAN, stops);
    let lei, lok = tree::leisen(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 201, tree::EUROPEAN, stops);
    let jos, jok = tree::joshi(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 201, tree::EUROPEAN, stops);
    if !dok || !tok || !nok || !lok || !jok { fail("tree"); }
    if !near(add, analytic) || !near(tri, analytic) || !near(tian, analytic) || !near(lei, analytic) || !near(jos, analytic) { fail("level"); }
    var line: u8[>..] = [];
    format(line, "crr 801 ");
    format(line, fine);
    format(line, "\namerican 801 ");
    format(line, american);
    format(line, "\ntree ok\n");
    write_stdout(line);
}
