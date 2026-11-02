// ISO currencies from QuantLib 1.45-dev. Rounding() stores no rounding.
// ClosestRounding(n) rounds to n places with digit 5. EUR is the one that does.

namespace currency;

struct Ccy {
    numeric: i32,
    fractions: i32,
    precision: i32,
    round: i32,
    ncode: i32,
    c0: u8,
    c1: u8,
    c2: u8,
    c3: u8,
}

const NONE: i32 = 0;
const CLOSEST: i32 = 3;

const TABLE: Ccy[111] = [
    Ccy { numeric: 784, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'A', c1: 'E', c2: 'D', c3: 0 },
    Ccy { numeric: 973, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'A', c1: 'O', c2: 'A', c3: 0 },
    Ccy { numeric: 32, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'A', c1: 'R', c2: 'S', c3: 0 },
    Ccy { numeric: 40, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'A', c1: 'T', c2: 'S', c3: 0 },
    Ccy { numeric: 36, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'A', c1: 'U', c2: 'D', c3: 0 },
    Ccy { numeric: 10003, fractions: 100000, precision: 0, round: NONE, ncode: 3, c0: 'B', c1: 'C', c2: 'H', c3: 0 },
    Ccy { numeric: 50, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'B', c1: 'D', c2: 'T', c3: 0 },
    Ccy { numeric: 56, fractions: 1, precision: 0, round: NONE, ncode: 3, c0: 'B', c1: 'E', c2: 'F', c3: 0 },
    Ccy { numeric: 100, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'B', c1: 'G', c2: 'L', c3: 0 },
    Ccy { numeric: 975, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'B', c1: 'G', c2: 'N', c3: 0 },
    Ccy { numeric: 48, fractions: 1000, precision: 0, round: NONE, ncode: 3, c0: 'B', c1: 'H', c2: 'D', c3: 0 },
    Ccy { numeric: 986, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'B', c1: 'R', c2: 'L', c3: 0 },
    Ccy { numeric: 10000, fractions: 100000, precision: 0, round: NONE, ncode: 3, c0: 'B', c1: 'T', c2: 'C', c3: 0 },
    Ccy { numeric: 72, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'B', c1: 'W', c2: 'P', c3: 0 },
    Ccy { numeric: 974, fractions: 1, precision: 0, round: NONE, ncode: 3, c0: 'B', c1: 'Y', c2: 'R', c3: 0 },
    Ccy { numeric: 124, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'C', c1: 'A', c2: 'D', c3: 0 },
    Ccy { numeric: 756, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'C', c1: 'H', c2: 'F', c3: 0 },
    Ccy { numeric: 990, fractions: 1, precision: 0, round: NONE, ncode: 3, c0: 'C', c1: 'L', c2: 'F', c3: 0 },
    Ccy { numeric: 152, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'C', c1: 'L', c2: 'P', c3: 0 },
    Ccy { numeric: 156, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'C', c1: 'N', c2: 'H', c3: 0 },
    Ccy { numeric: 156, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'C', c1: 'N', c2: 'Y', c3: 0 },
    Ccy { numeric: 170, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'C', c1: 'O', c2: 'P', c3: 0 },
    Ccy { numeric: 970, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'C', c1: 'O', c2: 'U', c3: 0 },
    Ccy { numeric: 196, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'C', c1: 'Y', c2: 'P', c3: 0 },
    Ccy { numeric: 203, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'C', c1: 'Z', c2: 'K', c3: 0 },
    Ccy { numeric: 10006, fractions: 100000, precision: 0, round: NONE, ncode: 4, c0: 'D', c1: 'A', c2: 'S', c3: 'H' },
    Ccy { numeric: 276, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'D', c1: 'E', c2: 'M', c3: 0 },
    Ccy { numeric: 208, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'D', c1: 'K', c2: 'K', c3: 0 },
    Ccy { numeric: 233, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'E', c1: 'E', c2: 'K', c3: 0 },
    Ccy { numeric: 818, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'E', c1: 'G', c2: 'P', c3: 0 },
    Ccy { numeric: 724, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'E', c1: 'S', c2: 'P', c3: 0 },
    Ccy { numeric: 230, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'E', c1: 'T', c2: 'B', c3: 0 },
    Ccy { numeric: 10002, fractions: 100000, precision: 0, round: NONE, ncode: 3, c0: 'E', c1: 'T', c2: 'C', c3: 0 },
    Ccy { numeric: 10001, fractions: 100000, precision: 0, round: NONE, ncode: 3, c0: 'E', c1: 'T', c2: 'H', c3: 0 },
    Ccy { numeric: 978, fractions: 100, precision: 2, round: CLOSEST, ncode: 3, c0: 'E', c1: 'U', c2: 'R', c3: 0 },
    Ccy { numeric: 246, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'F', c1: 'I', c2: 'M', c3: 0 },
    Ccy { numeric: 250, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'F', c1: 'R', c2: 'F', c3: 0 },
    Ccy { numeric: 826, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'G', c1: 'B', c2: 'P', c3: 0 },
    Ccy { numeric: 981, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'G', c1: 'E', c2: 'L', c3: 0 },
    Ccy { numeric: 936, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'G', c1: 'H', c2: 'S', c3: 0 },
    Ccy { numeric: 300, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'G', c1: 'R', c2: 'D', c3: 0 },
    Ccy { numeric: 344, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'H', c1: 'K', c2: 'D', c3: 0 },
    Ccy { numeric: 191, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'H', c1: 'R', c2: 'K', c3: 0 },
    Ccy { numeric: 348, fractions: 1, precision: 0, round: NONE, ncode: 3, c0: 'H', c1: 'U', c2: 'F', c3: 0 },
    Ccy { numeric: 360, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'I', c1: 'D', c2: 'R', c3: 0 },
    Ccy { numeric: 372, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'I', c1: 'E', c2: 'P', c3: 0 },
    Ccy { numeric: 376, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'I', c1: 'L', c2: 'S', c3: 0 },
    Ccy { numeric: 356, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'I', c1: 'N', c2: 'R', c3: 0 },
    Ccy { numeric: 368, fractions: 1000, precision: 0, round: NONE, ncode: 3, c0: 'I', c1: 'Q', c2: 'D', c3: 0 },
    Ccy { numeric: 364, fractions: 1, precision: 0, round: NONE, ncode: 3, c0: 'I', c1: 'R', c2: 'R', c3: 0 },
    Ccy { numeric: 352, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'I', c1: 'S', c2: 'K', c3: 0 },
    Ccy { numeric: 380, fractions: 1, precision: 0, round: NONE, ncode: 3, c0: 'I', c1: 'T', c2: 'L', c3: 0 },
    Ccy { numeric: 400, fractions: 1000, precision: 0, round: NONE, ncode: 3, c0: 'J', c1: 'O', c2: 'D', c3: 0 },
    Ccy { numeric: 392, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'J', c1: 'P', c2: 'Y', c3: 0 },
    Ccy { numeric: 404, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'K', c1: 'E', c2: 'S', c3: 0 },
    Ccy { numeric: 410, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'K', c1: 'R', c2: 'W', c3: 0 },
    Ccy { numeric: 414, fractions: 1000, precision: 0, round: NONE, ncode: 3, c0: 'K', c1: 'W', c2: 'D', c3: 0 },
    Ccy { numeric: 398, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'K', c1: 'Z', c2: 'T', c3: 0 },
    Ccy { numeric: 144, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'L', c1: 'K', c2: 'R', c3: 0 },
    Ccy { numeric: 10005, fractions: 100000, precision: 0, round: NONE, ncode: 3, c0: 'L', c1: 'T', c2: 'C', c3: 0 },
    Ccy { numeric: 440, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'L', c1: 'T', c2: 'L', c3: 0 },
    Ccy { numeric: 442, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'L', c1: 'U', c2: 'F', c3: 0 },
    Ccy { numeric: 428, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'L', c1: 'V', c2: 'L', c3: 0 },
    Ccy { numeric: 504, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'M', c1: 'A', c2: 'D', c3: 0 },
    Ccy { numeric: 807, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'M', c1: 'K', c2: 'D', c3: 0 },
    Ccy { numeric: 470, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'M', c1: 'T', c2: 'L', c3: 0 },
    Ccy { numeric: 480, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'M', c1: 'U', c2: 'R', c3: 0 },
    Ccy { numeric: 484, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'M', c1: 'X', c2: 'N', c3: 0 },
    Ccy { numeric: 979, fractions: 1, precision: 0, round: NONE, ncode: 3, c0: 'M', c1: 'X', c2: 'V', c3: 0 },
    Ccy { numeric: 458, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'M', c1: 'Y', c2: 'R', c3: 0 },
    Ccy { numeric: 566, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'N', c1: 'G', c2: 'N', c3: 0 },
    Ccy { numeric: 528, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'N', c1: 'L', c2: 'G', c3: 0 },
    Ccy { numeric: 578, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'N', c1: 'O', c2: 'K', c3: 0 },
    Ccy { numeric: 524, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'N', c1: 'P', c2: 'R', c3: 0 },
    Ccy { numeric: 554, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'N', c1: 'Z', c2: 'D', c3: 0 },
    Ccy { numeric: 512, fractions: 1000, precision: 0, round: NONE, ncode: 3, c0: 'O', c1: 'M', c2: 'R', c3: 0 },
    Ccy { numeric: 999, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'P', c1: 'E', c2: 'H', c3: 0 },
    Ccy { numeric: 998, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'P', c1: 'E', c2: 'I', c3: 0 },
    Ccy { numeric: 604, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'P', c1: 'E', c2: 'N', c3: 0 },
    Ccy { numeric: 608, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'P', c1: 'H', c2: 'P', c3: 0 },
    Ccy { numeric: 586, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'P', c1: 'K', c2: 'R', c3: 0 },
    Ccy { numeric: 985, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'P', c1: 'L', c2: 'N', c3: 0 },
    Ccy { numeric: 620, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'P', c1: 'T', c2: 'E', c3: 0 },
    Ccy { numeric: 634, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'Q', c1: 'A', c2: 'R', c3: 0 },
    Ccy { numeric: 642, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'R', c1: 'O', c2: 'L', c3: 0 },
    Ccy { numeric: 946, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'R', c1: 'O', c2: 'N', c3: 0 },
    Ccy { numeric: 941, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'R', c1: 'S', c2: 'D', c3: 0 },
    Ccy { numeric: 643, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'R', c1: 'U', c2: 'B', c3: 0 },
    Ccy { numeric: 682, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'S', c1: 'A', c2: 'R', c3: 0 },
    Ccy { numeric: 752, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'S', c1: 'E', c2: 'K', c3: 0 },
    Ccy { numeric: 702, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'S', c1: 'G', c2: 'D', c3: 0 },
    Ccy { numeric: 705, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'S', c1: 'I', c2: 'T', c3: 0 },
    Ccy { numeric: 703, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'S', c1: 'K', c2: 'K', c3: 0 },
    Ccy { numeric: 764, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'T', c1: 'H', c2: 'B', c3: 0 },
    Ccy { numeric: 788, fractions: 1000, precision: 0, round: NONE, ncode: 3, c0: 'T', c1: 'N', c2: 'D', c3: 0 },
    Ccy { numeric: 792, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'T', c1: 'R', c2: 'L', c3: 0 },
    Ccy { numeric: 949, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'T', c1: 'R', c2: 'Y', c3: 0 },
    Ccy { numeric: 780, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'T', c1: 'T', c2: 'D', c3: 0 },
    Ccy { numeric: 901, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'T', c1: 'W', c2: 'D', c3: 0 },
    Ccy { numeric: 980, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'U', c1: 'A', c2: 'H', c3: 0 },
    Ccy { numeric: 800, fractions: 1, precision: 0, round: NONE, ncode: 3, c0: 'U', c1: 'G', c2: 'X', c3: 0 },
    Ccy { numeric: 840, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'U', c1: 'S', c2: 'D', c3: 0 },
    Ccy { numeric: 858, fractions: 1, precision: 0, round: NONE, ncode: 3, c0: 'U', c1: 'Y', c2: 'U', c3: 0 },
    Ccy { numeric: 860, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'U', c1: 'Z', c2: 'S', c3: 0 },
    Ccy { numeric: 862, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'V', c1: 'E', c2: 'B', c3: 0 },
    Ccy { numeric: 704, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'V', c1: 'N', c2: 'D', c3: 0 },
    Ccy { numeric: 952, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'X', c1: 'O', c2: 'F', c3: 0 },
    Ccy { numeric: 10004, fractions: 100000, precision: 0, round: NONE, ncode: 3, c0: 'X', c1: 'R', c2: 'P', c3: 0 },
    Ccy { numeric: 710, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'Z', c1: 'A', c2: 'R', c3: 0 },
    Ccy { numeric: 10007, fractions: 100000, precision: 0, round: NONE, ncode: 3, c0: 'Z', c1: 'E', c2: 'C', c3: 0 },
    Ccy { numeric: 967, fractions: 100, precision: 0, round: NONE, ncode: 3, c0: 'Z', c1: 'M', c2: 'W', c3: 0 },
];

