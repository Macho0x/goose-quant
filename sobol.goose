// QuantLib's SobolRsg in one dimension, Gray code on.
// Direction integer j is 1 << (31-j). Construction stores direction 0,
// the Gray code of 1, and never emits the origin. The first uniform is 1/2.
// nextSequence scales the integer by 0.5 / (1 << 31).

namespace sobol;

const TOP: u32 = 0x80000000;

struct Rsg {
    x: u32,
    n: u32,
    first: bool,
}

fn open() -> Rsg {
    return Rsg { x: TOP, n: 0, first: true };
}

fn next_u32(g: Rsg&) -> u32 {
    if g.first {
        g.first = false;
        return g.x;
    }
    g.n += 1;
    var bits = g.n;
    var j: u32 = 0;
    while (bits & 1) != 0 {
        bits = bits >> 1;
        j += 1;
    }
    g.x = g.x ^ (TOP >> j);
    return g.x;
}

fn next_uniform(g: Rsg&) -> f64 {
    return next_u32(g) * (0.5 / 2147483648.0);
}
