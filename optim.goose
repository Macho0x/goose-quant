namespace optim;

import math;

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
