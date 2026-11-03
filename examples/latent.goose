// LatentModel example, 19 March 2014, three names, notional 100,
// flat hazard -ln(0.99). Horizon is the sample's 120-month date.
// Expected loss is notional times the default probability. The factor
// loading cancels in that sum; the copula is checked in the test.

import os;
import quant from "..";
import quant.date;
import quant.period;
import quant.calendar;
import quant.markets;
import quant.daycount;
import quant.schedule;
import quant.latent;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn horizon() -> f64, bool {
    let raw, ok = date::from_ymd(19, date::MARCH, 2014);
    if !ok { return 0.0, false; }
    let today, tok = schedule::adjusted(markets::TARGET, raw, calendar::FOLLOWING);
    if !tok { return 0.0, false; }
    let calc, cok = calendar::advance_span(markets::TARGET, today, period::months(120), calendar::FOLLOWING, false);
    if !cok { return 0.0, false; }
    return daycount::year_fraction(daycount::actual365_fixed(), today, calc, date::blank(), date::blank());
}

fn ::main() {
    let t, tok = horizon();
    if !tok { fail("date"); }
    let loss, ok = latent::expected_loss(latent::NOTIONAL, t, latent::NAMES);
    if !ok { fail("loss"); }
    var line: u8[>..] = [];
    format(line, loss);
    format(line, "\nlatent ok\n");
    write_stdout(line);
}
