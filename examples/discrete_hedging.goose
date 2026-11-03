import os;
import quant from "..";
import quant.hedge;

fn ::main() {
    let dev21, form21, dev84, form84, ok = hedge::show();
    if !ok || !hedge::finite(dev21) || !hedge::finite(form21) || !hedge::finite(dev84) || !hedge::finite(form84) {
        exit(1);
    }
}
