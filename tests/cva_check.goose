import os;
import math;
import quant from "..";
import quant.cva;

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
    let par, pok = cva::fair(5);
    if !pok || gap(par, 0.03249) > 1.0e-8 { fail("par"); }

    var zero_h: f64[10] = [0.0; 10];
    let zero, zok = cva::amount(5, zero_h, cva::RECOVERY_LOW);
    if !zok || zero != 0.0 { fail("zero"); }

    let h = cva::LOW[0];
    var flat: f64[10] = [0.0; 10];
    var i: i64 = 0;
    while i < 10 {
        flat[i] = h;
        i += 1;
    }
    let got, gok = cva::amount(5, flat, cva::RECOVERY_LOW);
    if !gok { fail("flat"); }

    var epe: f64[160] = [0.0; 160];
    var t_lo: f64[160] = [0.0; 160];
    var t_hi: f64[160] = [0.0; 160];
    let n, nok = cva::exposure(5, epe, t_lo, t_hi);
    if !nok || n <= 0 { fail("exposure"); }
    let lgd = 1.0 - cva::RECOVERY_LOW;
    var sum = 0.0;
    i = 0;
    while i < n {
        let s0 = exp(-h * t_lo[i]);
        let s1 = exp(-h * t_hi[i]);
        sum += epe[i] * (s0 - s1) * lgd;
        i += 1;
    }
    if got != sum { fail("sum"); }
    if !(got > 0.0) { fail("payer"); }
    write_stdout("cva ok\n");
}
