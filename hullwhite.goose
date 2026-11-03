// HullWhite::convexityBias. Kirikos and Novak, Risk, March 1997.
// Hull-White bermudan: the 15 Feb 2002 cached TreeSwaptionEngine deal.

import math;
import date;
import period;
import calendar;
import markets;
import schedule;
import daycount;

namespace hullwhite;

const EPS: f64 = 2.2204460492503131e-16;

fn duration(a: f64, x: f64) -> f64 {
    // ponytail: a under machine epsilon is the x limit. (1-exp(-a*x))/a above that.
    if a < EPS { return x; }
    return (1.0 - exp(-a * x)) / a;
}

fn convexity_bias(future_price: f64, t: f64, maturity: f64, sigma: f64, a: f64) -> f64, bool {
    if future_price < 0.0 || t < 0.0 || maturity < t || sigma < 0.0 || a < 0.0 { return 0.0, false; }
    let dt = maturity - t;
    let g = duration(a, dt);
    let bt = duration(a, t);
    let z = sigma * sigma * 0.5 * (duration(a, 2.0 * t) * g + bt * bt);
    if dt < EPS { return z, true; }
    let rate = (100.0 - future_price) / 100.0;
    return (1.0 - exp(-z * g)) * (rate + 1.0 / dt), true;
}

fn near(x: f64, y: f64) -> bool {
    if x == y { return true; }
    let diff = abs(x - y);
    let tol = 42.0 * EPS;
    if x == 0.0 || y == 0.0 { return diff < tol * tol; }
    return diff <= tol * abs(x) || diff <= tol * abs(y);
}

fn floor_int(x: f64) -> i64 {
    let t = x as i64;
    if x < t { return t - 1; }
    return t;
}

fn yf365(d1: date::Date, d2: date::Date) -> f64, bool {
    let blank = date::blank();
    return daycount::year_fraction(daycount::actual365_fixed(), d1, d2, blank, blank);
}

fn yf360(d1: date::Date, d2: date::Date) -> f64, bool {
    let blank = date::blank();
    return daycount::year_fraction(daycount::actual360(), d1, d2, blank, blank);
}

fn yf30(d1: date::Date, d2: date::Date) -> f64, bool {
    let blank = date::blank();
    return daycount::year_fraction(daycount::thirty360_bond(), d1, d2, blank, blank);
}

