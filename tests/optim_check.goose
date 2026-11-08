import os;
import quant from "..";
import quant.optim;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn gap(got: f64, want: f64) -> f64 {
    var d = got - want;
    if d < 0.0 { d = -d; }
    return d;
}

fn ::main() {
    var one: f64[1] = [0.0];
    let ev, eok = optim::eggholder(one);
    if eok || ev != 0.0 { fail("eggholder size"); }
    let rv, rok = optim::rosenbrock(one);
    if rok || rv != 0.0 { fail("rosenbrock size"); }
    var none: f64[>..] = [];
    let av, aok = optim::ackley(none);
    if aok || av != 0.0 { fail("ackley size"); }
    var out: f64[>..] = [];
    let bad, bok = optim::evolve(none, none, none, 10, 10, 0.6, 0.3, 127, out) { it.len * 0.0 };
    if bok || bad != 0.0 { fail("evolve"); }

    let egg, gok = optim::eggholder_min(out);
    if !gok || out.len != 2 { fail("eggholder run"); }
    var spot: f64[2] = [512.0, 404.2319];
    let want, wok = optim::eggholder(spot);
    if !wok { fail("eggholder optimum"); }
    var rel = (egg - want) / want;
    if rel < 0.0 { rel = -rel; }
    if rel >= 1.0e-6 { fail("eggholder value"); }
    let back, b2 = optim::eggholder(out);
    if !b2 || back != egg { fail("eggholder point"); }

    let ack, cok = optim::ackley_min(out);
    if !cok || out.len != 2 || gap(ack, 0.0) > 1.0e-6 { fail("ackley"); }
    let aback, a2 = optim::ackley(out);
    if !a2 || aback != ack { fail("ackley point"); }

    let ros, sok = optim::rosenbrock_min(out);
    if !sok || out.len != 3 || gap(ros, 0.0) > 1.0e-6 { fail("rosenbrock"); }
    let rback, r2 = optim::rosenbrock(out);
    if !r2 || rback != ros { fail("rosenbrock point"); }

    let fly, fok = optim::firefly_min(out);
    if !fok || out.len != 2 { fail("firefly run"); }
    var relf = (fly - want) / want;
    if relf < 0.0 { relf = -relf; }
    if relf >= 1.0e-6 { fail("firefly value"); }
    let fback, f2 = optim::eggholder(out);
    if !f2 || fback != fly { fail("firefly point"); }

    let swarm, wok = optim::swarm_min(out);
    if !wok || out.len != 3 || gap(swarm, 0.0) >= 1.0e-6 { fail("swarm"); }
    let sback, s2 = optim::rosenbrock(out);
    if !s2 || sback != swarm { fail("swarm point"); }

    let ann, nok = optim::anneal_min(out);
    if !nok || out.len != 2 || gap(ann, 0.0) > 1.0e-6 { fail("anneal"); }
    let nback, n2 = optim::rosenbrock(out);
    if !n2 || nback != ann { fail("anneal point"); }

    write_stdout("optim ok\n");
}
