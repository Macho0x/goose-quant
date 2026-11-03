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
    write_stdout("market models ok\n");
}
