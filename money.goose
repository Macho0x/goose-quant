// Money is an amount and an ISO numeric code. Same-currency arithmetic
// stays in that code. One unit of source buys `rate` units of target.
// convert walks a list of pairs, direct or inverse.

namespace money;

struct Cash { amount: f64, numeric: i32 }

fn cash(amount: f64, numeric: i32) -> Cash {
    Cash { amount: amount, numeric: numeric }
}

fn scale(m: Cash, k: f64) -> Cash {
    Cash { amount: m.amount * k, numeric: m.numeric }
}

fn add(a: Cash, b: Cash) -> Cash, bool {
    if a.numeric != b.numeric { return cash(0.0, 0), false; }
    return cash(a.amount + b.amount, a.numeric), true;
}

fn sub(a: Cash, b: Cash) -> Cash, bool {
    if a.numeric != b.numeric { return cash(0.0, 0), false; }
    return cash(a.amount - b.amount, a.numeric), true;
}

fn ratio(a: Cash, b: Cash) -> f64, bool {
    if a.numeric != b.numeric || b.amount == 0.0 { return 0.0, false; }
    return a.amount / b.amount, true;
}

struct Pair { source: i32, target: i32, rate: f64 }

fn exchange(amount: f64, from: i32, to: i32, pair: Pair) -> f64, bool {
    if pair.rate == 0.0 { return 0.0, false; }
    if from == to { return amount, true; }
    if from == pair.source && to == pair.target { return amount * pair.rate, true; }
    if from == pair.target && to == pair.source { return amount / pair.rate, true; }
    return 0.0, false;
}

// ponytail: depth 4 stops a cycle. A longer chain needs a bigger cap.
recursive fn walk(amount: f64, from: i32, to: i32, pairs: Pair[:], depth: i32) -> f64, bool {
    if from == to { return amount, true; }
    if depth <= 0 { return 0.0, false; }
    var i: i64 = 0;
    while i < pairs.len {
        let got, ok = exchange(amount, from, pairs[i].target, pairs[i]);
        if ok && from != pairs[i].target {
            let next, nok = walk(got, pairs[i].target, to, pairs, depth - 1);
            if nok { return next, true; }
        }
        let back, bok = exchange(amount, from, pairs[i].source, pairs[i]);
        if bok && from != pairs[i].source {
            let next, nok = walk(back, pairs[i].source, to, pairs, depth - 1);
            if nok { return next, true; }
        }
        i += 1;
    }
    return 0.0, false;
}

fn convert(amount: f64, from: i32, to: i32, pairs: Pair[:]) -> f64, bool {
    return walk(amount, from, to, pairs, 4);
}

fn mid_equivalent(bid: f64, ask: f64, last: f64, close: f64) -> f64, bool {
    if bid > 0.0 {
        if ask > 0.0 { return (bid + ask) / 2.0, true; }
        return bid, true;
    }
    if ask > 0.0 { return ask, true; }
    if last > 0.0 { return last, true; }
    if close > 0.0 { return close, true; }
    return 0.0, false;
}

fn mid_safe(bid: f64, ask: f64) -> f64, bool {
    if bid <= 0.0 || ask <= 0.0 { return 0.0, false; }
    return (bid + ask) / 2.0, true;
}
