namespace optim;

import math;
import mt;

// ponytail: DE/rand/1/bin with an LCG, 400 generations. Use mt.goose and BestMemberWithJitter if a coordinate must match QuantLib's sample.

const POP: i64 = 50;
const GENS: i64 = 400;
const STEP: f64 = 0.6;
const RATE: f64 = 0.3;
const SEED: i64 = 127;

fn ackley(x: f64[:]) -> f64, bool {
    if x.len < 1 { return 0.0, false; }
    var p1 = 0.0;
    var p2 = 0.0;
    var i = 0;
    while i < x.len {
        p1 += x[i] * x[i];
        p2 += cos(2.0 * PI * x[i]);
        i += 1;
    }
    p1 = -0.2 * sqrt(0.5 * p1);
    p2 *= 0.5;
    return exp(1.0) + 20.0 - 20.0 * exp(p1) - exp(p2), true;
}

fn rosenbrock(x: f64[:]) -> f64, bool {
    if x.len < 2 { return 0.0, false; }
    var result = 0.0;
    var i = 0;
    while i < x.len - 1 {
        let temp = x[i + 1] - x[i] * x[i];
        result += (x[i] - 1.0) * (x[i] - 1.0) + 100.0 * temp * temp;
        i += 1;
    }
    return result, true;
}

fn eggholder(x: f64[:]) -> f64, bool {
    if x.len != 2 { return 0.0, false; }
    let p = x[1] + 47.0;
    return -p * sin(sqrt(abs(0.5 * x[0] + p))) - x[0] * sin(sqrt(abs(x[0] - p))), true;
}

fn next_u(s: u32&) -> u32 {
    s = 1664525 * s + 1013904223;
    return s;
}

fn next_f(s: u32&) -> f64 {
    return (next_u(s) + 0.5) / 4294967296.0;
}

fn roll(s: u32&, n: i64, a: i64, b: i64, c: i64) -> i64 {
    var r = a;
    while r == a || r == b || r == c {
        r = next_u(s) % n;
    }
    return r;
}

fn evolve<F>(start: f64[:], lo: f64[:], hi: f64[:], agents: i64, steps: i64, weight: f64, cross: f64, seed: i64, out: f64[>..]&) -> f64, bool {
    let n = start.len;
    if n < 1 || lo.len != n || hi.len != n || agents < 4 || steps < 1 { return 0.0, false; }
    if seed < 0 || weight < 0.0 || weight > 2.0 || cross < 0.0 || cross > 1.0 { return 0.0, false; }
    var i = 0;
    while i < n {
        if lo[i] >= hi[i] || start[i] < lo[i] || start[i] > hi[i] { return 0.0, false; }
        i += 1;
    }
    var state = seed as u32;
    var pop: f64[>..] = [];
    var cost: f64[>..] = [];
    var trial: f64[>..] = [];
    i = 0;
    while i < n {
        pop.push(start[i]);
        trial.push(start[i]);
        i += 1;
    }
    var best = F(trial[0..n]);
    var best_at = 0;
    cost.push(best);
    var a = 1;
    while a < agents {
        i = 0;
        while i < n {
            let x = lo[i] + (hi[i] - lo[i]) * next_f(state);
            pop.push(x);
            trial[i] = x;
            i += 1;
        }
        let y = F(trial[0..n]);
        cost.push(y);
        if y < best {
            best = y;
            best_at = a;
        }
        a += 1;
    }
    var gen = 0;
    while gen < steps {
        var member = 0;
        while member < agents {
            let r1 = roll(state, agents, member, -1, -1);
            let r2 = roll(state, agents, member, r1, -1);
            let r3 = roll(state, agents, member, r1, r2);
            let jrand = next_u(state) % n;
            var k = 0;
            while k < n {
                let draw = next_f(state);
                if draw < cross || k == jrand {
                    trial[k] = pop[r1 * n + k] + weight * (pop[r2 * n + k] - pop[r3 * n + k]);
                } else {
                    trial[k] = pop[member * n + k];
                }
                if trial[k] > hi[k] { trial[k] = hi[k]; }
                if trial[k] < lo[k] { trial[k] = lo[k]; }
                k += 1;
            }
            let y = F(trial[0..n]);
            if y <= cost[member] {
                k = 0;
                while k < n {
                    pop[member * n + k] = trial[k];
                    k += 1;
                }
                cost[member] = y;
                if y < best {
                    best = y;
                    best_at = member;
                }
            }
            member += 1;
        }
        gen += 1;
    }
    out.clear();
    i = 0;
    while i < n {
        out.push(pop[best_at * n + i]);
        i += 1;
    }
    return best, true;
}

