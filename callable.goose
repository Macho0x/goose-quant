// European callable zero, QuantLib's BlackCallableZeroCouponBondEngine.
// test-suite/callablebonds.cpp caches the clean price at 74.54521578,
// tolerance 1e-4. testCached prices a 5% semiannual bond on a 240-step
// Hull-White tree; the call-only clean price is 110.60975477.

import math;
import date;
import daycount;
import calendar;
import markets;
import period;
import schedule;
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

fn close_enough(x: f64, y: f64) -> bool {
    if x == y { return true; }
    var diff = x - y;
    if diff < 0.0 { diff = -diff; }
    let tol = 42.0 * 2.2204460492503131e-16;
    if x == 0.0 || y == 0.0 { return diff < tol * tol; }
    var ax = x;
    if ax < 0.0 { ax = -ax; }
    var ay = y;
    if ay < 0.0 { ay = -ay; }
    return diff <= tol * ax || diff <= tol * ay;
}

fn ifloor(x: f64) -> i64 {
    let t = x as i64;
    if x >= 0.0 || t == x { return t; }
    return t - 1;
}

fn yf_act(a: date::Date, b: date::Date) -> f64, bool {
    let blank = date::blank();
    return daycount::year_fraction(daycount::actual365_fixed(), a, b, blank, blank);
}

fn yf_bond(a: date::Date, b: date::Date) -> f64, bool {
    let blank = date::blank();
    return daycount::year_fraction(daycount::thirty360_bond(), a, b, blank, blank);
}

fn sort_times(xs: f64[>..] &) {
    var i = 1;
    while i < xs.len {
        let v = xs[i];
        var j = i;
        while j > 0 && xs[j - 1] > v {
            xs[j] = xs[j - 1];
            j -= 1;
        }
        xs[j] = v;
        i += 1;
    }
}

fn grid_index(times: f64[:], t: f64) -> i64, bool {
    if times.len == 0 { return 0, false; }
    var i = 0;
    while i < times.len && times[i] < t { i += 1; }
    var idx = i;
    if i == 0 {
        idx = 0;
    } else if i == times.len {
        idx = times.len - 1;
    } else {
        let later = times[i] - t;
        let earlier = t - times[i - 1];
        if later < earlier { idx = i; } else { idx = i - 1; }
    }
    if close_enough(t, times[idx]) { return idx, true; }
    return 0, false;
}

// Coupons marked pre are paid before the call; the rest are paid after.
fn on_date(values: f64[:], c_at: i64[:], c_amt: f64[:], c_pre: i64[:], k_at: i64[:], k_px: f64[:], at: i64) {
    var k = 0;
    while k < c_at.len {
        if c_pre[k] == 1 && c_at[k] == at {
            var j = 0;
            while j < values.len {
                values[j] += c_amt[k];
                j += 1;
            }
        }
        k += 1;
    }
    k = 0;
    while k < k_at.len {
        if k_at[k] == at {
            let strike = k_px[k];
            var j = 0;
            while j < values.len {
                if values[j] > strike { values[j] = strike; }
                j += 1;
            }
        }
        k += 1;
    }
    k = 0;
    while k < c_at.len {
        if c_pre[k] == 0 && c_at[k] == at {
            var j = 0;
            while j < values.len {
                values[j] += c_amt[k];
                j += 1;
            }
        }
        k += 1;
    }
}

