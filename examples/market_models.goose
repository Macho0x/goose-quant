import os;
import quant from "..";
import quant.lmm;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    let forward = 0.03;
    let strike = forward;
    let vol = 0.15541283;
    let expiry = 0.5;
    let accrual = 0.5;
    let discount = 0.95 / (1.0 + forward * accrual);
    let px, ok = lmm::caplet(forward, strike, vol, expiry, discount, accrual, 0.0);
    if !ok { fail("caplet"); }
    var line: u8[>..] = [];
    format(line, "caplet ");
    format(line, px);
    format(line, "\n");
    write_stdout(line);
    var d = px - 0.0006151942533796;
    if d < 0.0 { d = -d; }
    if d > 1.0e-12 { fail("caplet"); }
    let mean_fwd, err_fwd, mean_call, err_call, pok = lmm::one_step_rates(42, 32767);
    if !pok { fail("paths"); }
    var i: i64 = 0;
    while i < 9 {
        line.clear();
        format(line, mean_call[i]);
        format(line, "\n");
        write_stdout(line);
        i += 1;
    }
    var spot = 0.95;
    i = 0;
    while i < 9 {
        let f = 0.03 + 0.0010 * (i as f64);
        let payment = spot / (1.0 + f * accrual);
        let t = accrual * ((i + 1) as f64);
        let black_px, bok = lmm::caplet(f, f, lmm::MKT_VOL[i], t, payment, accrual, 0.0);
        if !bok { fail("caplet"); }
        let closed = (f - (f + 0.01)) * accrual * payment;
        var df = mean_fwd[i] - closed;
        if df < 0.0 { df = -df; }
        if df > 4.0 * err_fwd[i] { fail("forward"); }
        var dc = mean_call[i] - black_px;
        if dc < 0.0 { dc = -dc; }
        if dc > 4.0 * err_call[i] { fail("optionlet"); }
        spot = payment;
        i += 1;
    }
    write_stdout("market models ok\n");
}
