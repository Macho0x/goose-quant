import os;
import quant from "..";
import quant.black;
import quant.european;
import quant.barrier;

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

fn parity(option: i32, h: f64, spot: f64, strike: f64) {
    let van, vok = european::npv(option, spot, strike, 0.04, 0.0, 0.20, 1.0);
    let kin = barrier::DOWN_IN;
    let kout = barrier::DOWN_OUT;
    let inn, iok = barrier::npv(option, kin, h, 0.0, spot, strike, 0.04, 0.0, 0.20, 1.0);
    let out, ook = barrier::npv(option, kout, h, 0.0, spot, strike, 0.04, 0.0, 0.20, 1.0);
    if !vok || !iok || !ook { fail("parity"); }
    if gap(inn + out, van) > 1.0e-10 { fail("in-out"); }
}

fn ::main() {
    parity(black::PUT, 70.0, 100.0, 100.0);
    parity(black::CALL, 70.0, 100.0, 100.0);
    parity(black::PUT, 70.0, 100.0, 60.0);
    parity(black::CALL, 90.0, 100.0, 80.0);
    let up_in, a = barrier::npv(black::CALL, barrier::UP_IN, 120.0, 0.0, 100.0, 100.0, 0.05, 0.02, 0.25, 0.75);
    let up_out, b = barrier::npv(black::CALL, barrier::UP_OUT, 120.0, 0.0, 100.0, 100.0, 0.05, 0.02, 0.25, 0.75);
    let van, c = european::npv(black::CALL, 100.0, 100.0, 0.05, 0.02, 0.25, 0.75);
    if !a || !b || !c || gap(up_in + up_out, van) > 1.0e-10 { fail("up parity"); }
    let deep, dok = barrier::npv(black::PUT, barrier::DOWN_OUT, 1.0, 0.0, 100.0, 100.0, 0.04, 0.0, 0.20, 1.0);
    let plain, pok = european::npv(black::PUT, 100.0, 100.0, 0.04, 0.0, 0.20, 1.0);
    if !dok || !pok || gap(deep, plain) > 1.0e-8 { fail("deep"); }
    write_stdout("barrier ok\n");
}
