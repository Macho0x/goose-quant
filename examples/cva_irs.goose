import os;
import quant from "..";
import quant.cva;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn show(years: i32, low: f64, med: f64, high: f64) {
    var line: u8[>..] = [];
    format(line, years);
    format(line, "Y ");
    format(line, low);
    format(line, " ");
    format(line, med);
    format(line, " ");
    format(line, high);
    format(line, "\n");
    write_stdout(line);
}

fn ::main() {
    var i: i64 = 0;
    while i < 6 {
        let years = cva::TENOR[i];
        let low, lok = cva::correction(years, cva::LOW, cva::RECOVERY_LOW);
        let med, mok = cva::correction(years, cva::MEDIUM, cva::RECOVERY_MEDIUM);
        let high, hok = cva::correction(years, cva::HIGH, cva::RECOVERY_HIGH);
        if !lok || !mok || !hok { fail("cva"); }
        show(years, low, med, high);
        i += 1;
    }
    write_stdout("cva irs ok\n");
}
