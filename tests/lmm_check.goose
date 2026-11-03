import os;
import quant from "..";
import quant.lmm;

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
    // testOneStepForwardsAndOptionlets, first caplet (i = 0).
    // forward = 0.03 + 0.0010 * i, displacement = 0, strike = forward.
    // vol = 0.15541283. Semiannual SimpleDayCounter, so expiry and
    // accrual are 1/2. Discount starts at 0.95.
    // BlackCalculator tolerance in that check is a Monte Carlo bound.
    // The price itself is the Black value, held to 1e-12.
    let forward = 0.03;
    let strike = forward;
    let vol = 0.15541283;
    let expiry = 0.5;
    let accrual = 0.5;
    let discount = 0.95 / (1.0 + forward * accrual);
    let displacement = 0.0;
    let px, ok = lmm::caplet(forward, strike, vol, expiry, discount, accrual, displacement);
    if !ok || gap(px, 0.0006151942533796) > 1.0e-12 { fail("caplet"); }
    write_stdout("lmm ok\n");
}
