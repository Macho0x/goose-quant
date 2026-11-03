<p align="center">
  <img src="logo.png" alt="A goose wearing a badge with a yield curve" width="220">
</p>

<h1 align="center">goose-quant</h1>

<p align="center">
  Dates, day counts, calendars, and prices for <a href="https://github.com/aardappel/goose">Goose</a><br>
  <strong>0.1.0</strong> · <a href="LICENSE">QuantLib license</a>
</p>

A Goose port of [QuantLib](https://github.com/lballabio/QuantLib) 1.45-dev, commit `4b575ac561e0ddbc2c39f4621be13d890e9a9bae`. `Real` is `f64`. A date is QuantLib's Excel serial. The caller owns quotes, curves, and the evaluation date. There is no `shared_ptr`, `Handle`, or `Observer`.

## Example

```goose
import date from "../quant/date";
import daycount from "../quant/daycount";
import black from "../quant/black";

fn main() {
    let start, sok = date::from_ymd(20, date::AUGUST, 2006);
    let end, eok = date::from_ymd(20, date::FEBRUARY, 2007);
    if sok && eok {
        let yf, ok = daycount::year_fraction(daycount::actual360(), start, end, date::blank(), date::blank());
        if ok { print(yf); }
    }
    let px, pok = black::black(black::CALL, 100.0, 100.0, 0.2, 1.0, 0.0);
    if pok { print(px); }
}
```

## Check

Install the Goose compiler, then from this directory:

```sh
goose tests/self_check.goose
```

A good run prints `quant ok`. `tests/black_check.goose` prints `black ok`. `tests/money_check.goose` prints `money ok`. `tests/instruments_check.goose` prints `instruments ok`. `tests/sample_bonds.goose` prints the Bonds example table and `sample bonds ok`. `tests/barrier_check.goose` prints `barrier ok`. `tests/tree_check.goose` prints `tree ok`. `tests/baw_check.goose` prints `baw ok`. `tests/bjerk_check.goose` prints `bjerk ok`. `tests/asian_check.goose` prints `asian ok`. `tests/vasicek_check.goose` prints `vasicek ok`. `tests/integral_engine_check.goose` prints `integral engine ok`. `tests/gauss_check.goose` prints `gauss ok`. `tests/schedule_rules.goose` prints `schedule rules ok`. `tests/fitted_check.goose` prints `fitted ok`. `tests/multicurve_check.goose` prints `multicurve ok`. `tests/curve_suite.goose` prints `curve suite ok`.

## Benchmarks

`bench.goose` times this package. The row names stay fixed, so a clang run before a change and a clang run after it compare.

```sh
goose build -o quant-bench bench.goose
./quant-bench
```

`goose bench.goose` runs in TinyCC. That is not a timing result. Numbers depend on the machine, so this page does not publish them.

The rows are `actual/360 year fraction`, `target advance 1y`, `flat discount factor`, `black formula`, and `european npv`.

## License

QuantLib's modified BSD license. This package is a derivative work. The terms are in [LICENSE](LICENSE). What was kept, dropped, or renamed is in [PORTING.md](PORTING.md).
