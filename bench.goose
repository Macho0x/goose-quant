// Times this package. One untimed batch, then batches until the window
// elapses. The sink keeps the call alive.
// Build with clang on the revision before a change, then again after:
//   goose build -o quant-bench bench.goose
//   ./quant-bench
// Row names stay fixed. TinyCC (goose bench.goose) is not a timing result.

import os;
import date;
import period;
import daycount;
import calendar;
import markets;
import black;
import curve;
import european;
import rate;

fn mark(n: i32) -> u64 {
    if n < 0 { return 0; }
    let v = n as u64;
    return v + 1;
}

fn time_batch<F>(batch: i64, ms: i64) -> i64, u64 {
    var sink: u64 = 0;
    var k = 0;
    while k < batch {
        sink += F();
        k += 1;
    }
    var n: i64 = 0;
    var dt: i64 = 0;
    let end = clock_ns() + ms * 1000000;
    while true {
        let t0 = clock_ns();
        k = 0;
        while k < batch {
            sink += F();
            k += 1;
        }
        dt += clock_ns() - t0;
        n += batch;
        if clock_ns() >= end { break; }
    }
    return dt / n, sink;
}

fn row<F>(name: u8[:], batch: i64, ms: i64) -> u64 {
    let ns, part = time_batch(batch, ms, F);
    var line: u8[>..] = [];
    format(line, name);
    while line.len < 28 { line.push(' '); }
    format_int(line, ns, 10, 12, ' ');
    format(line, "\n");
    write_stdout(line);
    return part;
}

fn act360_row() -> u64 {
    let a, aok = date::from_ymd(20, date::AUGUST, 2006);
    let b, bok = date::from_ymd(20, date::FEBRUARY, 2007);
    if !aok || !bok { return 0; }
    let yf, ok = daycount::year_fraction(daycount::actual360(), a, b, date::blank(), date::blank());
    if !ok { return 0; }
    return mark((yf * 360.0) as i32);
}

fn european_row() -> u64 {
    let px, ok = european::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    if !ok { return 0; }
    return mark((px * 10000.0) as i32);
}

fn black_row() -> u64 {
    let px, ok = black::black(black::CALL, 100.0, 100.0, 0.2, 1.0, 0.0);
    if !ok { return 0; }
    return mark((px * 1000.0) as i32);
}

fn flat_row() -> u64 {
    let df, ok = curve::flat_discount(0.05, rate::CONTINUOUS, 1, 1.0);
    if !ok { return 0; }
    return mark((df * 10000.0) as i32);
}

fn target_row() -> u64 {
    let start, ok = date::from_ymd(15, date::JANUARY, 2004);
    if !ok { return 0; }
    var hole: i32[1] = [0];
    let got, gok = calendar::advance(markets::TARGET, start, 1, period::YEARS, calendar::MODIFIED_FOLLOWING, false, hole[0..0], hole[0..0]);
    if !gok { return 0; }
    return mark(got.serial);
}

fn close(got: f64, want: f64) -> bool {
    var gap = got - want;
    if gap < 0.0 { gap = -gap; }
    return gap <= 1.0e-10;
}

fn ready() -> bool {
    let a, aok = date::from_ymd(20, date::AUGUST, 2006);
    let b, bok = date::from_ymd(20, date::FEBRUARY, 2007);
    if !aok || !bok { return false; }
    let yf, ok = daycount::year_fraction(daycount::actual360(), a, b, date::blank(), date::blank());
    if !ok { return false; }
    var gap = yf * 360.0 - date::days_between(a, b);
    if gap < 0.0 { gap = -gap; }
    if gap > 1.0e-9 { return false; }
    let start, sok = date::from_ymd(15, date::JANUARY, 2004);
    let want, wok = date::from_ymd(17, date::JANUARY, 2005);
    if !sok || !wok { return false; }
    var hole: i32[1] = [0];
    let got, gok = calendar::advance(markets::TARGET, start, 1, period::YEARS, calendar::MODIFIED_FOLLOWING, false, hole[0..0], hole[0..0]);
    if !gok || got.serial != want.serial { return false; }
    let df, dfok = curve::flat_discount(0.05, rate::CONTINUOUS, 1, 1.0);
    if !dfok || !close(df, 0.951229424500714) { return false; }
    let px, pxok = black::black(black::CALL, 100.0, 100.0, 0.2, 1.0, 0.0);
    if !pxok || !close(px, 7.965567455405804) { return false; }
    let eu, euok = european::npv(black::PUT, 36.0, 40.0, 0.06, 0.0, 0.20, 1.0);
    return euok && close(eu, 3.84430779159684);
}

fn ::main() {
    if !ready() { print("bench FAIL"); exit(1); }
    write_stdout("operation                       ns/call\n");
    var sink: u64 = 0;
    sink += row("actual/360 year fraction", 64, 200, act360_row);
    sink += row("target advance 1y", 64, 200, target_row);
    sink += row("flat discount factor", 64, 200, flat_row);
    sink += row("black formula", 64, 200, black_row);
    sink += row("european npv", 64, 200, european_row);
    var tail: u8[>..] = [];
    format(tail, "sink ");
    format(tail, sink);
    format(tail, "\n");
    write_stdout(tail);
}
