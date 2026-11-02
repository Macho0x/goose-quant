import os;
import quant from "..";
import quant.date;
import quant.period;
import quant.daycount;
import quant.calendar;
import quant.markets;
import quant.schedule;
import quant.cash;
import quant.rate;
import quant.solver;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn yf(dc: daycount::Count, a: date::Date, b: date::Date) -> f64, bool {
    return daycount::year_fraction(dc, a, b, date::blank(), date::blank());
}

fn ::main() {
    let settle, sok = date::from_ymd(14, date::FEBRUARY, 2000);
    let delivery, dok = date::from_ymd(15, date::AUGUST, 2000);
    let dated, aok = date::from_ymd(15, date::SEPTEMBER, 1995);
    let maturity, mok = date::from_ymd(15, date::SEPTEMBER, 2005);
    if !sok || !dok || !aok || !mok { fail("dates"); }
    var buf: i32[>..] = [];
    var n: i32 = 0;
    while n < 30 {
        buf.push(0);
        n += 1;
    }
    let count, cok = schedule::build(dated, maturity, 6, period::MONTHS, markets::NULL_CAL, calendar::UNADJUSTED, calendar::UNADJUSTED, schedule::BACKWARD, false, buf);
    if !cok || count < 2 { fail("schedule"); }
    let bond_dc = daycount::thirty360_bond();
    let repo_dc = daycount::actual360();
    var pay: i32[>..] = [];
    var amounts: f64[>..] = [];
    var accrued = 0.0;
    var accrued_delivery = 0.0;
    var k: i64 = 1;
    let n64 = count as i64;
    while k < n64 {
        let start, s2 = date::from_serial(buf[k - 1]);
        let end, e2 = date::from_serial(buf[k]);
        if !s2 || !e2 { fail("period"); }
        let tau, tok = yf(bond_dc, start, end);
        if !tok { fail("coupon"); }
        var coupon = 100.0 * 0.08 * tau;
        if settle.serial > start.serial && settle.serial < end.serial {
            let gone, gok = yf(bond_dc, start, settle);
            if !gok { fail("accrued"); }
            accrued = 100.0 * 0.08 * gone;
        }
        if delivery.serial > start.serial && delivery.serial < end.serial {
            let gone, gok = yf(bond_dc, start, delivery);
            if !gok { fail("delivery accrued"); }
            accrued_delivery = 100.0 * 0.08 * gone;
        }
        if end.serial > settle.serial {
            if k == n64 - 1 { coupon += 100.0; }
            pay.push(end.serial);
            amounts.push(coupon);
        }
        k += 1;
    }
    let clean = 89.97693786;
    let dirty = clean + accrued;
    let y, yok = solver::brent(0.08, 0.001, 0.2, 1.0e-12, 80) {
        let npv, ok = cash::yield_npv(pay, amounts, settle.serial, it, rate::COMPOUNDED, 2, bond_dc);
        if ok { npv - dirty } else { 1.0 }
    };
    if !yok { fail("yield"); }
    let back, bok = cash::yield_npv(pay, amounts, settle.serial, y, rate::COMPOUNDED, 2, bond_dc);
    if !bok { fail("reprice"); }
    var gap = back - dirty;
    if gap < 0.0 { gap = -gap; }
    if gap > 1.0e-8 { fail("yield price"); }

    var income = 0.0;
    k = 0;
    while k < pay.len {
        if pay[k] <= delivery.serial {
            let when, wok = date::from_serial(pay[k]);
            if !wok { fail("income date"); }
            let t, tk = yf(repo_dc, settle, when);
            let df, dfok = rate::discount_factor(0.05, rate::SIMPLE, 1, t);
            if !tk || !dfok { fail("income df"); }
            var piece = amounts[k];
            if piece > 100.0 { piece -= 100.0; }
            income += piece * df;
        }
        k += 1;
    }
    let t_del, tdk = yf(repo_dc, settle, delivery);
    let df_del, ddk = rate::discount_factor(0.05, rate::SIMPLE, 1, t_del);
    if !tdk || !ddk || df_del == 0.0 { fail("delivery df"); }
    let fwd_dirty = (dirty - income) / df_del;
    let fwd_clean = fwd_dirty - accrued_delivery;
    let strike = 91.5745;
    let npv = (fwd_dirty - strike) * df_del;

    var line: u8[>..] = [];
    format(line, "Underlying bond clean price: ");
    format(line, clean);
    format(line, "\nUnderlying bond dirty price: ");
    format(line, dirty);
    format(line, "\nUnderlying bond accrued at settlement: ");
    format(line, accrued);
    format(line, "\nUnderlying bond accrued at delivery:   ");
    format(line, accrued_delivery);
    format(line, "\nUnderlying bond spot income: ");
    format(line, income);
    format(line, "\nUnderlying bond fwd income:  ");
    format(line, income / df_del);
    format(line, "\nRepo strike: ");
    format(line, strike);
    format(line, "\nRepo NPV:    ");
    format(line, npv);
    format(line, "\nRepo clean forward price: ");
    format(line, fwd_clean);
    format(line, "\nRepo dirty forward price: ");
    format(line, fwd_dirty);
    format(line, "\n\nCompare with example given at \n");
    format(line, "http://www.fincad.com/support/developerFunc/mathref/BFWD.htm\n");
    format(line, "Clean forward price = 88.2408\n\n");
    format(line, "In that example, it is unknown what bond calendar they are\n");
    format(line, "using, as well as settlement Days. For that reason, I have\n");
    format(line, "made the simplest possible assumptions here: NullCalendar\n");
    format(line, "and 0 settlement days.\n");
    write_stdout(line);
    var err = fwd_clean - 88.2408;
    if err < 0.0 { err = -err; }
    if err > 5.0e-4 { fail("fincad"); }
}
