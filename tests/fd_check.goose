import os;
import quant from "..";
import quant.black;
import quant.european;
import quant.fd;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    let analytic, aok = european::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    if !aok { fail("analytic"); }
    var stops: f64[4] = [92.0 / 365.0, 184.0 / 365.0, 276.0 / 365.0, 1.0];
    let euro, eok = fd::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 801, 800, fd::EUROPEAN, stops);
    let berm, bok = fd::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 801, 800, fd::BERMUDAN, stops);
    let amer, mok = fd::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0, 801, 800, fd::AMERICAN, stops);
    if !eok || !bok || !mok { fail("price"); }
    var gap = euro - analytic;
    if gap < 0.0 { gap = -gap; }
    if analytic <= 0.0 || gap / analytic >= 0.001 { fail("tol"); }
    if amer + 1.0e-8 < euro { fail("american"); }
    if berm + 1.0e-8 < euro || amer + 1.0e-8 < berm { fail("exercise"); }
    var line: u8[>..] = [];
    format(line, "European ");
    format(line, euro);
    format(line, "\nBermudan ");
    format(line, berm);
    format(line, "\nAmerican ");
    format(line, amer);
    format(line, "\nfd ok\n");
    write_stdout(line);
}
