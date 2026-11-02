import os;
import quant from "..";
import quant.bjerk;
import quant.black;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    // type, strike, spot, q, r, t, vol, value
    var kind: i32[8] = [
        black::CALL, black::PUT, black::CALL, black::CALL,
        black::CALL, black::CALL, black::PUT, black::PUT
    ];
    var strike: f64[8] = [40.00, 40.00, 100.0, 100.0, 100.0, 100.0, 110.0, 100.0];
    var spot: f64[8] = [42.00, 36.00, 100.0, 100.0, 99.99, 110.0, 100.0, 110.0];
    var q: f64[8] = [0.08, 0.00, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05];
    var r: f64[8] = [0.04, 0.06, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05];
    var t: f64[8] = [0.75, 1.00, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0];
    var vol: f64[8] = [0.35, 0.20, 0.0021, 0.0001, 0.0001, 0.0001, 0.0001, 10.0];
    var want: f64[8] = [5.2704, 4.4531, 0.08032314, 0.003860656, 0.00081, 10.0, 10.0, 99.20350];
    var i: i64 = 0;
    while i < kind.len {
        let px, ok = bjerk::npv(kind[i], spot[i], strike[i], r[i], q[i], vol[i], t[i]);
        if !ok { fail("price"); }
        var gap = px - want[i];
        if gap < 0.0 { gap = -gap; }
        if gap > 5.0e-5 {
            var line: u8[>..] = [];
            format(line, "row ");
            format(line, i);
            format(line, " got ");
            format(line, px);
            format(line, " want ");
            format(line, want[i]);
            format(line, "\n");
            write_stdout(line);
            exit(1);
        }
        i += 1;
    }
    write_stdout("bjerk ok\n");
}
