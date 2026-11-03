import os;
import quant from "..";
import quant.hedge;

fn ::main() {
    if !hedge::prove() { exit(1); }
    let dev21, form21, dev84, form84, ok = hedge::show();
    if !ok || !hedge::finite(dev21) || !hedge::finite(form21) || !hedge::finite(dev84) || !hedge::finite(form84) {
        write_stdout("hedge finite\n");
        exit(1);
    }
    write_stdout("hedge ok\n");
}
