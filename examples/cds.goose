import os;
import math;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn show(label: u8[:], x: f64) {
    var line: u8[>..] = [];
    format(line, label);
    format(line, x);
    format(line, "\n");
    write_stdout(line);
}

fn ::main() {
    let spread = 0.0150;
    let recovery = 0.5;
    let hazard = spread / (1.0 - recovery);
    let one = exp(-hazard * 1.0);
    let two = exp(-hazard * 2.0);
    show("flat hazard: ", hazard);
    show("1Y survival probability: ", one);
    show("               expected: ", 0.9704);
    show("2Y survival probability: ", two);
    show("               expected: ", 0.9418);
    var d1 = one - 0.9704;
    if d1 < 0.0 { d1 = -d1; }
    var d2 = two - 0.9418;
    if d2 < 0.0 { d2 = -d2; }
    if hazard != 0.03 || d1 > 5.0e-4 || d2 > 5.0e-4 { fail("survival"); }
    write_stdout("cds ok\n");
}