fn eggholder_min(out: f64[>..]&) -> f64, bool {
    var start: f64[2] = [0.0, 0.0];
    var lo: f64[2] = [-512.0, -512.0];
    var hi: f64[2] = [512.0, 512.0];
    return evolve(start, lo, hi, POP, GENS, STEP, RATE, SEED, out) {
        let y, ok = eggholder(it);
        if ok { y } else { 1.0e300 }
    };
}

fn ackley_min(out: f64[>..]&) -> f64, bool {
    var start: f64[2] = [1.5, 1.5];
    var lo: f64[2] = [-5.0, -5.0];
    var hi: f64[2] = [5.0, 5.0];
    return evolve(start, lo, hi, POP, GENS, STEP, RATE, SEED, out) {
        let y, ok = ackley(it);
        if ok { y } else { 1.0e300 }
    };
}

fn rosenbrock_min(out: f64[>..]&) -> f64, bool {
    var start: f64[3] = [0.0, 0.0, 0.0];
    var lo: f64[3] = [-4.0, -4.0, -4.0];
    var hi: f64[3] = [4.0, 4.0, 4.0];
    return evolve(start, lo, hi, POP, GENS, STEP, RATE, SEED, out) {
        let y, ok = rosenbrock(it);
        if ok { y } else { 1.0e300 }
    };
}

// Firefly (eggholder) and particle swarm (Rosenbrock) use GlobalOptimizer's
// first settings. Every Mersenne Twister and std::mt19937 in those runs is
// seeded with SEED. The example leaves FireflyAlgorithm's own generator to
// the clock; 127 keeps the same seed the file already sets.
// ponytail: Jaeckel Sobol only through dimension 6, the largest start vector here.

struct Rank {
    y: f64,
    at: i64,
}

struct Sobol {
    dim: i64,
    counter: u32,
    first: bool,
    seq: u32[6],
    dir: u32[192],
}

const DEG: i64[5] = [1, 2, 3, 3, 4];
const PPMT: i64[5] = [0, 1, 1, 2, 1];
const NRAW: i64[5] = [1, 2, 3, 3, 4];
const RAW: u32[20] = [
    1, 0, 0, 0,
    1, 1, 0, 0,
    1, 3, 7, 0,
    1, 1, 5, 0,
    1, 3, 1, 1,
];

fn ql_real(g: mt::Twister&) -> f64 {
    return (mt::next_u32(g) + 0.5) / 4294967296.0;
}

fn canon(g: mt::Twister&) -> f64 {
    var ret = 1.0;
    while ret >= 1.0 {
        let a: u64 = mt::next_u32(g);
        let b: u64 = mt::next_u32(g);
        let sum = a | (b << 32);
        ret = sum / (4294967296.0 * 4294967296.0);
    }
    return ret;
}

fn draw_span(g: mt::Twister&, span: u32) -> u32 {
    let width: u64 = span;
    var r: u64 = mt::next_u32(g);
    var product = r * width;
    var low = (product & 0xffffffff) as! u32;
    if low < span {
        let threshold = (0 - span) % span;
        while low < threshold {
            r = mt::next_u32(g);
            product = r * width;
            low = (product & 0xffffffff) as! u32;
        }
    }
    return (product >> 32) as! u32;
}

fn before(a: Rank, b: Rank) -> bool {
    if a.y < b.y { return true; }
    if a.y > b.y { return false; }
    return a.at < b.at;
}

