// G2++ bermudan on the 15 Sep 2016 cached TreeSwaptionEngine deal.
// Fifty-step two-factor lattice, at-par coupons, tolerance 0.005.

import math;
import date;
import period;
import calendar;
import markets;
import schedule;
import daycount;

namespace g2tree;

const EPS: f64 = 2.2204460492503131e-16;
const CURVE: f64 = 0.04875825;
const SPEED_X: f64 = 0.1;
const VOL_X: f64 = 0.01;
const SPEED_Y: f64 = 0.2;
const VOL_Y: f64 = 0.013;
const RHO: f64 = -0.5;
const NOMINAL: f64 = 1000.0;
const STEPS: i64 = 50;

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

fn ou_var(speed: f64, vol: f64, h: f64) -> f64 {
    if abs(speed) < sqrt(EPS) { return vol * vol * h; }
    return 0.5 * vol * vol / speed * (1.0 - exp(-2.0 * speed * h));
}

fn fitting(t: f64) -> f64 {
    let temp1 = VOL_X * (1.0 - exp(-SPEED_X * t)) / SPEED_X;
    let temp2 = VOL_Y * (1.0 - exp(-SPEED_Y * t)) / SPEED_Y;
    return 0.5 * temp1 * temp1 + 0.5 * temp2 * temp2 + RHO * temp1 * temp2 + CURVE;
}

// Branch weight for a negative factor correlation. m is the 3x3 lattice mix.
fn mix(b1: i64, b2: i64) -> f64 {
    if b1 == b2 {
        if b1 == 1 { return 8.0; }
        return -1.0;
    }
    if b1 + b2 == 2 { return 5.0; }
    return -4.0;
}

