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

    // Every forward in setup(). Rate 0 repeats the call above.
    let rates_fwd, rates_ferr, rates_call, rates_cerr, rok = lmm::one_step_rates(42, 32767);
    if !rok { fail("rates"); }
    if rates_fwd[0] != mean_fwd || rates_ferr[0] != err_fwd || rates_call[0] != mean_call || rates_cerr[0] != err_call {
        fail("first");
    }
    let vol: f64[9] = [
        0.15541283,
        0.18719678,
        0.20890740,
        0.22318179,
        0.23212717,
        0.23731450,
        0.23988649,
        0.24066384,
        0.24023111,
    ];
    var spot = 0.95;
    var i: i64 = 0;
    while i < 9 {
        let f = 0.03 + 0.0010 * (i as f64);
        let payment = spot / (1.0 + f * accrual);
        let expiry = accrual * ((i + 1) as f64);
        let black_px, bok = lmm::caplet(f, f, vol[i], expiry, payment, accrual, displacement);
        if !bok { fail("caplet"); }
        if i == 0 && gap(black_px, 0.0006151942533796) > 1.0e-12 { fail("caplet"); }
        let closed_i = (f - (f + 0.01)) * accrual * payment;
        if gap(rates_fwd[i], closed_i) > 4.0 * rates_ferr[i] { fail("forward"); }
        if gap(rates_call[i], black_px) > 4.0 * rates_cerr[i] { fail("optionlet"); }
        spot = payment;
        i += 1;
    }
    write_stdout("lmm ok\n");
}