fn sort_ranks(xs: Rank[:]) {
    var i = 1;
    while i < xs.len {
        let v = xs[i];
        var j = i;
        while j > 0 && before(v, xs[j - 1]) {
            xs[j] = xs[j - 1];
            j -= 1;
        }
        xs[j] = v;
        i += 1;
    }
}

fn sobol_open(dim: i64) -> Sobol {
    var s = Sobol { dim: dim, counter: 0, first: true, seq: [0; 6], dir: [0; 192] };
    var j: i64 = 0;
    while j < 32 {
        s.dir[j] = (1 as u32) << ((31 - j) as u32);
        j += 1;
    }
    var k = 1;
    while k < dim {
        let gk = DEG[k - 1];
        let poly = PPMT[k - 1];
        var t = 0;
        while t < NRAW[k - 1] {
            s.dir[k * 32 + t] = RAW[(k - 1) * 4 + t] << ((31 - t) as u32);
            t += 1;
        }
        var l = gk;
        while l < 32 {
            var n = s.dir[k * 32 + (l - gk)] >> (gk as u32);
            t = 1;
            while t < gk {
                if ((poly >> (gk - t - 1)) & 1) != 0 {
                    n = n ^ s.dir[k * 32 + (l - t)];
                }
                t += 1;
            }
            n = n ^ s.dir[k * 32 + (l - gk)];
            s.dir[k * 32 + l] = n;
            l += 1;
        }
        k += 1;
    }
    k = 0;
    while k < dim {
        s.seq[k] = s.dir[k * 32];
        k += 1;
    }
    return s;
}

fn sobol_next(s: Sobol&, out: f64[:]) {
    if !s.first {
        s.counter += 1;
        var n = s.counter;
        var j: i64 = 0;
        while (n & 1) != 0 {
            n = n >> 1;
            j += 1;
        }
        var k = 0;
        while k < s.dim {
            s.seq[k] = s.seq[k] ^ s.dir[k * 32 + j];
            k += 1;
        }
    }
    s.first = false;
    var k = 0;
    while k < s.dim {
        out[k] = s.seq[k] * (0.5 / 2147483648.0);
        k += 1;
    }
}

fn set_weights(lo: f64[:], hi: f64[:], w: f64[:]) {
    var maxb = hi[0] - lo[0];
    var j = 1;
    while j < lo.len {
        let b = hi[j] - lo[j];
        if b > maxb { maxb = b; }
        j += 1;
    }
    j = 0;
    while j < lo.len {
        w[j] = (hi[j] - lo[j]) / maxb;
        j += 1;
    }
}

fn isotropic(eng: mt::Twister&, dir: mt::Twister&, w: f64[:], xm: f64, alpha: f64, out: f64[:], at: i64) {
    let dim = w.len;
    var radius = xm * pow(canon(eng), -1.0 / alpha);
    if dim > 1 {
        var phi = PI * ql_real(dir);
        var i = 0;
        while i < dim - 2 {
            out[at + i] = radius * cos(phi) * w[i];
            radius *= sin(phi);
            phi = PI * ql_real(dir);
            i += 1;
        }
        out[at + dim - 2] = radius * cos(2.0 * phi) * w[dim - 2];
        out[at + dim - 1] = radius * sin(2.0 * phi) * w[dim - 1];
    } else {
        var step = radius;
        if ql_real(dir) < 0.5 { step = -radius; }
        out[at] = step * w[0];
    }
}

fn egg_at(x: f64[:], i: i64) -> f64 {
    var p: f64[2] = [x[i * 2], x[i * 2 + 1]];
    let y, ok = eggholder(p);
    if ok { return y; }
    return 1.0e300;
}

fn ros_at(x: f64[:], i: i64) -> f64 {
    var p: f64[3] = [x[i * 3], x[i * 3 + 1], x[i * 3 + 2]];
    let y, ok = rosenbrock(p);
    if ok { return y; }
    return 1.0e300;
}

