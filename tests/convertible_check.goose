import os;
import quant from "..";
import quant.black;
import quant.european;
import quant.rate;
import quant.convertible;
import quant.date;
import quant.period;
import quant.calendar;
import quant.markets;
import quant.daycount;

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
    // ConvertibleBonds.cpp market, length 5. Conversion is at the money.
    // testOption: a zero credit spread is the straight bond plus the call.
    let spot = 36.0;
    let redemption = 100.0;
    let ratio = redemption / spot;
    let r = 0.06;
    let q = 0.02;
    let vol = 0.20;
    let t = 5.0;
    let spread = 0.005;
    let px, ok = convertible::npv(spot, redemption, ratio, r, q, vol, t, 0.0);
    let call, cok = european::npv(black::CALL, spot, spot, r, q, vol, t);
    let df, dok = rate::discount_factor(r, rate::CONTINUOUS, 0, t);
    if !ok || !cok || !dok { fail("spread zero"); }
    if gap(px, df * redemption + ratio * call) > 1.0e-9 { fail("spread zero"); }

    // testOption tolerance is 5.0e-2 * (faceAmount/100). Face is 100.
    // 801 steps is ConvertibleBonds.cpp. Zero coupon, no dividends, spread 0.
    let bin, tok = convertible::crr(spot, redemption, ratio, r, q, vol, t, 0.0, 801);
    if !tok || gap(bin, px) > 5.0e-2 { fail("binomial"); }

    // No conversion: only the risky redemption remains.
    let buried, bok = convertible::npv(1.0, redemption, ratio, r, q, vol, t, spread);
    let risky, rok = rate::discount_factor(r + spread, rate::CONTINUOUS, 0, t);
    if !bok || !rok || gap(buried, risky * redemption) > 1.0e-9 { fail("no conversion"); }

    // Certain conversion: the shares, whatever the credit spread.
    // A zero strike is that prepaid forward.
    let high = 100000.0;
    let equity, eok = convertible::npv(high, redemption, ratio, r, q, vol, t, spread);
    let stock, sok = european::npv(black::CALL, high, 0.0, r, q, vol, t);
    if !eok || !sok || gap(equity, ratio * stock) > 1.0e-6 { fail("certain conversion"); }

    let dead, ddok = convertible::npv(1.0, redemption, ratio, r, q, 0.0, t, spread);
    if !ddok || gap(dead, risky * redemption) > 1.0e-12 { fail("zero vol"); }

    let bad, reject = convertible::npv(0.0, redemption, ratio, r, q, vol, t, spread);
    if reject || bad != 0.0 { fail("reject"); }

    var hole: f64[1] = [0.0];
    let none = hole[0..0];
    let bin2, b2ok = convertible::binomial(spot, redemption, ratio, r, q, vol, t, 0.0, 801, convertible::CRR, false, none, none, none, none);
    if !b2ok || gap(bin2, px) > 5.0e-2 { fail("binomial"); }

    // dividendValues()[0] discounts from the evaluation date. This tree's
    // time origin is settlement, so a dividend of 1 uses the 0.05 engine
    // tolerance, not 1e-12. Escrowing it lowers the share price.
    var one_t: f64[1] = [0.5];
    var one_a: f64[1] = [1.0];
    let steps: i32 = 101;
    let bare, bare_ok = convertible::binomial(spot, redemption, ratio, r, q, vol, t, spread, steps, convertible::CRR, false, none, none, none, none);
    let paid, paid_ok = convertible::binomial(spot, redemption, ratio, r, q, vol, t, spread, steps, convertible::CRR, false, none, none, one_t, one_a);
    let cash, cash_ok = convertible::dividend_value(1.0, r, 0.5);
    if !bare_ok || !paid_ok || !cash_ok || gap(cash, 1.0) > 5.0e-2 || !(bare > paid) { fail("dividend"); }

    var c_t: f64[1] = [1.0];
    var c_a: f64[1] = [5.0];
    let coup, coup_ok = convertible::binomial(spot, redemption, ratio, r, q, vol, t, spread, steps, convertible::CRR, false, c_t, c_a, none, none);
    if !coup_ok || coup <= bare { fail("coupon"); }

    var coupon_t: f64[>..] = [];
    var coupon_a: f64[>..] = [];
    var div_t: f64[>..] = [];
    var div_a: f64[>..] = [];
    if !convertible::sample_flows(t, coupon_t, coupon_a, div_t, div_a) { fail("flows"); }
    if coupon_t.len != 5 || div_t.len != 9 { fail("flows"); }
    let eu, eok = convertible::binomial(spot, redemption, ratio, r, q, vol, t, spread, steps, convertible::CRR, false, coupon_t, coupon_a, div_t, div_a);
    let am, aok = convertible::binomial(spot, redemption, ratio, r, q, vol, t, spread, steps, convertible::CRR, true, coupon_t, coupon_a, div_t, div_a);
    if !eok || !aok || am + 1.0e-8 < eu { fail("coupon"); }

    let broken, broken_ok = convertible::binomial(0.0, redemption, ratio, r, q, vol, t, spread, steps, convertible::CRR, false, none, none, none, none);
    if broken_ok || broken != 0.0 { fail("reject tree"); }

    // testDividendsSpanningSettlementDate. 15 Jan 2024, TARGET, Actual/360,
    // flat 5%. The next business day is on or before settlement and drops
    // out. The dividend of 10 one year after settlement is amount times the
    // discount, within the test's 1e-12 percent tolerance. A dividend of 1
    // on that same date is about 1.
    let today, today_ok = date::from_ymd(15, 1, 2024);
    var cal_hole: i32[1] = [0];
    let cal_none = cal_hole[0..0];
    let early, early_ok = calendar::advance(markets::TARGET, today, 1, period::DAYS, calendar::FOLLOWING, false, cal_none, cal_none);
    let settle, settle_ok = calendar::advance(markets::TARGET, today, 3, period::DAYS, calendar::FOLLOWING, false, cal_none, cal_none);
    let later, later_ok = calendar::advance(markets::TARGET, settle, 1, period::YEARS, calendar::FOLLOWING, false, cal_none, cal_none);
    let yf, yf_ok = daycount::year_fraction(daycount::actual360(), today, later, date::blank(), date::blank());
    let disc, disc_ok = rate::discount_factor(0.05, rate::CONTINUOUS, 0, yf);
    if !today_ok || !early_ok || !settle_ok || !later_ok || !yf_ok || !disc_ok { fail("dates"); }
    if !(early.serial > today.serial && early.serial < settle.serial) { fail("lag"); }
    let kept, kept_ok = convertible::stored_dividend(10.0, disc, later.serial, settle.serial);
    let expect = 10.0 * disc;
    if !kept_ok || gap(kept, expect) > expect * 1.0e-12 / 100.0 { fail("dividend value"); }
    let unit, unit_ok = convertible::stored_dividend(1.0, disc, later.serial, settle.serial);
    if !unit_ok || gap(unit, disc) > 1.0e-12 { fail("dividend one"); }
    let gone, gone_ok = convertible::stored_dividend(1.0, disc, early.serial, settle.serial);
    if !gone_ok || gone != 0.0 { fail("dropped dividend"); }

    var kind: i32 = 0;
    while kind <= convertible::JOSHI {
        if kind != convertible::ADDITIVE {
            let tree_px, tree_ok = convertible::binomial(spot, redemption, ratio, r, q, vol, t, 0.0, 801, kind, false, none, none, none, none);
            if !tree_ok || gap(tree_px, px) > 5.0e-2 { fail("tree"); }
            let us, us_ok = convertible::binomial(spot, redemption, ratio, r, q, vol, t, spread, 801, kind, true, coupon_t, coupon_a, div_t, div_a);
            let euro, euro_ok = convertible::binomial(spot, redemption, ratio, r, q, vol, t, spread, 801, kind, false, coupon_t, coupon_a, div_t, div_a);
            if !us_ok || !euro_ok || us + 1.0e-6 < euro { fail("row"); }
        }
        kind += 1;
    }

    write_stdout("convertible ok\n");
}
