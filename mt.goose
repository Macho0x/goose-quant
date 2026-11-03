// QuantLib's MersenneTwisterUniformRng. 32-bit words, period 2^19937-1.
// Seed 0 is rejected: QuantLib would read the clock, and this port does not.

namespace mt;

const N = 624;
const M = 397;
const MATRIX_A: u32 = 0x9908b0df;
const UPPER: u32 = 0x80000000;
const LOWER: u32 = 0x7fffffff;
const MIX: u32 = 1812433253;
const TEMPER_B: u32 = 0x9d2c5680;
const TEMPER_C: u32 = 0xefc60000;

struct Twister {
    st: u32[N],
    mti: i64,
}

fn mag(y: u32) -> u32 {
    if (y & 1) == 0 { return 0; }
    return MATRIX_A;
}

fn seed(g: Twister&, s: u32) {
    g.st[0] = s;
    var i: i64 = 1;
    while i < N {
        let prev = g.st[i - 1];
        g.st[i] = MIX * (prev ^ (prev >> 30)) + (i as u32);
        i += 1;
    }
    g.mti = N;
}

fn twist(g: Twister&) {
    var kk: i64 = 0;
    while kk < N - M {
        let y = (g.st[kk] & UPPER) | (g.st[kk + 1] & LOWER);
        g.st[kk] = g.st[kk + M] ^ (y >> 1) ^ mag(y);
        kk += 1;
    }
    while kk < N - 1 {
        let y = (g.st[kk] & UPPER) | (g.st[kk + 1] & LOWER);
        g.st[kk] = g.st[kk + M - N] ^ (y >> 1) ^ mag(y);
        kk += 1;
    }
    let y = (g.st[N - 1] & UPPER) | (g.st[0] & LOWER);
    g.st[N - 1] = g.st[M - 1] ^ (y >> 1) ^ mag(y);
    g.mti = 0;
}

fn next_u32(g: Twister&) -> u32 {
    if g.mti == N { twist(g); }
    var y = g.st[g.mti];
    g.mti += 1;
    y = y ^ (y >> 11);
    y = y ^ ((y << 7) & TEMPER_B);
    y = y ^ ((y << 15) & TEMPER_C);
    y = y ^ (y >> 18);
    return y;
}

fn next_real(g: Twister&) -> f64 {
    return (next_u32(g) + 0.5) / 4294967296.0;
}
