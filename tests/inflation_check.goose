import os;
import quant from "..";
import quant.inflation;
import quant.date;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

// QL_CHECK_CLOSE: abs(got - want) <= abs(want) * tol / 100.
fn close_pct(got: f64, want: f64, tol: f64) -> bool {
    var diff = got - want;
    if diff < 0.0 { diff = -diff; }
    var scale = want;
    if scale < 0.0 { scale = -scale; }
    return diff <= scale * tol / 100.0;
}

fn ymd(day: i32, m: i32, y: i32) -> date::Date {
    let d, ok = date::from_ymd(day, m, y);
    if !ok { fail("ymd"); }
    return d;
}

fn ::main() {
    var fixings: inflation::Fix[5] = [
        inflation::Fix { on: ymd(1, date::NOVEMBER, 2020), value: 293.5 },
        inflation::Fix { on: ymd(1, date::DECEMBER, 2020), value: 295.4 },
        inflation::Fix { on: ymd(1, date::JANUARY, 2021), value: 294.6 },
        inflation::Fix { on: ymd(1, date::FEBRUARY, 2021), value: 296.0 },
        inflation::Fix { on: ymd(1, date::MARCH, 2021), value: 296.9 },
    ];
    let feb, fok = inflation::lagged_fixing(fixings, ymd(10, date::FEBRUARY, 2021), 3);
    if !fok || !close_pct(feb, 293.5, 1.0e-8) { fail("february"); }
    let may, mok = inflation::lagged_fixing(fixings, ymd(12, date::MAY, 2021), 3);
    if !mok || !close_pct(may, 296.0, 1.0e-8) { fail("may"); }
    let june, jok = inflation::lagged_fixing(fixings, ymd(25, date::JUNE, 2021), 3);
    if !jok || !close_pct(june, 296.9, 1.0e-8) { fail("june"); }

    let lin_feb = 293.5 * (19.0 / 28.0) + 295.4 * (9.0 / 28.0);
    let got_feb, lfok = inflation::linear_fixing(fixings, ymd(10, date::FEBRUARY, 2021), 3);
    if !lfok || !close_pct(got_feb, lin_feb, 1.0e-8) { fail("linear february"); }
    let lin_may = 296.0 * (20.0 / 31.0) + 296.9 * (11.0 / 31.0);
    let got_may, lmok = inflation::linear_fixing(fixings, ymd(12, date::MAY, 2021), 3);
    if !lmok || !close_pct(got_may, lin_may, 1.0e-8) { fail("linear may"); }
    let first, firstok = inflation::linear_fixing(fixings, ymd(1, date::JUNE, 2021), 3);
    if !firstok || !close_pct(first, 296.9, 1.0e-8) { fail("linear first"); }
    let missing, miss = inflation::linear_fixing(fixings, ymd(25, date::JUNE, 2021), 3);
    if miss || missing != 0.0 { fail("linear missing"); }
    write_stdout("inflation ok\n");
}
