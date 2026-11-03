import os;
import quant from "..";
import quant.optim;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn show(name: u8[:], x: f64[:], y: f64) {
    var line: u8[>..] = [];
    format(line, name);
    var i = 0;
    while i < x.len {
        format(line, " ");
        format(line, x[i]);
        i += 1;
    }
    format(line, " ");
    format(line, y);
    format(line, "\n");
    write_stdout(line);
}

fn ::main() {
    var out: f64[>..] = [];
    let egg, eok = optim::eggholder_min(out);
    if !eok { fail("eggholder"); }
    show("eggholder", out, egg);
    let ack, aok = optim::ackley_min(out);
    if !aok { fail("ackley"); }
    show("ackley", out, ack);
    let ros, rok = optim::rosenbrock_min(out);
    if !rok { fail("rosenbrock"); }
    show("rosenbrock", out, ros);
    let fly, fok = optim::firefly_min(out);
    if !fok { fail("firefly"); }
    show("firefly", out, fly);
    let swarm, sok = optim::swarm_min(out);
    if !sok { fail("swarm"); }
    show("swarm", out, swarm);
    write_stdout("optimizer ok\n");
}