fn firefly_min(out: f64[>..]&) -> f64, bool {
    let agents = 150;
    let mde = 40;
    let mfa = agents - mde;
    let n = 2;
    let beta0 = 10.0;
    let beta_min = 1.0e-8;
    let gamma = 1.0;
    let alpha = 1.5;
    let xm = 0.5;
    let delta = 1.0;
    let mutation = 1.0;
    let cross = 0.5;
    let max_iter = 5000;
    let max_still = 1000;
    var lo: f64[2] = [-512.0, -512.0];
    var hi: f64[2] = [512.0, 512.0];
    var w: f64[2] = [1.0, 1.0];
    set_weights(lo, hi, w);
    var gen = default<mt::Twister>();
    var cross_rng = default<mt::Twister>();
    var eng = default<mt::Twister>();
    var dir = default<mt::Twister>();
    let seed = SEED as u32;
    mt::seed(gen, seed);
    mt::seed(cross_rng, seed);
    mt::seed(eng, seed);
    mt::seed(dir, seed);
    var x: f64[300] = [0.0; 300];
    var xI: f64[300] = [0.0; 300];
    var x_rw: f64[300] = [0.0; 300];
    var ranks: Rank[150] = [Rank { y: 0.0, at: 0 }; 150];
    var sob = sobol_open(n);
    var sample: f64[2] = [0.0, 0.0];
    var i = 0;
    while i < agents {
        sobol_next(sob, sample);
        var j = 0;
        while j < n {
            x[i * n + j] = lo[j] + (hi[j] - lo[j]) * sample[j];
            j += 1;
        }
        ranks[i].y = egg_at(x, i);
        ranks[i].at = i;
        i += 1;
    }
    var best_y = ranks[0].y;
    var best_at = 0;
    i = 1;
    while i < agents {
        if ranks[i].y < best_y {
            best_y = ranks[i].y;
            best_at = ranks[i].at;
        }
        i += 1;
    }
    var best: f64[2] = [x[best_at * n], x[best_at * n + 1]];
    var iteration = 0;
    var still = 0;
    var z: f64[2] = [0.0, 0.0];
    while true {
        iteration += 1;
        still += 1;
        if iteration > max_iter || still > max_still { break; }
        sort_ranks(ranks);
        let index_best = ranks[0].at;
        i = mfa;
        while i < agents {
            var r1 = 110 + (draw_span(gen, 40) as i64);
            while r1 == index_best {
                r1 = 110 + (draw_span(gen, 40) as i64);
            }
            var r2 = 110 + (draw_span(gen, 40) as i64);
            while r2 == index_best || r2 == r1 {
                r2 = 110 + (draw_span(gen, 40) as i64);
            }
            let index = ranks[i].at;
            let r_index = draw_span(gen, 2) as i64;
            var j = 0;
            while j < n {
                var take = j == r_index;
                if !take { take = ql_real(cross_rng) <= cross; }
                if take {
                    z[j] = x[index_best * n + j] + mutation * (x[r1 * n + j] - x[r2 * n + j]);
                } else {
                    z[j] = x[index * n + j];
                }
                if z[j] < lo[j] { z[j] = lo[j]; }
                else if z[j] > hi[j] { z[j] = hi[j]; }
                j += 1;
            }
            let val, vok = eggholder(z);
            if vok && val < ranks[index].y {
                j = 0;
                while j < n {
                    x[index * n + j] = z[j];
                    j += 1;
                }
                ranks[index].y = val;
                if val < best_y {
                    best_y = val;
                    best[0] = z[0];
                    best[1] = z[1];
                    still = 0;
                }
            }
            i += 1;
        }
        let bright = ranks[0].at;
        var j = 0;
        while j < n {
            xI[bright * n + j] = 0.0;
            j += 1;
        }
        i = 1;
        while i < mfa {
            let index = ranks[i].at;
            j = 0;
            while j < n {
                xI[index * n + j] = 0.0;
                j += 1;
            }
            var k = 0;
            while k < i - 1 {
                let y_index = ranks[k].at;
                var d = 0.0;
                j = 0;
                while j < n {
                    let diff = x[index * n + j] - x[y_index * n + j];
                    d += diff * diff;
                    j += 1;
                }
                let intense = (beta0 - beta_min) * exp(-gamma * d) + beta_min;
                j = 0;
                while j < n {
                    xI[index * n + j] += intense * (x[y_index * n + j] - x[index * n + j]);
                    j += 1;
                }
                k += 1;
            }
            i += 1;
        }
        i = 0;
        while i < mfa {
            let index = ranks[i].at;
            isotropic(eng, dir, w, xm, alpha, x_rw, index * n);
            j = 0;
            while j < n {
                x_rw[index * n + j] *= delta;
                j += 1;
            }
            i += 1;
        }
        i = 0;
        while i < mfa {
            let index = ranks[i].at;
            j = 0;
            while j < n {
                z[j] = x[index * n + j] + xI[index * n + j] + x_rw[index * n + j];
                if z[j] < lo[j] { z[j] = lo[j]; }
                else if z[j] > hi[j] { z[j] = hi[j]; }
                j += 1;
            }
            let val, vok = eggholder(z);
            if vok && !is_nan(val) {
                j = 0;
                while j < n {
                    x[index * n + j] = z[j];
                    j += 1;
                }
                ranks[index].y = val;
                if val < best_y {
                    best_y = val;
                    best[0] = z[0];
                    best[1] = z[1];
                    still = 0;
                }
            }
            i += 1;
        }
    }
    out.clear();
    out.push(best[0]);
    out.push(best[1]);
    return best_y, true;
}

