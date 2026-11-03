import os;
import math;
import quant from "..";
import quant.date;
import quant.daycount;
import quant.rate;
import quant.curve;
import quant.cash;
import quant.cashflow;

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

fn expect_duration(r: f64, compounding: i32) -> f64 {
    let first = 180.0 / 365.0;
    let second = 300.0 / 365.0;
    let t2 = first + second;
    var df1 = 0.0;
    var df2 = 0.0;
    if compounding == rate::CONTINUOUS {
        df1 = exp(-r * first);
        df2 = exp(-r * t2);
    } else if compounding == rate::SIMPLE {
        df1 = 1.0 / (1.0 + r * first);
        df2 = df1 / (1.0 + r * second);
    } else if compounding == rate::SIMPLE_THEN_COMPOUNDED {
        df1 = 1.0 / (1.0 + r * first);
        df2 = df1 * pow(1.0 + r / 2.0, -2.0 * second);
    } else if compounding == rate::COMPOUNDED_THEN_SIMPLE {
        df1 = pow(1.0 + r / 2.0, -2.0 * first);
        df2 = df1 / (1.0 + r * second);
    } else {
        df1 = pow(1.0 + r / 2.0, -2.0 * first);
        df2 = df1 * pow(1.0 + r / 2.0, -2.0 * second);
    }
    return (first * 40.0 * df1 + t2 * 70.0 * df2) / (40.0 * df1 + 70.0 * df2);
}

