import os;
import math;
import quant from "..";
import quant.rate;
import quant.curve;
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
    write_stdout("curve suite ok\n");
}