fn swarm_min(out: f64[>..]&) -> f64, bool {
    let agents = 100;
    let n = 3;
    let kneigh = 25;
    let threshold = 500;
    let alpha = 1.5;
    let max_iter = 10000;
    let max_still = 1000;
    let c_self = 2.05;
    let c_social = 2.05;
    var lo: f64[3] = [-1.0, -1.0, -1.0];
    var hi: f64[3] = [4.0, 4.0, 4.0];
    var bounds: f64[3] = [5.0, 5.0, 5.0];
    var w: f64[3] = [1.0, 1.0, 1.0];
    set_weights(lo, hi, w);
    let phi = c_self + c_social;
    let c0 = 2.0 / abs(2.0 - phi - sqrt(phi * phi - 4.0 * phi));
    let c1 = c0 * c_self;
    let c2 = c0 * c_social;
    var vel = default<mt::Twister>();
    var inrng = default<mt::Twister>();
    var eng = default<mt::Twister>();
    var dir = default<mt::Twister>();
    let seed = SEED as u32;
    mt::seed(vel, seed);
    mt::seed(inrng, seed);
    mt::seed(eng, seed);
    mt::seed(dir, seed);
    var x: f64[300] = [0.0; 300];
    var v: f64[300] = [0.0; 300];
    var pbx: f64[300] = [0.0; 300];
    var gbx: f64[300] = [0.0; 300];
    var pbf: f64[100] = [0.0; 100];
    var personal: f64[100] = [0.0; 100];
    var counter: i64[100] = [0; 100];
    var sob = sobol_open(n * 2);
    var sample: f64[6] = [0.0; 6];
    var i = 0;
    while i < agents {
        sobol_next(sob, sample);
        var j = 0;
        while j < n {
            x[i * n + j] = lo[j] + bounds[j] * sample[2 * j];
            v[i * n + j] = bounds[j] * (2.0 * sample[2 * j + 1] - 1.0);
            pbx[i * n + j] = x[i * n + j];
            j += 1;
        }
        pbf[i] = ros_at(x, i);
        personal[i] = pbf[i];
        i += 1;
    }
    var best_y = pbf[0];
    var best_at = 0;
    i = 1;
    while i < agents {
        if pbf[i] < best_y {
            best_y = pbf[i];
            best_at = i;
        }
        i += 1;
    }
    var iteration = 0;
    var still = 0;
    while true {
        iteration += 1;
        still += 1;
        if iteration > max_iter || still > max_still { break; }
        i = 0;
        while i < agents {
            var best_f = pbf[i];
            var best_x = 0;
            var upper = i + kneigh;
            if upper > agents { upper = agents; }
            var lower = i;
            if kneigh + 1 > lower { lower = kneigh + 1; }
            lower = lower - kneigh - 1;
            var j = lower;
            while j < upper {
                if pbf[j] < best_f {
                    best_f = pbf[j];
                    best_x = j;
                }
                j += 1;
            }
            if i + kneigh >= agents {
                j = 0;
                while j < i + kneigh - agents {
                    if pbf[j] < best_f {
                        best_f = pbf[j];
                        best_x = j;
                    }
                    j += 1;
                }
            } else if i < kneigh {
                j = agents - (kneigh - i) - 1;
                while j < agents {
                    if pbf[j] < best_f {
                        best_f = pbf[j];
                        best_x = j;
                    }
                    j += 1;
                }
            }
            j = 0;
            while j < n {
                gbx[i * n + j] = pbx[best_x * n + j];
                j += 1;
            }
            i += 1;
        }
        i = 0;
        while i < agents {
            if pbf[i] < personal[i] {
                personal[i] = pbf[i];
                counter[i] = 0;
            } else {
                counter[i] += 1;
            }
            if counter[i] <= threshold {
                let scale = c0 * (0.5 + 0.5 * ql_real(inrng));
                var j = 0;
                while j < n {
                    v[i * n + j] *= scale;
                    j += 1;
                }
            } else {
                isotropic(eng, dir, w, 1.0, alpha, v, i * n);
            }
            i += 1;
        }
        i = 0;
        while i < agents {
            var j = 0;
            while j < n {
                v[i * n + j] += c1 * ql_real(vel) * (pbx[i * n + j] - x[i * n + j]) + c2 * ql_real(vel) * (gbx[i * n + j] - x[i * n + j]);
                x[i * n + j] += v[i * n + j];
                if x[i * n + j] < lo[j] {
                    x[i * n + j] = lo[j];
                    v[i * n + j] = 0.0;
                } else if x[i * n + j] > hi[j] {
                    x[i * n + j] = hi[j];
                    v[i * n + j] = 0.0;
                }
                j += 1;
            }
            let f = ros_at(x, i);
            if f < pbf[i] {
                pbf[i] = f;
                j = 0;
                while j < n {
                    pbx[i * n + j] = x[i * n + j];
                    j += 1;
                }
                if f < best_y {
                    best_y = f;
                    best_at = i;
                    still = 0;
                }
            }
            i += 1;
        }
    }
    out.clear();
    var j = 0;
    while j < n {
        out.push(pbx[best_at * n + j]);
        j += 1;
    }
    return best_y, true;
}

