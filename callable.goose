// European callable zero, QuantLib's BlackCallableZeroCouponBondEngine.
// test-suite/callablebonds.cpp caches the clean price at 74.54521578,
// tolerance 1e-4. The CallableBonds example table is a Hull-White tree
// and has no QuantLib price literal.

import math;
import date;
import daycount;
import calendar;
import markets;
import period;
import rate;
import curve;
import cash;
import black;

namespace callable;

fn business(d: date::Date, n: i32, unit: i32) -> date::Date, bool {
    var hole: i32[1] = [0];
    let none = hole[0..0];
    return calendar::advance(markets::TARGET, d, n, unit, calendar::FOLLOWING, false, none, none);
}

fn following(d: date::Date) -> date::Date, bool {
    var hole: i32[1] = [0];
    let none = hole[0..0];
    return calendar::adjust(markets::TARGET, d, calendar::FOLLOWING, none, none);
}

fn rolled(d: date::Date) -> date::Date, bool {
    var hole: i32[1] = [0];
    let none = hole[0..0];
    return calendar::adjust(markets::TARGET, d, calendar::MODIFIED_FOLLOWING, none, none);
}

// One remaining cash flow. QuantLib's modified duration is t / (1 + y)
// for annual compounding, and price vol is yield vol times that times yield.
fn zero_clean(vol_ref: date::Date, settle: date::Date, exercise: date::Date, redeem: date::Date, face: f64, redemption: f64, call_clean: f64, yield_vol: f64, flat: f64) -> f64, bool {
    if face <= 0.0 || yield_vol < 0.0 || exercise.serial < settle.serial { return 0.0, false; }
    let act = daycount::actual365_fixed();
    let bond = daycount::thirty360_bond();
    let blank = date::blank();
    let t_red, rok = daycount::year_fraction(act, settle, redeem, blank, blank);
    let t_ex, eok = daycount::year_fraction(act, settle, exercise, blank, blank);
    let t_vol, vok = daycount::year_fraction(act, vol_ref, exercise, blank, blank);
    let t30, tok = daycount::year_fraction(bond, exercise, redeem, blank, blank);
    if !rok || !eok || !vok || !tok || t_red < 0.0 || t_ex < 0.0 || t_vol < 0.0 || t30 <= 0.0 {
        return 0.0, false;
    }
    let df_red, d1 = curve::flat_discount(flat, rate::CONTINUOUS, 1, t_red);
    let df_ex, d2 = curve::flat_discount(flat, rate::CONTINUOUS, 1, t_ex);
    if !d1 || !d2 || df_ex == 0.0 || df_red <= 0.0 { return 0.0, false; }
    let amount = face * redemption / 100.0;
    var times: f64[2] = [0.0, t_red];
    var discounts: f64[2] = [1.0, df_red];
    var pay: i32[1] = [redeem.serial];
    var amounts: f64[1] = [amount];
    let value, vok2 = cash::curve_npv(pay, amounts, times, discounts, settle.serial, settle.serial, act);
    let pv, pok = cash::curve_npv(pay, amounts, times, discounts, exercise.serial, settle.serial, act);
    if !vok2 || !pok { return 0.0, false; }
    let forward = pv / df_ex;
    if forward <= 0.0 { return 0.0, false; }
    let y, yok = rate::implied_rate(amount / forward, rate::COMPOUNDED, 1, t30);
    if !yok { return 0.0, false; }
    let back, bok = cash::yield_npv(pay, amounts, exercise.serial, y, rate::COMPOUNDED, 1, bond);
    if !bok { return 0.0, false; }
    var gap = back - forward;
    if gap < 0.0 { gap = -gap; }
    if gap > 1.0e-8 { return 0.0, false; }
    let std_dev = yield_vol * (t30 / (1.0 + y)) * y * sqrt(t_vol);
    let strike = call_clean * face / 100.0;
    let opt, ook = black::black(black::CALL, strike, forward, std_dev, 1.0, 0.0);
    if !ook { return 0.0, false; }
    return (value - opt * df_ex) * 100.0 / face, true;
}

// testBlackEngine: 20 Sep 2022, flat 3% continuous Actual/365, yield vol 30%,
// call in four years at 100 clean, redemption in ten years.
fn price() -> f64, bool {
    let today, a = date::from_ymd(20, date::SEPTEMBER, 2022);
    if !a { return 0.0, false; }
    let settle, b = business(today, 3, period::DAYS);
    let back, c = date::plus_days(today, -100);
    if !b || !c { return 0.0, false; }
    let issue, d = following(back);
    if !d { return 0.0, false; }
    let exercise, e = business(issue, 4, period::YEARS);
    let maturity, f = business(issue, 10, period::YEARS);
    if !e || !f { return 0.0, false; }
    let redeem, g = rolled(maturity);
    if !g { return 0.0, false; }
    return zero_clean(today, settle, exercise, redeem, 10000.0, 100.0, 100.0, 0.3, 0.03);
}
