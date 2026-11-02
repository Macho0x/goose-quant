import os;
import math;
import quant from "..";
import quant.date;
import quant.daycount;
import quant.rate;
import quant.cash;
import quant.curve;
import quant.calendar;
import quant.markets;
import quant.solver;
import quant.black;
import quant.normal;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn near(got: f64, want: f64, tol: f64) -> bool {
    var d = got - want;
    if d < 0.0 { d = -d; }
    return d <= tol;
}

fn ::main() {
    let dc = daycount::actual365_fixed();
    let d08, ok08 = date::from_ymd(15, date::MAY, 2008);
    let d09, ok09 = date::from_ymd(15, date::MAY, 2009);
    let d10, ok10 = date::from_ymd(15, date::MAY, 2010);
    let d11, ok11 = date::from_ymd(15, date::NOVEMBER, 2008);
    if !ok08 || !ok09 || !ok10 || !ok11 { fail("dates"); }
    let c1, c1ok = cash::coupon(d08, d09, 100.0, 0.05, dc);
    let c2, c2ok = cash::coupon(d09, d10, 100.0, 0.05, dc);
    if !c1ok || !c2ok || !near(c1, 5.0, 1.0e-12) || !near(c2, 5.0, 1.0e-12) { fail("coupon"); }
    var pay: i32[2] = [d09.serial, d10.serial];
    var amounts: f64[2] = [c1, c2 + 100.0];
    let npv, nok = cash::yield_npv(pay, amounts, d08.serial, 0.05, rate::COMPOUNDED, 1, dc);
    if !nok || !near(npv, 100.0, 1.0e-10) { fail("par"); }
    var pillar_t: f64[1] = [1.0];
    var pillar_df: f64[1] = [0.951229424500714];
    var one_pay: i32[1] = [d09.serial];
    var one_amt: f64[1] = [105.0];
    let cnpv, cok = cash::curve_npv(one_pay, one_amt, pillar_t, pillar_df, d08.serial, d08.serial, dc);
    if !cok || !near(cnpv, 99.879089572575, 1.0e-10) { fail("curve npv"); }
    var times2: f64[2] = [1.0, 2.0];
    var dfs2: f64[2] = [0.97, 0.9];
    var pays: i32[2] = [d09.serial, d10.serial];
    var amts: f64[2] = [5.0, 105.0];
    let fitted, fitok = cash::fit_discount(pays, amts, times2, dfs2, d08.serial, d08.serial, dc, 100.0, 0.9);
    if !fitok || !near(fitted, 0.906190476190476, 1.0e-10) { fail("fit"); }
    let back, bok = cash::curve_npv(pays, amts, times2, dfs2, d08.serial, d08.serial, dc);
    if !bok || !near(back, 100.0, 1.0e-8) { fail("fit price"); }
    var bt: f64[2] = [0.0, 1.0];
    var bd: f64[2] = [1.0, 0.9];
    var bpay: i32[1] = [d09.serial];
    var bamt: f64[1] = [105.0];
    let df1, d1ok = cash::fit_discount(bpay, bamt, bt, bd, d08.serial, d08.serial, dc, 100.0, 0.9);
    if !d1ok || !near(df1, 100.0 / 105.0, 1.0e-10) { fail("pillar 1"); }
    var bt2: f64[3] = [0.0, 1.0, 2.0];
    var bd2: f64[3] = [1.0, df1, 0.9];
    var bpay2: i32[2] = [d09.serial, d10.serial];
    var bamt2: f64[2] = [5.0, 105.0];
    let df2, d2ok = cash::fit_discount(bpay2, bamt2, bt2, bd2, d08.serial, d08.serial, dc, 100.0, 0.9);
    if !d2ok || !near(df2, (100.0 - 5.0 * df1) / 105.0, 1.0e-10) { fail("pillar 2"); }
    let acc, aok = cash::accrued(d08, d11, d09, 100.0, 0.05, dc);
    if !aok || !near(acc, 2.520547945205479, 1.0e-12) { fail("accrued"); }

    let fra, fok = cash::fra_amount(1000000.0, 0.05, 0.04, 0.5, true);
    if !fok || !near(fra, 4878.048780487805, 1.0e-8) { fail("fra"); }

    var dfs: f64[3] = [1.0, 0.951229424500714, 0.904837418035960];
    var taus: f64[2] = [1.0, 1.0];
    let par, pok = cash::par_rate(taus, dfs);
    if !pok || !near(par, 0.051271096376024, 1.0e-12) { fail("par swap"); }

    var times: f64[2] = [0.25, 1.0];
    var rates: f64[2] = [0.02, 0.03];
    var pillars: f64[2] = [0.0, 0.0];
    if !curve::simple_pillars(times, rates, pillars) { fail("pillars"); }
    if !near(pillars[0], 0.9950248756218906, 1.0e-12) || !near(pillars[1], 0.970873786407767, 1.0e-12) { fail("pillar df"); }
    let mid, mok = curve::log_linear_discount(times, pillars, 0.625);
    let geo = sqrt(pillars[0] * pillars[1]);
    if !mok || !near(mid, geo, 1.0e-12) { fail("log linear"); }

    var hole: i32[1] = [0];
    let empty = hole[0..0];
    var kinds: i32[2] = [markets::TARGET, markets::WEEKENDS];
    let ny, yok = date::from_ymd(1, date::JANUARY, 2004);
    if !yok { fail("new year"); }
    if calendar::joint_business(kinds, ny, empty, empty, true) { fail("joint holiday"); }
    if !calendar::joint_business(kinds, ny, empty, empty, false) { fail("joint open"); }

    let root, rok = solver::brent(1.0, 0.1, 2.0, 1.0e-12, 80) { it * it - 2.0 };
    if !rok || !near(root, 1.414213562373095, 1.0e-10) { fail("brent"); }
    let nroot, nrok = solver::newton(1.0, 1.0e-12, 40) { it * it - 2.0 };
    if !nrok || !near(nroot, 1.414213562373095, 1.0e-8) { fail("newton"); }

    let std, sok = black::implied_std(black::CALL, 100.0, 100.0, 7.965567455405804, 1.0, 0.0);
    if !sok || !near(std, 0.2, 1.0e-8) { fail("implied"); }
    if !near(normal::cdf(0.0), 0.5, 1.0e-15) || !near(normal::cdf(1.0), 0.841344746068543, 1.0e-12) { fail("cdf"); }
    let inv, iok = normal::inv_cdf(0.975);
    if !iok || !near(inv, 1.959963984540054, 1.0e-8) { fail("inv"); }

    var eval = rate::Settings { evaluation: d08.serial };
    if eval.evaluation != d08.serial { fail("settings"); }

    write_stdout("instruments ok\n");
}
