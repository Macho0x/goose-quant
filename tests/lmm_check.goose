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
    // testOneStepForwardsAndOptionlets strikes the forward at the rate plus 0.01.
    // Seed 42, 32767 paths. The check allows 4 standard errors.
    let forward_strike = forward + 0.01;
    let mean_fwd, err_fwd, mean_call, err_call, pok = lmm::one_step(forward, forward_strike, vol, expiry, discount, accrual, displacement, 42, 32767);
    if !pok { fail("paths"); }
    let closed = (forward - forward_strike) * accrual * discount;
    if gap(mean_fwd, closed) > 4.0 * err_fwd { fail("forward"); }
    if gap(mean_call, px) > 4.0 * err_call { fail("optionlet"); }
    write_stdout("lmm ok\n");
}
