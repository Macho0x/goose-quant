import os;
import math;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn f(x: f64) -> f64 {
    return exp(-x * x) * cos(x);
}

fn trap(a: f64, b: f64, n: i32) -> f64 {
    let h = (b - a) / n;
    var sum = 0.5 * (f(a) + f(b));
    var i: i32 = 1;
    while i < n {
        sum += f(a + i * h);
        i += 1;
    }
    return sum * h;
}

fn refine(a: f64, b: f64) -> f64 {
    var n: i32 = 4;
    var value = trap(a, b, n);
    var step: i32 = 0;
    while step < 14 {
        n *= 2;
        let next = trap(a, b, n);
        var change = next - value;
        if change < 0.0 { change = -change; }
        value = next;
        if change < 1.0e-10 { return value; }
        step += 1;
    }
    return value;
}

fn ::main() {
    let exact = pow(exp(-0.25) * sqrt(PI), 3.0);
    let grid = pow(refine(-4.0, 4.0), 3.0);
    let quad = pow(refine(-8.0, 8.0), 3.0);
    var line: u8[>..] = [];
    format(line, "Exact: ");
    format(line, exact);
    format(line, "\nQuad: ");
    format(line, quad);
    format(line, "\nGrid: ");
    format(line, grid);
    format(line, "\n");
    write_stdout(line);
    var err = grid - exact;
    if err < 0.0 { err = -err; }
    var qerr = quad - exact;
    if qerr < 0.0 { qerr = -qerr; }
    if err > 5.0e-5 || qerr > 5.0e-5 { fail("grid"); }
    write_stdout("integral ok\n");
}
