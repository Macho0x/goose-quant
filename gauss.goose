// Order-15 Gauss-Hermite quadrature, weight exp(-x*x).
// Nodes are Newton roots of the degree-15 Hermite polynomial.
// Weights are the Christoffel numbers divided by the weight, so
// integrate(f) approximates the integral of f from -inf to inf,
// the same split QuantLib's GaussianQuadrature uses.

import math;

namespace gauss;

const PIM4: f64 = 0.7511255444649425;

fn integrate<F>() -> f64 {
    var sum = 0.0;
    var z = 0.0;
    var older = 0.0;
    var old = 0.0;
    var i: i32 = 0;
    while i < 8 {
        if i == 0 {
            z = sqrt(31.0) - 1.85575 * pow(31.0, -0.16667);
        } else if i == 1 {
            z = z - 1.14 * pow(15.0, 0.426) / z;
        } else if i == 2 {
            z = 1.86 * z - 0.86 * older;
        } else if i == 3 {
            z = 1.91 * z - 0.91 * older;
        } else {
            z = 2.0 * z - older;
        }

        var its: i32 = 0;
        var pp = 0.0;
        var p1 = 0.0;
        var p2 = 0.0;
        while its < 10 {
            p1 = PIM4;
            p2 = 0.0;
            var j = 1.0;
            while j <= 15.0 {
                let p3 = p2;
                p2 = p1;
                p1 = z * sqrt(2.0 / j) * p2 - sqrt((j - 1.0) / j) * p3;
                j += 1.0;
            }
            pp = sqrt(30.0) * p2;
            let z1 = z;
            if pp != 0.0 { z = z1 - p1 / pp; }
            var diff = z - z1;
            if diff < 0.0 { diff = -diff; }
            its += 1;
            if diff <= 3.0e-14 { break; }
        }

        var w = 0.0;
        if pp != 0.0 { w = 2.0 * exp(z * z) / (pp * pp); }
        sum += w * F(z);
        if i != 7 { sum += w * F(-z); }
        older = old;
        old = z;
        i += 1;
    }
    return sum;
}
