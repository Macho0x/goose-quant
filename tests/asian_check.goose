import os;
import quant from "..";
import quant.black;
import quant.asian;

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
    // Haug pp. 96-97, testAnalyticContinuousGeometricAveragePrice.
    // Actual/360 from today to today+90 is 90/360. Put, tolerance 1e-4.
    let px, ok = asian::npv(black::PUT, 80.0, 85.0, 0.05, -0.03, 0.20, 90.0 / 360.0);
    if !ok || gap(px, 4.6922) > 1.0e-4 { fail("haug"); }
    write_stdout("asian ok\n");
}