fn build_factor(speed: f64, vol: f64, step_dt: f64[:], dx: f64[>..] &, jmin: i64[>..] &, origin: i64[>..] &, ks: i64[>..] &, p0: f64[>..] &, p1: f64[>..] &, p2: f64[>..] &) {
    var v_max = 0.0;
    var dt_peak = 0.0;
    var i: i64 = 0;
    while i < step_dt.len {
        let v2 = ou_var(speed, vol, step_dt[i]);
        if v2 > v_max { v_max = v2; }
        if step_dt[i] > dt_peak { dt_peak = step_dt[i]; }
        i += 1;
    }
    let dx_floor = sqrt(3.0 * v_max);
    dx.push(0.0);
    jmin.push(0);
    origin.push(0);
    var j_lo: i64 = 0;
    var j_hi: i64 = 0;
    var step: i64 = 0;
    while step < step_dt.len {
        let v2 = ou_var(speed, vol, step_dt[step]);
        let v = sqrt(v2);
        let dx_nat = v * sqrt(3.0);
        var dx_next = dx_nat;
        if step_dt[step] < 0.01 * dt_peak && dx_floor > dx_nat { dx_next = dx_floor; }
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
            let mean = x * exp(-speed * step_dt[step]);
            let temp = floor_int(mean / dx[step + 1] + 0.5);
            let drift = mean - temp * dx[step + 1];
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
}

// Payer bermudan. moneyness scales the fair fixed rate of the 1y x 5y swap.
fn price(moneyness: f64) -> f64, bool {
    if moneyness <= 0.0 { return 0.0, false; }
    var hole: i32[1] = [0];
    let empty = hole[0..0];
    let settle, sok = date::from_ymd(19, 9, 2016);
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
        let fwd = (exp(-CURVE * tr) / exp(-CURVE * te) - 1.0) / span;
        float_npv += NOMINAL * span * fwd * exp(-CURVE * te);
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
        annuity += NOMINAL * tau * exp(-CURVE * tp);
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
        fa.push(NOMINAL * strike * tau);
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

    var times: f64[>..] = [];
    var step_dt: f64[>..] = [];
    let last = uniq[uniq.len - 1];
    let spacing = last / STEPS;
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
        step_dt.push(times[i + 1] - times[i]);
        i += 1;
    }
    if step_dt.len == 0 { return 0.0, false; }

    var x_dx: f64[>..] = [];
    var x_jmin: i64[>..] = [];
    var x_origin: i64[>..] = [];
    var x_ks: i64[>..] = [];
    var x_p0: f64[>..] = [];
    var x_p1: f64[>..] = [];
    var x_p2: f64[>..] = [];
    var y_dx: f64[>..] = [];
    var y_jmin: i64[>..] = [];
    var y_origin: i64[>..] = [];
    var y_ks: i64[>..] = [];
    var y_p0: f64[>..] = [];
    var y_p1: f64[>..] = [];
    var y_p2: f64[>..] = [];
    build_factor(SPEED_X, VOL_X, step_dt, x_dx, x_jmin, x_origin, x_ks, x_p0, x_p1, x_p2);
    build_factor(SPEED_Y, VOL_Y, step_dt, y_dx, y_jmin, y_origin, y_ks, y_p0, y_p1, y_p2);
    if x_dx.len != times.len || y_dx.len != times.len { return 0.0, false; }
    if x_origin.len != times.len + 1 || y_origin.len != times.len + 1 { return 0.0, false; }

    var phi: f64[>..] = [];
    phi.resize(step_dt.len, 0.0);
    i = 0;
    while i < step_dt.len {
        phi[i] = fitting(times[i]);
        i += 1;
    }

    var bad = false;
    var swap: f64[>..] = [];
    var nxt: f64[>..] = [];
    var bond: f64[>..] = [];
    var bond2: f64[>..] = [];
    var opt: f64[>..] = [];
    var opt2: f64[>..] = [];
    var sp: f64[>..] = [];
    var hold: f64[>..] = [];
    var swap_i: i64 = 0;
    var opt_i: i64 = 0;
    var pre_mark: i64 = -1;
    var post_mark: i64 = -1;
    let rho_abs = abs(RHO);

    fn x_nodes(at: i64) -> i64 { return x_origin[at + 1] - x_origin[at]; }
    fn y_nodes(at: i64) -> i64 { return y_origin[at + 1] - y_origin[at]; }
    fn size2(at: i64) -> i64 { return x_nodes(at) * y_nodes(at); }

    fn locate(t: f64) -> i64 {
        var lo: i64 = 0;
        var hi = times.len;
        while lo < hi {
            let mid = (lo + hi) / 2;
            if times[mid] < t { lo = mid + 1; } else { hi = mid; }
        }
        if lo == 0 { return 0; }
        if lo == times.len { return times.len - 1; }
        let left = times[lo] - t;
        let right = t - times[lo - 1];
        if left < right { return lo; }
        return lo - 1;
    }

    fn on_grid(t: f64) -> bool { return near(times[locate(t)], t); }

    fn on_time(t: f64, at: i64) -> bool {
        if t < 0.0 || !on_grid(t) { return false; }
        return near(times[locate(t)], times[at]);
    }

    fn prob_xy(at: i64, ix: i64, iy: i64, b1: i64, b2: i64) -> f64 {
        let xb = x_origin[at] + ix;
        let yb = y_origin[at] + iy;
        var px = x_p0[xb];
        if b1 == 1 { px = x_p1[xb]; }
        if b1 == 2 { px = x_p2[xb]; }
        var py = y_p0[yb];
        if b2 == 1 { py = y_p1[yb]; }
        if b2 == 2 { py = y_p2[yb]; }
        return px * py + rho_abs * mix(b1, b2) / 36.0;
    }

    fn desc_xy(at: i64, ix: i64, iy: i64, b1: i64, b2: i64) -> i64 {
        let kx = x_ks[x_origin[at] + ix];
        let ky = y_ks[y_origin[at] + iy];
        let dxn = kx - x_jmin[at + 1] - 1 + b1;
        let dyn = ky - y_jmin[at + 1] - 1 + b2;
        return dxn + dyn * x_nodes(at + 1);
    }

    fn discount(at: i64, ix: i64, iy: i64) -> f64 {
        let r = phi[at] + (x_jmin[at] + ix) * x_dx[at] + (y_jmin[at] + iy) * y_dx[at];
        return exp(-r * step_dt[at]);
    }

    fn copy_into(src: f64[:], into: f64[>..] &) {
        into.resize(src.len, 0.0);
        var j: i64 = 0;
        while j < src.len {
            into[j] = src[j];
            j += 1;
        }
    }

    fn step_back(at: i64, src: f64[:], dst: f64[:]) {
        let nx = x_nodes(at);
        let ny = y_nodes(at);
        var iy: i64 = 0;
        while iy < ny {
            var ix: i64 = 0;
            while ix < nx {
                var acc = 0.0;
                var b2: i64 = 0;
                while b2 < 3 {
                    var b1: i64 = 0;
                    while b1 < 3 {
                        acc += prob_xy(at, ix, iy, b1, b2) * src[desc_xy(at, ix, iy, b1, b2)];
                        b1 += 1;
                    }
                    b2 += 1;
                }
                dst[ix + iy * nx] = acc * discount(at, ix, iy);
                ix += 1;
            }
            iy += 1;
        }
    }

    fn roll_to(pay_t: f64, to_i: i64) {
        if !on_grid(pay_t) { bad = true; return; }
        let i_from = locate(pay_t);
        if i_from < to_i { bad = true; return; }
        let n_from = size2(i_from);
        bond.resize(n_from, 0.0);
        var z: i64 = 0;
        while z < n_from {
            bond[z] = 1.0;
            z += 1;
        }
        var at = i_from;
        while at > to_i {
            let n_prev = size2(at - 1);
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
        if bond.len != swap.len { bad = true; return; }
        var j: i64 = 0;
        while j < swap.len {
            swap[j] -= fa[which] * bond[j];
            j += 1;
        }
    }

    fn add_float(which: i64) {
        roll_to(up[which], swap_i);
        if bad { return; }
        if bond.len != swap.len { bad = true; return; }
        var j: i64 = 0;
        while j < swap.len {
            swap[j] += NOMINAL * (1.0 - bond[j]);
            j += 1;
        }
    }

    fn pre_now() {
        if pre_mark == swap_i { return; }
        pre_mark = swap_i;
        var k: i64 = 0;
        while k < ur.len {
            if upost[k] == 0 && on_time(ur[k], swap_i) {
                add_float(k);
                if bad { return; }
            }
            k += 1;
        }
        k = 0;
        while k < fr.len {
            if on_time(fr[k], swap_i) {
                add_fixed(k);
                if bad { return; }
            }
            k += 1;
        }
    }

    fn post_now() {
        if post_mark == swap_i { return; }
        post_mark = swap_i;
        var k: i64 = 0;
        while k < ur.len {
            if upost[k] == 1 && on_time(ur[k], swap_i) {
                add_float(k);
                if bad { return; }
            }
            k += 1;
        }
    }

    fn layer_from(src: f64[:], at: i64, into: f64[>..] &) {
        let n = size2(at);
        into.resize(n, 0.0);
        step_back(at, src, into);
    }

    fn bring_swap(i_to: i64) {
        while swap_i > i_to {
            layer_from(swap, swap_i - 1, nxt);
            copy_into(nxt, swap);
            swap_i -= 1;
            if swap_i != i_to {
                pre_now();
                if bad { return; }
                post_now();
                if bad { return; }
            }
        }
    }

    fn exercise_here() {
        var k: i64 = 0;
        var hit = false;
        while k < ex.len {
            if on_time(ex[k], opt_i) { hit = true; }
            k += 1;
        }
        if !hit { return; }
        if swap.len != opt.len { bad = true; return; }
        var j: i64 = 0;
        while j < opt.len {
            if swap[j] > opt[j] { opt[j] = swap[j]; }
            j += 1;
        }
    }

    fn opt_touch() {
        bring_swap(opt_i);
        if bad { return; }
        pre_now();
        if bad { return; }
        exercise_here();
        if bad { return; }
        post_now();
    }

    if up.len == 0 || fp.len == 0 || ex.len == 0 { return 0.0, false; }
    var pay_t = up[up.len - 1];
    if fp[fp.len - 1] > pay_t { pay_t = fp[fp.len - 1]; }
    if !on_grid(pay_t) { return 0.0, false; }
    let pay_i = locate(pay_t);
    swap_i = pay_i;
    swap.resize(size2(pay_i), 0.0);
    pre_now();
    post_now();
    if bad { return 0.0, false; }

    let i_last = locate(ex[ex.len - 1]);
    if !on_grid(ex[ex.len - 1]) { return 0.0, false; }
    opt_i = i_last;
    opt.resize(size2(i_last), 0.0);
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

    sp.resize(1, 0.0);
    sp[0] = 1.0;
    var ready: i64 = 0;
    while ready < i_first {
        let at = ready;
        let n1 = size2(at + 1);
        hold.resize(n1, 0.0);
        var z: i64 = 0;
        while z < n1 {
            hold[z] = 0.0;
            z += 1;
        }
        let nx = x_nodes(at);
        let ny = y_nodes(at);
        var iy: i64 = 0;
        while iy < ny {
            var ix: i64 = 0;
            while ix < nx {
                let w = sp[ix + iy * nx] * discount(at, ix, iy);
                var b2: i64 = 0;
                while b2 < 3 {
                    var b1: i64 = 0;
                    while b1 < 3 {
                        let dest = desc_xy(at, ix, iy, b1, b2);
                        hold[dest] += w * prob_xy(at, ix, iy, b1, b2);
                        b1 += 1;
                    }
                    b2 += 1;
                }
                ix += 1;
            }
            iy += 1;
        }
        copy_into(hold, sp);
        ready += 1;
    }
    if opt.len != sp.len || opt.len == 0 { return 0.0, false; }
    var pv = 0.0;
    var j: i64 = 0;
    while j < opt.len {
        pv += opt[j] * sp[j];
        j += 1;
    }
    if is_nan(pv) || is_inf(pv) { return 0.0, false; }
    return pv, !bad;
}