fn anneal_min(out: f64[>..]&) -> f64, bool {
    // T0=1, factor 0.9997, 100000 steps, reset to the best point every 400. Ackley (lambda 0.1, T 350, epsilon 0.99, 1000) is not this schedule.
    var x0 = 0.0;
    var x1 = 0.0;
    var y = 1.0;
    var b0 = 0.0;
    var b1 = 0.0;
    var best = y;
    var g = default<mt::Twister>();
    mt::seed(g, SEED as u32);
    var temp = 1.0;
    var i = 0;
    while i < 100000 {
        var n0 = x0 + temp * (mt::next_real(g) * 2.0 - 1.0);
        var n1 = x1 + temp * (mt::next_real(g) * 2.0 - 1.0);
        if n0 < -4.0 { n0 = -4.0; }
        if n0 > 4.0 { n0 = 4.0; }
        if n1 < -4.0 { n1 = -4.0; }
        if n1 > 4.0 { n1 = 4.0; }
        var p: f64[2] = [n0, n1];
        let nf, ok = rosenbrock(p);
        if ok {
            let d = nf - y;
            var take = d <= 0.0;
            if !take { take = exp(-d / temp) > mt::next_real(g); }
            if take {
                x0 = n0;
                x1 = n1;
                y = nf;
            }
            if nf < best {
                best = nf;
                b0 = n0;
                b1 = n1;
            }
        }
        i += 1;
        if i % 400 == 0 {
            x0 = b0;
            x1 = b1;
            y = best;
        }
        temp *= 0.9997;
    }
    out.clear();
    out.push(b0);
    out.push(b1);
    return best, true;
}