// testCached bond1: 3 Jun 2004, TARGET, flat 3.2% continuous Actual/365,
// Hull-White a=0.1 sigma=0.01, semiannual 5% of 10000, calls at 110 clean
// on even years, 240-step TreeCallableFixedRateBondEngine. Clean price.
fn tree_clean() -> f64, bool {
    let today, tok = date::from_ymd(3, date::JUNE, 2004);
    if !tok { return 0.0, false; }
    let back, bok = date::plus_days(today, -100);
    if !bok { return 0.0, false; }
    let issue, iok = following(back);
    let settle, sok = business(today, 3, period::DAYS);
    if !iok || !sok { return 0.0, false; }
    let maturity, mok = business(issue, 10, period::YEARS);
    if !mok { return 0.0, false; }

    var sched: i32[40] = [0; 40];
    let nsch, schok = schedule::build(issue, maturity, 6, period::MONTHS, markets::TARGET, calendar::MODIFIED_FOLLOWING, calendar::MODIFIED_FOLLOWING, schedule::BACKWARD, false, sched);
    if !schok || nsch < 2 { return 0.0, false; }
    let nper = (nsch as i64) - 1;

    let face = 10000.0;
    let coupon = 0.05;
    let flat = 0.032;
    let call_clean = 110.0;
    let a = 0.1;
    let sig = 0.01;
    let steps: i64 = 240;
    let week = 1.0 / 52.0;

    var pay: i32[>..] = [];
    var acc0: i32[>..] = [];
    var acc1: i32[>..] = [];
    var amt: f64[>..] = [];
    var ctime: f64[>..] = [];
    var pre: i64[>..] = [];
    var p = 0;
    while p < nper {
        let start, s1 = date::from_serial(sched[p]);
        let end, s2 = date::from_serial(sched[p + 1]);
        if !s1 || !s2 { return 0.0, false; }
        let pay_d, pok = rolled(end);
        if !pok { return 0.0, false; }
        let y, yok = yf_bond(start, end);
        if !yok || y < 0.0 { return 0.0, false; }
        if pay_d.serial > settle.serial {
            let t, t1 = yf_act(settle, pay_d);
            if !t1 || t < 0.0 { return 0.0, false; }
            pay.push(pay_d.serial);
            acc0.push(start.serial);
            acc1.push(end.serial);
            amt.push(face * coupon * y);
            ctime.push(t);
            pre.push(0);
        }
        p += 1;
    }
    if pay.len == 0 { return 0.0, false; }

    let last_end, lek = date::from_serial(sched[nper]);
    if !lek { return 0.0, false; }
    let red_d, rdk = rolled(last_end);
    if !rdk { return 0.0, false; }
    let red_t, rtk = yf_act(settle, red_d);
    if !rtk || red_t < 0.0 { return 0.0, false; }

    var cd: i32[>..] = [];
    var cstrike: f64[>..] = [];
    var cwhen: f64[>..] = [];
    var yr: i32 = 2;
    while yr < 10 {
        let when, wok = business(issue, yr, period::YEARS);
        if !wok { return 0.0, false; }
        if when.serial > settle.serial && when.serial < red_d.serial {
            var accrued_pct = 0.0;
            var k = 0;
            while k < pay.len {
                if pay[k] > when.serial {
                    let a0, a0k = date::from_serial(acc0[k]);
                    let a1, a1k = date::from_serial(acc1[k]);
                    let pd, pdk = date::from_serial(pay[k]);
                    if !a0k || !a1k || !pdk { return 0.0, false; }
                    if when.serial > a0.serial && when.serial <= pd.serial {
                        var stop = a1;
                        if when.serial < a1.serial { stop = when; }
                        let y, yok = yf_bond(a0, stop);
                        if !yok { return 0.0, false; }
                        accrued_pct = coupon * y * 100.0;
                    }
                    break;
                }
                k += 1;
            }
            var strike = call_clean + accrued_pct;
            let t_call, tck = yf_act(settle, when);
            if !tck || t_call < 0.0 { return 0.0, false; }
            var t_use = t_call;
            var j = 0;
            while j < ctime.len {
                if t_use <= ctime[j] && ctime[j] <= t_use + week && when.serial < pay[j] {
                    let df_c = exp(-flat * t_call);
                    let df_k = exp(-flat * ctime[j]);
                    if df_k == 0.0 { return 0.0, false; }
                    strike *= df_c / df_k;
                    t_use = ctime[j];
                    pre[j] = 1;
                    break;
                }
                j += 1;
            }
            strike *= face / 100.0;
            cd.push(when.serial);
            cstrike.push(strike);
            cwhen.push(t_use);
        }
        yr += 2;
    }
    var i = 0;
    while i < cd.len {
        var j = 0;
        while j < pay.len {
            if pre[j] == 1 && cd[i] == pay[j] { cstrike[i] += amt[j]; }
            j += 1;
        }
        i += 1;
    }

    var accrued = 0.0;
    let a0, a0k = date::from_serial(acc0[0]);
    let a1, a1k = date::from_serial(acc1[0]);
    let pd, pdk = date::from_serial(pay[0]);
    if !a0k || !a1k || !pdk { return 0.0, false; }
    if settle.serial > a0.serial && settle.serial <= pd.serial {
        var stop = a1;
        if settle.serial < a1.serial { stop = settle; }
        let y, yok = yf_bond(a0, stop);
        if !yok { return 0.0, false; }
        accrued = face * coupon * y;
    }

    var mand: f64[>..] = [];
    mand.push(red_t);
    i = 0;
    while i < ctime.len {
        mand.push(ctime[i]);
        i += 1;
    }
    i = 0;
    while i < cwhen.len {
        mand.push(cwhen[i]);
        i += 1;
    }
    sort_times(mand);
    var uniq: f64[>..] = [];
    uniq.push(mand[0]);
    i = 1;
    while i < mand.len {
        if !close_enough(uniq[uniq.len - 1], mand[i]) { uniq.push(mand[i]); }
        i += 1;
    }
    if uniq[uniq.len - 1] <= 0.0 { return 0.0, false; }

    var times: f64[>..] = [];
    let dt_max = uniq[uniq.len - 1] / steps;
    times.push(0.0);
    var period_begin = 0.0;
    i = 0;
    while i < uniq.len {
        let period_end = uniq[i];
        if period_end != 0.0 {
            var n_steps = ifloor((period_end - period_begin) / dt_max + 0.5);
            if n_steps < 1 { n_steps = 1; }
            let dt = (period_end - period_begin) / n_steps;
            var n = 1;
            while n <= n_steps {
                times.push(period_begin + n * dt);
                n += 1;
            }
        }
        period_begin = period_end;
        i += 1;
    }
    if times.len < 2 { return 0.0, false; }

    var dts: f64[>..] = [];
    i = 0;
    while i < times.len - 1 {
        let dt = times[i + 1] - times[i];
        if dt <= 0.0 { return 0.0, false; }
        dts.push(dt);
        i += 1;
    }

    var dt_span = 0.0;
    var v_max = 0.0;
    i = 0;
    while i < dts.len {
        if dts[i] > dt_span { dt_span = dts[i]; }
        let v2 = 0.5 * sig * sig / a * (1.0 - exp(-2.0 * a * dts[i]));
        if v2 > v_max { v_max = v2; }
        i += 1;
    }
    let dx_floor = sqrt(3.0 * v_max);

    var counts: i64[>..] = [];
    var jmins: i64[>..] = [];
    var dxs: f64[>..] = [];
    var off: i64[>..] = [];
    var ks: i64[>..] = [];
    var ps0: f64[>..] = [];
    var ps1: f64[>..] = [];
    var ps2: f64[>..] = [];
    var j_min: i64 = 0;
    var j_max: i64 = 0;
    var dx_cur = 0.0;
    var max_n: i64 = 1;
    var step = 0;
    while step < dts.len {
        let n_here = j_max - j_min + 1;
        if n_here < 1 { return 0.0, false; }
        if n_here > max_n { max_n = n_here; }
        counts.push(n_here);
        jmins.push(j_min);
        dxs.push(dx_cur);
        off.push(ks.len);

        let dt = dts[step];
        let v2 = 0.5 * sig * sig / a * (1.0 - exp(-2.0 * a * dt));
        if v2 <= 0.0 { return 0.0, false; }
        let v = sqrt(v2);
        let dx_natural = v * sqrt(3.0);
        var dx_next = dx_natural;
        if dt < 0.01 * dt_span && dx_floor > dx_next { dx_next = dx_floor; }
        let floored = dx_next > dx_natural;
        if dx_next == 0.0 { return 0.0, false; }
        let dx2 = dx_next * dx_next;

        var k_min: i64 = 0;
        var k_max: i64 = 0;
        var seen = false;
        var j = j_min;
        while j <= j_max {
            let x = j * dx_cur;
            let m = x * exp(-a * dt);
            let temp = ifloor(m / dx_next + 0.5);
            let e = m - temp * dx_next;
            let e2 = e * e;
            var p1 = 0.0;
            var p2 = 0.0;
            var p3 = 0.0;
            if floored {
                p1 = (v2 + e2 - e * dx_next) / (2.0 * dx2);
                p2 = 1.0 - (v2 + e2) / dx2;
                p3 = (v2 + e2 + e * dx_next) / (2.0 * dx2);
            } else {
                let e3 = e * sqrt(3.0);
                p1 = (1.0 + e2 / v2 - e3 / v) / 6.0;
                p2 = (2.0 - e2 / v2) / 3.0;
                p3 = (1.0 + e2 / v2 + e3 / v) / 6.0;
            }
            ks.push(temp);
            ps0.push(p1);
            ps1.push(p2);
            ps2.push(p3);
            if !seen || temp < k_min { k_min = temp; }
            if !seen || temp > k_max { k_max = temp; }
            seen = true;
            j += 1;
        }
        j_min = k_min - 1;
        j_max = k_max + 1;
        dx_cur = dx_next;
        step += 1;
    }
    let n_last = j_max - j_min + 1;
    if n_last < 1 { return 0.0, false; }
    if n_last > max_n { max_n = n_last; }
    counts.push(n_last);
    jmins.push(j_min);
    dxs.push(dx_cur);
    if counts.len != times.len { return 0.0, false; }

    var c_at: i64[>..] = [];
    i = 0;
    while i < ctime.len {
        let idx, ok = grid_index(times, ctime[i]);
        if !ok { return 0.0, false; }
        c_at.push(idx);
        i += 1;
    }
    var k_at: i64[>..] = [];
    i = 0;
    while i < cwhen.len {
        let idx, ok = grid_index(times, cwhen[i]);
        if !ok { return 0.0, false; }
        k_at.push(idx);
        i += 1;
    }
    let red, rok = grid_index(times, red_t);
    if !rok || red < 0 || red >= counts.len { return 0.0, false; }

    var sp: f64[>..] = [];
    var sp2: f64[>..] = [];
    var z = 0;
    while z < max_n {
        sp.push(0.0);
        sp2.push(0.0);
        z += 1;
    }
    sp[0] = 1.0;
    var phis: f64[>..] = [];
    i = 0;
    while i < dts.len {
        let dt = dts[i];
        let dx = dxs[i];
        let n = counts[i];
        var x = jmins[i] * dx;
        var sum = 0.0;
        var j = 0;
        while j < n {
            sum += sp[j] * exp(-x * dt);
            x += dx;
            j += 1;
        }
        let bond = exp(-flat * times[i + 1]);
        if bond <= 0.0 || sum <= 0.0 { return 0.0, false; }
        let phi = log(sum / bond) / dt;
        phis.push(phi);
        let n2 = counts[i + 1];
        j = 0;
        while j < n2 {
            sp2[j] = 0.0;
            j += 1;
        }
        j = 0;
        while j < n {
            let idx = off[i] + j;
            let xj = (jmins[i] + j) * dx;
            let disc = exp(-(xj + phi) * dt);
            let base = ks[idx] - jmins[i + 1] - 1;
            if base < 0 || base + 2 >= n2 { return 0.0, false; }
            let w = sp[j] * disc;
            sp2[base] += w * ps0[idx];
            sp2[base + 1] += w * ps1[idx];
            sp2[base + 2] += w * ps2[idx];
            j += 1;
        }
        j = 0;
        while j < n2 {
            sp[j] = sp2[j];
            j += 1;
        }
        i += 1;
    }

    var cur: f64[>..] = [];
    var nxt: f64[>..] = [];
    z = 0;
    while z < max_n {
        cur.push(0.0);
        nxt.push(0.0);
        z += 1;
    }
    z = 0;
    while z < counts[red] {
        cur[z] = face;
        z += 1;
    }
    on_date(cur[0..counts[red]], c_at, amt, pre, k_at, cstrike, red);
    if red > 0 {
        step = red;
        while step > 0 {
            step -= 1;
            let n = counts[step];
            let n2 = counts[step + 1];
            var j = 0;
            while j < n {
                let idx = off[step] + j;
                let base = ks[idx] - jmins[step + 1] - 1;
                if base < 0 || base + 2 >= n2 { return 0.0, false; }
                let cont = ps0[idx] * cur[base] + ps1[idx] * cur[base + 1] + ps2[idx] * cur[base + 2];
                let x = (jmins[step] + j) * dxs[step];
                nxt[j] = cont * exp(-(x + phis[step]) * dts[step]);
                j += 1;
            }
            j = 0;
            while j < n {
                cur[j] = nxt[j];
                j += 1;
            }
            if step != 0 {
                on_date(cur[0..n], c_at, amt, pre, k_at, cstrike, step);
            }
        }
        on_date(cur[0..counts[0]], c_at, amt, pre, k_at, cstrike, 0);
    }
    return (cur[0] - accrued) * 100.0 / face, true;
}