// Payer bermudan on the cached 1y x 5y deal. moneyness scales the fair fixed rate.
// TreeSwaptionEngine, 50 steps, at-par coupons. The snapped schedule is built from
// the date list alone, so its calendar is the null calendar and payment dates are
// not rolled onto business days.
fn bermudan(moneyness: f64) -> f64, bool {
    if moneyness <= 0.0 { return 0.0, false; }
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    let settle, sok = date::from_ymd(19, 2, 2002);
    if !sok { return 0.0, false; }
    let start, aok = calendar::advance(markets::TARGET, settle, 1, period::YEARS, calendar::FOLLOWING, false, empty, empty);
    let maturity, mok = calendar::advance(markets::TARGET, start, 5, period::YEARS, calendar::FOLLOWING, false, empty, empty);
    if !aok || !mok { return 0.0, false; }
    var fixed_buf: i32[16] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    var float_buf: i32[24] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    let nf, fok = schedule::build(start, maturity, 1, period::YEARS, markets::TARGET, calendar::UNADJUSTED, calendar::UNADJUSTED, schedule::FORWARD, false, fixed_buf);
    let nu, uok = schedule::build(start, maturity, 6, period::MONTHS, markets::TARGET, calendar::MODIFIED_FOLLOWING, calendar::MODIFIED_FOLLOWING, schedule::FORWARD, false, float_buf);
    if !fok || !uok || nf < 2 || nu < 2 { return 0.0, false; }
    let n_fixed = nf as i64;
    let n_float = nu as i64;

    let curve = 0.04875825;
    var float_npv = 0.0;
    var annuity = 0.0;
    var i: i64 = 0;
    while i < n_float - 1 {
        let rs, rso = date::from_serial(float_buf[i]);
        let re, reo = date::from_serial(float_buf[i + 1]);
        if !rso || !reo { return 0.0, false; }
        let span, span_ok = yf360(rs, re);
        let tr, trok = yf365(settle, rs);
        let te, teok = yf365(settle, re);
        if !span_ok || !trok || !teok || span == 0.0 { return 0.0, false; }
        let fwd = (exp(-curve * tr) / exp(-curve * te) - 1.0) / span;
        float_npv += 1000.0 * span * fwd * exp(-curve * te);
        i += 1;
    }
    i = 0;
    while i < n_fixed - 1 {
        let rs, rso = date::from_serial(fixed_buf[i]);
        let re, reo = date::from_serial(fixed_buf[i + 1]);
        if !rso || !reo { return 0.0, false; }
        let tau, tau_ok = yf30(rs, re);
        let pay, pok = calendar::adjust(markets::TARGET, re, calendar::MODIFIED_FOLLOWING, empty, empty);
        if !tau_ok || !pok { return 0.0, false; }
        let tp, tpok = yf365(settle, pay);
        if !tpok { return 0.0, false; }
        annuity += 1000.0 * tau * exp(-curve * tp);
        i += 1;
    }
    if annuity == 0.0 { return 0.0, false; }
    let strike = float_npv / annuity * moneyness;

    var snapped: i32[24] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    var post: i64[24] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    i = 0;
    while i < n_float {
        snapped[i] = float_buf[i];
        i += 1;
    }
    var e: i64 = 0;
    while e < n_fixed - 1 {
        let exercise = fixed_buf[e];
        var j: i64 = 0;
        while j < n_float - 1 {
            let day = snapped[j];
            if day != exercise && day >= exercise - 7 && day <= exercise + 7 {
                snapped[j] = exercise;
                if day >= exercise - 7 && day <= exercise { post[j] = 1; }
            }
            j += 1;
        }
        e += 1;
    }

    var fr: f64[>..] = [];
    var fp: f64[>..] = [];
    var fa: f64[>..] = [];
    var ur: f64[>..] = [];
    var up: f64[>..] = [];
    var upost: i64[>..] = [];
    var ex: f64[>..] = [];
    i = 0;
    while i < n_fixed - 1 {
        let rs, rso = date::from_serial(fixed_buf[i]);
        let re, reo = date::from_serial(fixed_buf[i + 1]);
        if !rso || !reo { return 0.0, false; }
        let tau, tau_ok = yf30(rs, re);
        let tr, trok = yf365(settle, rs);
        let tp, tpok = yf365(settle, re);
        if !tau_ok || !trok || !tpok { return 0.0, false; }
        fr.push(tr);
        fp.push(tp);
        fa.push(1000.0 * strike * tau);
        ex.push(tr);
        i += 1;
    }
    i = 0;
    while i < n_float - 1 {
        let rs, rso = date::from_serial(snapped[i]);
        let re, reo = date::from_serial(snapped[i + 1]);
        if !rso || !reo { return 0.0, false; }
        let tr, trok = yf365(settle, rs);
        let tp, tpok = yf365(settle, re);
        if !trok || !tpok { return 0.0, false; }
        ur.push(tr);
        up.push(tp);
        upost.push(post[i]);
        i += 1;
    }

    var mand: f64[>..] = [];
    i = 0;
    while i < fr.len {
        if fr[i] >= 0.0 { mand.push(fr[i]); }
        if fp[i] >= 0.0 { mand.push(fp[i]); }
        i += 1;
    }
    i = 0;
    while i < ur.len {
        if ur[i] >= 0.0 { mand.push(ur[i]); }
        if up[i] >= 0.0 { mand.push(up[i]); }
        i += 1;
    }
    i = 0;
    while i < ex.len {
        if ex[i] >= 0.0 { mand.push(ex[i]); }
        i += 1;
    }
    if mand.len == 0 { return 0.0, false; }
    i = 1;
    while i < mand.len {
        let v = mand[i];
        var j = i;
        while j > 0 && mand[j - 1] > v {
            mand[j] = mand[j - 1];
            j -= 1;
        }
        mand[j] = v;
        i += 1;
    }
    var uniq: f64[>..] = [];
    i = 0;
    while i < mand.len {
        if uniq.len == 0 || !near(uniq[uniq.len - 1], mand[i]) { uniq.push(mand[i]); }
        i += 1;
    }
    if uniq[0] < 0.0 { return 0.0, false; }

    let revert = 0.048696;
    let vol = 0.0058904;
    let steps: i64 = 50;
    var times: f64[>..] = [];
    var dt: f64[>..] = [];
    let last = uniq[uniq.len - 1];
    let spacing = last / steps;
    times.push(0.0);
    var begin = 0.0;
    i = 0;
    while i < uniq.len {
        let end = uniq[i];
        if end != 0.0 {
            var n_add = ((end - begin) / spacing + 0.5) as i64;
            if n_add < 1 { n_add = 1; }
            let h = (end - begin) / n_add;
            var n: i64 = 1;
            while n <= n_add {
                times.push(begin + n * h);
                n += 1;
            }
        }
        begin = end;
        i += 1;
    }
    i = 0;
    while i < times.len - 1 {
        dt.push(times[i + 1] - times[i]);
        i += 1;
    }
    if dt.len == 0 { return 0.0, false; }

    var bad = false;
    var dx: f64[>..] = [];
    var jmin: i64[>..] = [];
    var origin: i64[>..] = [];
    var ks: i64[>..] = [];
    var p0: f64[>..] = [];
    var p1: f64[>..] = [];
    var p2: f64[>..] = [];
    var phi: f64[>..] = [];
    var sp: f64[>..] = [];
    var swap: f64[>..] = [];
    var nxt: f64[>..] = [];
    var bond: f64[>..] = [];
    var bond2: f64[>..] = [];
    var opt: f64[>..] = [];
    var opt2: f64[>..] = [];
    var swap_i: i64 = 0;
    var opt_i: i64 = 0;
    var ready: i64 = 0;

    fn ou_var(h: f64) -> f64 {
        if abs(revert) < sqrt(EPS) { return vol * vol * h; }
        return 0.5 * vol * vol / revert * (1.0 - exp(-2.0 * revert * h));
    }

    fn locate(t: f64) -> i64 {
        var lo: i64 = 0;
        var hi = times.len;
        while lo < hi {
            let mid = (lo + hi) / 2;
            if times[mid] < t { lo = mid + 1; } else { hi = mid; }
        }
        if lo == 0 { return 0; }
        if lo == times.len { return times.len - 1; }
        let dt1 = times[lo] - t;
        let dt2 = t - times[lo - 1];
        if dt1 < dt2 { return lo; }
        return lo - 1;
    }

    fn on_grid(t: f64) -> bool {
        return near(times[locate(t)], t);
    }

    fn nodes(at: i64) -> i64 {
        return origin[at + 1] - origin[at];
    }

    fn under(at: i64, j: i64) -> f64 {
        if at == 0 { return 0.0; }
        return (jmin[at] + j) * dx[at];
    }

    var v_max = 0.0;
    var dt_peak = 0.0;
    i = 0;
    while i < dt.len {
        let v2 = ou_var(dt[i]);
        if v2 > v_max { v_max = v2; }
        if dt[i] > dt_peak { dt_peak = dt[i]; }
        i += 1;
    }
    let dx_floor = sqrt(3.0 * v_max);
    dx.push(0.0);
    jmin.push(0);
    origin.push(0);
    var j_lo: i64 = 0;
    var j_hi: i64 = 0;
    var step: i64 = 0;
    while step < dt.len {
        let v2 = ou_var(dt[step]);
        let v = sqrt(v2);
        let dx_nat = v * sqrt(3.0);
        var dx_next = dx_nat;
        if dt[step] < 0.01 * dt_peak && dx_floor > dx_nat { dx_next = dx_floor; }
        let floored = dx_next > dx_nat;
        dx.push(dx_next);
        let dx2 = dx_next * dx_next;
        var k_min: i64 = 1000000000;
        var k_max: i64 = -1000000000;
        var index: i64 = 0;
        let count = j_hi - j_lo + 1;
        while index < count {
            let j_int = j_lo + index;
            let x = j_int * dx[step];
            let m = x * exp(-revert * dt[step]);
            let temp = floor_int(m / dx[step + 1] + 0.5);
            let drift = m - temp * dx[step + 1];
            let drift2 = drift * drift;
            var down = 0.0;
            var midp = 0.0;
            var up = 0.0;
            if floored {
                down = (v2 + drift2 - drift * dx_next) / (2.0 * dx2);
                midp = 1.0 - (v2 + drift2) / dx2;
                up = (v2 + drift2 + drift * dx_next) / (2.0 * dx2);
            } else {
                let drift3 = drift * sqrt(3.0);
                down = (1.0 + drift2 / v2 - drift3 / v) / 6.0;
                midp = (2.0 - drift2 / v2) / 3.0;
                up = (1.0 + drift2 / v2 + drift3 / v) / 6.0;
            }
            ks.push(temp);
            p0.push(down);
            p1.push(midp);
            p2.push(up);
            if temp < k_min { k_min = temp; }
            if temp > k_max { k_max = temp; }
            index += 1;
        }
        j_lo = k_min - 1;
        j_hi = k_max + 1;
        jmin.push(j_lo);
        origin.push(ks.len);
        step += 1;
    }
    let last_nodes = j_hi - j_lo + 1;
    origin.push(origin[origin.len - 1] + last_nodes);
    let n_times = times.len;
    phi.resize(dt.len, 0.0);
    sp.resize(origin[n_times], 0.0);
    sp[0] = 1.0;

    fn fill_states(until: i64) {
        while ready < until {
            let at = ready;
            let n1 = nodes(at + 1);
            var j: i64 = 0;
            while j < n1 {
                sp[origin[at + 1] + j] = 0.0;
                j += 1;
            }
            let n0 = nodes(at);
            j = 0;
            while j < n0 {
                let src = origin[at] + j;
                let x = under(at, j);
                let disc = exp(-(x + phi[at]) * dt[at]);
                let weight = sp[src] * disc;
                let d0 = ks[src] - jmin[at + 1] - 1;
                let dst = origin[at + 1] + d0;
                sp[dst] += weight * p0[src];
                sp[dst + 1] += weight * p1[src];
                sp[dst + 2] += weight * p2[src];
                j += 1;
            }
            ready += 1;
        }
    }

    fn step_back(at: i64, src: f64[:], dst: f64[:]) {
        let n0 = nodes(at);
        var j: i64 = 0;
        while j < n0 {
            let from = origin[at] + j;
            let d0 = ks[from] - jmin[at + 1] - 1;
            var acc = p0[from] * src[d0];
            acc += p1[from] * src[d0 + 1];
            acc += p2[from] * src[d0 + 2];
            let x = under(at, j);
            dst[j] = acc * exp(-(x + phi[at]) * dt[at]);
            j += 1;
        }
    }

    fn roll_to(pay_t: f64, to_i: i64) {
        if !on_grid(pay_t) { bad = true; return; }
        let i_from = locate(pay_t);
        if i_from < to_i { bad = true; return; }
        let n_from = nodes(i_from);
        bond.resize(n_from, 0.0);
        var z: i64 = 0;
        while z < n_from {
            bond[z] = 1.0;
            z += 1;
        }
        var at = i_from;
        while at > to_i {
            let n_prev = nodes(at - 1);
            bond2.resize(n_prev, 0.0);
            step_back(at - 1, bond, bond2);
            bond.resize(n_prev, 0.0);
            var j: i64 = 0;
            while j < n_prev {
                bond[j] = bond2[j];
                j += 1;
            }
            at -= 1;
        }
    }

    fn add_fixed(which: i64) {
        roll_to(fp[which], swap_i);
        if bad { return; }
        var j: i64 = 0;
        while j < swap.len {
            swap[j] -= fa[which] * bond[j];
            j += 1;
        }
    }

    fn add_float(which: i64) {
        roll_to(up[which], swap_i);
        if bad { return; }
        var j: i64 = 0;
        while j < swap.len {
            swap[j] += 1000.0 * (1.0 - bond[j]);
            j += 1;
        }
    }

    fn swap_pre() {
        let t = times[swap_i];
        var k: i64 = 0;
        while k < ur.len {
            if upost[k] == 0 && ur[k] >= 0.0 && on_grid(ur[k]) && near(times[locate(ur[k])], t) {
                add_float(k);
            }
            k += 1;
        }
        k = 0;
        while k < fr.len {
            if fr[k] >= 0.0 && on_grid(fr[k]) && near(times[locate(fr[k])], t) {
                add_fixed(k);
            }
            k += 1;
        }
    }

    fn layer_from(src: f64[:], at: i64, into: f64[>..]&) {
        let n = nodes(at);
        into.resize(n, 0.0);
        step_back(at, src, into);
    }

    i = 0;
    while i < dt.len {
        if i > ready { fill_states(i); }
        let h = dt[i];
        var x = under(i, 0);
        let gap = dx[i];
        var value = 0.0;
        var j: i64 = 0;
        let n0 = nodes(i);
        while j < n0 {
            value += sp[origin[i] + j] * exp(-x * h);
            x += gap;
            j += 1;
        }
        let bond_df = exp(-curve * times[i + 1]);
        phi[i] = log(value / bond_df) / h;
        i += 1;
    }
    fn copy_into(src: f64[:], into: f64[>..]&) {
        into.resize(src.len, 0.0);
        var j: i64 = 0;
        while j < src.len {
            into[j] = src[j];
            j += 1;
        }
    }

    var pay_t = up[up.len - 1];
    if fp[fp.len - 1] > pay_t { pay_t = fp[fp.len - 1]; }
    if !on_grid(pay_t) { return 0.0, false; }
    let pay_i = locate(pay_t);
    swap_i = pay_i;
    swap.resize(nodes(pay_i), 0.0);
    swap_pre();
    if bad { return 0.0, false; }

    fn exercise_here() {
        var k: i64 = 0;
        var hit = false;
        let t = times[opt_i];
        while k < ex.len {
            if ex[k] >= 0.0 && on_grid(ex[k]) && near(times[locate(ex[k])], t) { hit = true; }
            k += 1;
        }
        if !hit { return; }
        var j: i64 = 0;
        while j < opt.len {
            if swap[j] > opt[j] { opt[j] = swap[j]; }
            j += 1;
        }
    }

    fn bring_swap(i_to: i64) {
        if swap_i == i_to { return; }
        var at = swap_i - 1;
        while at >= i_to {
            layer_from(swap, at, nxt);
            copy_into(nxt, swap);
            swap_i = at;
            if at != i_to { swap_pre(); }
            at -= 1;
        }
    }

    fn opt_touch() {
        bring_swap(opt_i);
        swap_pre();
        exercise_here();
    }

    if ex.len == 0 { return 0.0, false; }
    let i_last = locate(ex[ex.len - 1]);
    if !on_grid(ex[ex.len - 1]) { return 0.0, false; }
    opt_i = i_last;
    opt.resize(nodes(i_last), 0.0);
    opt_touch();
    if bad { return 0.0, false; }
    let i_first = locate(ex[0]);
    if !on_grid(ex[0]) { return 0.0, false; }
    var cursor = opt_i - 1;
    while cursor >= i_first {
        layer_from(opt, cursor, opt2);
        copy_into(opt2, opt);
        opt_i = cursor;
        if cursor != i_first { opt_touch(); }
        if bad { return 0.0, false; }
        cursor -= 1;
    }
    opt_touch();
    if bad { return 0.0, false; }
    if opt_i > ready { fill_states(opt_i); }
    var pv = 0.0;
    var j: i64 = 0;
    while j < opt.len {
        pv += opt[j] * sp[origin[opt_i] + j];
        j += 1;
    }
    return pv, !bad;
}
