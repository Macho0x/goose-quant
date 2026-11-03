import os;
import quant from "..";
import quant.latent;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn ::main() {
    let pd, ok = latent::default_probability(1.0);
    if !ok { fail("hazard"); }
    var same: f64[3] = [pd, pd, pd];
    let indep, iok = latent::joint_survival(same, 0.0);
    let s = 1.0 - pd;
    if !iok || indep != s * s * s { fail("independence"); }

    let p2, a2 = latent::default_probability(2.0);
    let p5, a5 = latent::default_probability(5.0);
    if !a2 || !a5 { fail("tenor"); }
    var book: f64[3] = [pd, p2, p5];
    let survived, sok = latent::joint_survival(book, 1.0);
    var worst = pd;
    if p2 > worst { worst = p2; }
    if p5 > worst { worst = p5; }
    if !sok || survived != 1.0 - worst { fail("perfect"); }

    let got, gok = latent::integrated_default(pd, latent::factor_weight());
    if !gok { fail("integral"); }
    var gap = got - pd;
    if gap < 0.0 { gap = -gap; }
    if gap > 1.0e-8 { fail("marginal"); }

    let mid, mok = latent::joint_survival(same, latent::factor_weight());
    if !mok || mid <= s * s * s || mid >= s { fail("copula"); }
    write_stdout("latent ok\n");
}