fn blank() -> Ccy {
    Ccy { numeric: 0, fractions: 0, precision: 0, round: NONE, ncode: 0, c0: 0, c1: 0, c2: 0, c3: 0 }
}

fn by_code(code: u8[:]) -> Ccy, bool {
    if code.len < 3 || code.len > 4 { return blank(), false; }
    var i: i64 = 0;
    while i < TABLE.len {
        let c = TABLE[i];
        if c.ncode == code.len && c.c0 == code[0] && c.c1 == code[1] && c.c2 == code[2] {
            if c.ncode == 3 || c.c3 == code[3] { return c, true; }
        }
        i += 1;
    }
    return blank(), false;
}

fn name(code: u8[:]) -> u8[:], bool {
    if code == "AED" { return "United Arab Emirates dirham", true; }
    if code == "AOA" { return "Angolan kwanza", true; }
    if code == "ARS" { return "Argentinian peso", true; }
    if code == "ATS" { return "Austrian shilling", true; }
    if code == "AUD" { return "Australian dollar", true; }
    if code == "BCH" { return "Bitcoin Cash", true; }
    if code == "BDT" { return "Bangladesh taka", true; }
    if code == "BEF" { return "Belgian franc", true; }
    if code == "BGL" { return "Bulgarian lev", true; }
    if code == "BGN" { return "Bulgarian lev", true; }
    if code == "BHD" { return "Bahraini dinar", true; }
    if code == "BRL" { return "Brazilian real", true; }
    if code == "BTC" { return "Bitcoin", true; }
    if code == "BWP" { return "Botswanan pula", true; }
    if code == "BYR" { return "Belarussian ruble", true; }
    if code == "CAD" { return "Canadian dollar", true; }
    if code == "CHF" { return "Swiss franc", true; }
    if code == "CLF" { return "Unidad de Fomento (funds code)", true; }
    if code == "CLP" { return "Chilean peso", true; }
    if code == "CNH" { return "Chinese yuan (Hong Kong)", true; }
    if code == "CNY" { return "Chinese yuan", true; }
    if code == "COP" { return "Colombian peso", true; }
    if code == "COU" { return "Unidad de Valor Real (UVR) (funds code)", true; }
    if code == "CYP" { return "Cyprus pound", true; }
    if code == "CZK" { return "Czech koruna", true; }
    if code == "DASH" { return "Dash coin", true; }
    if code == "DEM" { return "Deutsche mark", true; }
    if code == "DKK" { return "Danish krone", true; }
    if code == "EEK" { return "Estonian kroon", true; }
    if code == "EGP" { return "Egyptian pound", true; }
    if code == "ESP" { return "Spanish peseta", true; }
    if code == "ETB" { return "Ethiopian birr", true; }
    if code == "ETC" { return "Ethereum Classic", true; }
    if code == "ETH" { return "Ethereum", true; }
    if code == "EUR" { return "European Euro", true; }
    if code == "FIM" { return "Finnish markka", true; }
    if code == "FRF" { return "French franc", true; }
    if code == "GBP" { return "British pound sterling", true; }
    if code == "GEL" { return "Georgian lari", true; }
    if code == "GHS" { return "Ghanaian cedi", true; }
    if code == "GRD" { return "Greek drachma", true; }
    if code == "HKD" { return "Hong Kong dollar", true; }
    if code == "HRK" { return "Croatian kuna", true; }
    if code == "HUF" { return "Hungarian forint", true; }
    if code == "IDR" { return "Indonesian Rupiah", true; }
    if code == "IEP" { return "Irish punt", true; }
    if code == "ILS" { return "Israeli shekel", true; }
    if code == "INR" { return "Indian rupee", true; }
    if code == "IQD" { return "Iraqi dinar", true; }
    if code == "IRR" { return "Iranian rial", true; }
    if code == "ISK" { return "Iceland krona", true; }
    if code == "ITL" { return "Italian lira", true; }
    if code == "JOD" { return "Jordanian dinar", true; }
    if code == "JPY" { return "Japanese yen", true; }
    if code == "KES" { return "Kenyan shilling", true; }
    if code == "KRW" { return "South-Korean won", true; }
    if code == "KWD" { return "Kuwaiti dinar", true; }
    if code == "KZT" { return "Kazakstanti Tenge", true; }
    if code == "LKR" { return "Sri Lankan rupee", true; }
    if code == "LTC" { return "Litecoin", true; }
    if code == "LTL" { return "Lithuanian litas", true; }
    if code == "LUF" { return "Luxembourg franc", true; }
    if code == "LVL" { return "Latvian lat", true; }
    if code == "MAD" { return "Moroccan dirham", true; }
    if code == "MKD" { return "Macedonian denar", true; }
    if code == "MTL" { return "Maltese lira", true; }
    if code == "MUR" { return "Mauritian rupee", true; }
    if code == "MXN" { return "Mexican peso", true; }
    if code == "MXV" { return "Mexican Unidad de Inversion", true; }
    if code == "MYR" { return "Malaysian Ringgit", true; }
    if code == "NGN" { return "Nigerian Naira", true; }
    if code == "NLG" { return "Dutch guilder", true; }
    if code == "NOK" { return "Norwegian krone", true; }
    if code == "NPR" { return "Nepal rupee", true; }
    if code == "NZD" { return "New Zealand dollar", true; }
    if code == "OMR" { return "Omani rial", true; }
    if code == "PEH" { return "Peruvian sol", true; }
    if code == "PEI" { return "Peruvian inti", true; }
    if code == "PEN" { return "Peruvian nuevo sol", true; }
    if code == "PHP" { return "Philippine peso", true; }
    if code == "PKR" { return "Pakistani rupee", true; }
    if code == "PLN" { return "Polish zloty", true; }
    if code == "PTE" { return "Portuguese escudo", true; }
    if code == "QAR" { return "Qatari riyal", true; }
    if code == "ROL" { return "Romanian leu", true; }
    if code == "RON" { return "Romanian new leu", true; }
    if code == "RSD" { return "Serbian dinar", true; }
    if code == "RUB" { return "Russian ruble", true; }
    if code == "SAR" { return "Saudi riyal", true; }
    if code == "SEK" { return "Swedish krona", true; }
    if code == "SGD" { return "Singapore dollar", true; }
    if code == "SIT" { return "Slovenian tolar", true; }
    if code == "SKK" { return "Slovak koruna", true; }
    if code == "THB" { return "Thai baht", true; }
    if code == "TND" { return "Tunisian dinar", true; }
    if code == "TRL" { return "Turkish lira", true; }
    if code == "TRY" { return "New Turkish lira", true; }
    if code == "TTD" { return "Trinidad & Tobago dollar", true; }
    if code == "TWD" { return "Taiwan dollar", true; }
    if code == "UAH" { return "Ukrainian hryvnia", true; }
    if code == "UGX" { return "Ugandan shilling", true; }
    if code == "USD" { return "U.S. dollar", true; }
    if code == "UYU" { return "Uruguayan peso", true; }
    if code == "UZS" { return "Uzbekistani Som", true; }
    if code == "VEB" { return "Venezuelan bolivar", true; }
    if code == "VND" { return "Vietnamese Dong", true; }
    if code == "XOF" { return "West African CFA franc", true; }
    if code == "XRP" { return "Ripple", true; }
    if code == "ZAR" { return "South-African rand", true; }
    if code == "ZEC" { return "Zcash", true; }
    if code == "ZMW" { return "Zambian kwacha", true; }
    return "", false;
}