fn ::main() {
    var rates: f64[3] = [-0.02, 0.0, 0.05];
    var comps: i32[5] = [rate::SIMPLE, rate::COMPOUNDED, rate::CONTINUOUS, rate::SIMPLE_THEN_COMPOUNDED, rate::COMPOUNDED_THEN_SIMPLE];
    var times: f64[2] = [180.0 / 365.0, 480.0 / 365.0];
    var amounts: f64[2] = [40.0, 70.0];
    var i: i64 = 0;
    while i < 3 {
        var j: i64 = 0;
        while j < 5 {
            let got, ok = cashflow::simple_duration(times, amounts, rates[i], comps[j], 2);
            if !ok || gap(got, expect_duration(rates[i], comps[j])) > 1.0e-12 { fail("duration"); }
            j += 1;
        }
        i += 1;
    }
    var none: f64[0] = [];
    let empty, eok = cashflow::duration(none, none, 0.04, rate::COMPOUNDED, 1, cashflow::MACAULAY);
    if !eok || empty != 0.0 { fail("empty"); }
    var zero_t: f64[1] = [1.0];
    var zero_a: f64[1] = [0.0];
    let zdur, zok = cashflow::duration(zero_t, zero_a, 0.04, rate::COMPOUNDED, 1, cashflow::MODIFIED);
    let zconv, cok = cashflow::convexity(zero_t, zero_a, 0.04, rate::COMPOUNDED, 1);
    let zbpv, bok = cashflow::basis_point_value(zero_t, zero_a, 0.04, rate::COMPOUNDED, 1);
    if !zok || !cok || !bok || zdur != 0.0 || zconv != 0.0 || zbpv != 0.0 { fail("zero"); }
    var cancel_t: f64[2] = [1.0, 1.0];
    var cancel_a: f64[2] = [100.0, -100.0];
    let cdur, cdk = cashflow::simple_duration(cancel_t, cancel_a, 0.0, rate::COMPOUNDED, 1);
    if !cdk || cdur != 0.0 { fail("cancel"); }

    var k: i64 = 1;
    while k < 4 {
        let r = k / 100.0;
        let base, a = curve::flat_discount(r, rate::CONTINUOUS, 0, 3.0);
        let full, b = curve::flat_discount(r, rate::CONTINUOUS, 0, 8.0);
        let implied, c = curve::implied_discount(r, rate::CONTINUOUS, 0, 3.0, 8.0);
        if !a || !b || !c || gap(full, base * implied) > 1.0e-10 { fail("implied"); }
        k += 1;
    }
    let spreaded, sok = curve::zero_spreaded_discount(0.05, 0.01, 5.0);
    if !sok || gap(spreaded, exp(-0.06 * 5.0)) > 1.0e-10 { fail("zspread"); }
    let aug30, a30 = date::from_ymd(30, date::AUGUST, 2023);
    let aug31, a31 = date::from_ymd(31, date::AUGUST, 2023);
    if !a30 || !a31 { fail("date"); }
    let z0, zok = curve::flat_continuous_zero(0.02, daycount::thirty360_bond(), aug30, aug31);
    if !zok || gap(z0, 0.02) > 1.0e-10 { fail("null time"); }

    let settle, setok = date::from_ymd(15, date::JANUARY, 2024);
    if !setok { fail("settle"); }
    let pay = settle.serial + 365;
    var flows: i32[4] = [settle.serial - 1, settle.serial, pay, pay];
    var amts: f64[4] = [20.0, 3.0, 5.0, 100.0];
    let off, offok = cash::leg_npv(flows, amts, settle.serial, false, 0.04, rate::CONTINUOUS, 1, daycount::actual365_fixed());
    let on, onok = cash::leg_npv(flows, amts, settle.serial, true, 0.04, rate::CONTINUOUS, 1, daycount::actual365_fixed());
    let df = exp(-0.04);
    if !offok || !onok || gap(off, 105.0 * df) > 1.0e-12 || gap(on, 105.0 * df + 3.0) > 1.0e-12 { fail("leg"); }
    var is_cp: bool[4] = [false, false, true, false];
    var noms: f64[4] = [0.0, 0.0, 100.0, 0.0];
    var accs: f64[4] = [0.0, 0.0, 1.0, 0.0];
    let bp, bpok = cash::leg_bps(flows, is_cp, noms, accs, settle.serial, 0.04, rate::CONTINUOUS, 1, daycount::actual365_fixed());
    if !bpok || gap(bp, 0.01 * df) > 1.0e-12 { fail("bps"); }

    let coupon_day, cok2 = date::from_ymd(3, date::JANUARY, 2024);
    if !cok2 { fail("coupon date"); }
    var cp_pay: i32[4] = [coupon_day.serial, coupon_day.serial, coupon_day.serial, coupon_day.serial];
    var cp_flag: bool[4] = [false, true, true, false];
    var cp_nom: f64[4] = [0.0, 100.0, 100.0, 0.0];
    var cp_acc: f64[4] = [0.0, 1.0, 1.0, 0.0];
    var cp_dc: i32[4] = [0, 1, 1, 0];
    var cp_rate: f64[4] = [0.0, 0.03, 0.02, 0.0];
    let n1, n1ok = cashflow::next_coupon_rate(cp_pay, cp_flag, cp_nom, cp_acc, cp_dc, cp_rate, coupon_day.serial - 1, false);
    let p1, p1ok = cashflow::previous_coupon_rate(cp_pay, cp_flag, cp_nom, cp_acc, cp_dc, cp_rate, coupon_day.serial, false);
    let n2, n2ok = cashflow::next_coupon_rate(cp_pay, cp_flag, cp_nom, cp_acc, cp_dc, cp_rate, coupon_day.serial, true);
    let p2, p2ok = cashflow::previous_coupon_rate(cp_pay, cp_flag, cp_nom, cp_acc, cp_dc, cp_rate, coupon_day.serial, true);
    let n3, n3ok = cashflow::next_coupon_rate(cp_pay, cp_flag, cp_nom, cp_acc, cp_dc, cp_rate, coupon_day.serial, false);
    if !n1ok || !p1ok || !n2ok || !p2ok || !n3ok { fail("coupon"); }
    if gap(n1, 0.05) > 1.0e-14 || gap(p1, 0.05) > 1.0e-14 || gap(n2, 0.05) > 1.0e-14 || p2 != 0.0 || n3 != 0.0 { fail("coupon"); }
    var none_b: bool[0] = [];
    var none_i: i32[0] = [];
    var none_f: f64[0] = [];
    let empty_c, ecok = cashflow::next_coupon_rate(none_i, none_b, none_f, none_f, none_i, none_f, coupon_day.serial, false);
    if !ecok || empty_c != 0.0 { fail("empty coupon"); }
    var bad_nom: f64[2] = [100.0, 200.0];
    var bad_pay: i32[2] = [coupon_day.serial, coupon_day.serial];
    var bad_flag: bool[2] = [true, true];
    var bad_acc: f64[2] = [1.0, 1.0];
    var bad_dc: i32[2] = [1, 1];
    var bad_rate: f64[2] = [0.03, 0.02];
    let bad, badok = cashflow::next_coupon_rate(bad_pay, bad_flag, bad_nom, bad_acc, bad_dc, bad_rate, coupon_day.serial - 1, false);
    if badok || bad != 0.0 { fail("mismatch"); }
    write_stdout("curve suite ok\n");
}
