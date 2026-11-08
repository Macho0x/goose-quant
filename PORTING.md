# Porting notes

Source: QuantLib `master` at `4b575ac561e0ddbc2c39f4621be13d890e9a9bae`, `QL_VERSION` 1.45-dev. The C++ tree is not part of this package. Behavior is checked against the QuantLib test-suite values.

## Kept on purpose

- A date is the Excel serial. 367 is 1 January 1901. 109574 is 31 December 2199. Serial 0 is the blank date. 1900 is a leap year, matching Excel and QuantLib's table.
- Weekday numbers are Excel's: Sunday is 1 and Saturday is 7.
- `QL_CHECK_CLOSE` tolerances in the tests we port are percent tolerances. `QL_CHECK_CLOSE_FRACTION` is a fraction.
- Business-day conventions are the QuantLib rules, including half-month modified following and nearest.
- The error function is Sun's fdlibm rational approximation, the one QuantLib ships. The cumulative normal uses it, with the same tail expansion. The inverse normal is Acklam's approximation with the Halley step left off, as in the QuantLib sources.
- Black's formula takes volatility times the square root of time, QuantLib's `stdDev`. Call is `1` and put is `-1`.
- Currency rows are the QuantLib `Data` constructors: ISO code, numeric code, fractions per unit, and the rounding stored on that currency. `Rounding()` means no rounding. Euro uses closest rounding to 2 places.

## Left out

These test C++ machinery rather than a market result. They are not ported:

- `compiledboostversion.cpp`
- `observable.cpp`
- `lazyobject.cpp`

Also left out of the Goose API: `shared_ptr`, `Handle`, `Observer`, `LazyObject`, the visitor, Boost, and the config headers. High-resolution dates (`QL_HIGH_RESOLUTION_DATE`) are not the default build and are not ported. `ql/legacy` is ported only when a surviving test or example calls it.

A QuantLib exception on bad input is a trailing `false` from the function that was asked to do the work.

## Names

| QuantLib | Goose |
| --- | --- |
| `Date` | `date::Date`, field `serial` |
| `Date()` null | `date::blank()` |
| `Period` | `period::Span` |
| `DayCounter` | `daycount::Count` |
| `Actual/360` | `daycount::actual360()` |
| `Actual/365 (Fixed)` | `daycount::actual365_fixed()` |
| `30/360 Bond Basis` | `daycount::thirty360_bond()` |
| `30/360 USA` | `daycount::thirty360_usa()` |
| `30/360 European` | `daycount::thirty360_euro()` |
| `30/365` | `daycount::make(daycount::T365)` |
| `Actual/Actual (ISDA)` | `daycount::actual_actual_isda()` |
| `Actual/Actual (ISMA)` | `daycount::actual_actual_isma()` |
| `Actual/Actual (AFB)` | `daycount::actual_actual_afb()` |
| `Business/252` | `daycount::business252()`, Brazil settlement calendar |
| `Calendar::adjust` / `advance` | `calendar::adjust` / `calendar::advance` |
| `TARGET` | `markets::TARGET` |
| `Germany` settlement, Frankfurt, Xetra, Eurex, Euwax | `markets_west` kinds 10–14 |
| `Austria` settlement and exchange | `markets_west` kinds 15–16 |
| `Switzerland` | `markets_west::SWITZERLAND` (17) |
| `France` settlement and exchange | `markets_west` kinds 18–19 |
| `Italy` settlement and exchange | `markets_west` kinds 20–21 |
| `Denmark`, `Finland`, `Iceland`, `Norway`, `Sweden` | `markets_north` kinds 40–44 |
| `UnitedKingdom::Exchange` and `Metals` | `markets_north` kinds 45–46 |
| Argentina, Australia, Canada, Chile, Mexico, New Zealand, US markets other than settlement, Brazil exchange | `markets_americas` kinds 110–125 |
| India NSE, Indonesia BEJ/JSX/IDX, Malaysia KLSE, Philippines PSE, Singapore SGX, Thailand | `markets_seasia` kinds 180–187 |
| Czech Republic, Hungary, Poland, Romania, Russia, Slovakia, Slovenia, Ukraine, Croatia, Serbia, Montenegro, North Macedonia, Malta | `markets_east` kinds 70–85 |
| China SSE and IB, Hong Kong, Japan, South Korea settlement and KRX, Taiwan | `markets_asia` kinds 150–156 |
| Israel settlement, TASE, SHIR, and Telbor; Saudi Arabia; South Africa; Turkey; Botswana; Uzbekistan | `markets_other` kinds 210–218 |
| `Schedule` backward, forward, and zero | `schedule::build` |
| `UnitedStates::Settlement` | `markets::US_SETTLEMENT` |
| `UnitedKingdom::Settlement` | `markets::UK_SETTLEMENT` |
| `Brazil::Settlement` | `markets::BRAZIL` |
| `InterestRate` | `rate::compound_factor`, `rate::discount_factor`, `rate::implied_rate` |
| `FlatForward::discount` | `curve::flat_discount` |
| `blackFormula` | `black::black` |
| `AnalyticEuropeanEngine` | `european::npv` |
| `Currency` | `currency::by_code` |
| `Money` | `money::Cash` |
| `ExchangeRate` | `money::Pair`, `money::exchange`, `money::convert` |
| `Rounding` | `rounding::apply` |
| `midEquivalent` / `midSafe` | `money::mid_equivalent`, `money::mid_safe` |
| `Settings::evaluationDate` | `rate::Settings.evaluation` |
| `Brent` / `Newton` | `solver::brent`, `solver::newton` |
| `blackFormulaImpliedStdDev` | `black::implied_std` |
| `CashFlows::npv` | `cash::yield_npv`, `cash::curve_npv` |
| `CashFlows::duration` simple | `cashflow::simple_duration` |
| `CashFlows::nextCouponRate` | `cashflow::next_coupon_rate` |
| `CashFlows::bps` | `cash::leg_bps` |
| implied and zero-spreaded discounts | `curve::implied_discount`, `curve::zero_spreaded_discount` |
| last pillar on a log-linear discount curve | `cash::fit_discount`, `cash::fit_clean`, `cash::fit_par` |
| `ForwardRateAgreement` amount | `cash::fra_amount` |
| par swap rate | `cash::par_rate` |
| `JointCalendar` | `calendar::joint_business` |
| `AnalyticBarrierEngine` | `barrier::npv` |
| binomial vanilla trees | `tree::jr`, `tree::crr`, `tree::additive`, `tree::trigeorgis`, `tree::tian`, `tree::leisen`, `tree::joshi` |
| `BaroneAdesiWhaleyApproximationEngine` | `baw::npv` |
| `BondForward` | `examples/repo.goose` |
| indexed-coupon FRA bootstrap | `examples/fra.goose` |
| `BjerksundStenslandApproximationEngine` | `bjerk::npv` |
| `QdFpAmericanEngine` fast, accurate, and high-precision schemes | `qd::npv_fast`, `qd::npv_accurate`, `qd::npv_high` |
| `IntegralEngine` | `vanilla_integral::npv` |
| `FdBlackScholesVanillaEngine` | `fd::npv` |
| crude Monte Carlo European put | `mc::european_put` |
| Sobol European put | `qmc::european_put` |
| Longstaff-Schwartz American put | `lsmc::american_put` |
| discrete hedging replication error | `hedge::show` |
| `AnalyticBlackVasicekEngine` | `vasicek::npv` |
| `AnalyticHestonEngine` | `heston::npv` |
| `BatesEngine` | `bates::npv` |
| continuous geometric Asian | `asian::npv` |
| order-15 Gauss-Hermite | `gauss::integrate` |
| CDS schedule and `cdsMaturity` | `schedule::build_cds`, `schedule::cds_maturity` |
| Twentieth and ThirdWednesday schedules | `schedule::build_twentieth`, `schedule::third_wednesday` |
| CDS hazard bootstrap | `credit::calibrate` |
| exponential spline fitted bond curve | `fitted::splines` |
| Eonia plus Euribor 6M bootstrap | `multicurve::verify` |
| `CustomIborIndex` value, fixing, and maturity dates | `index::value_date`, `index::fixing_date`, `index::maturity_date` |
| `HullWhite::convexityBias` | `hullwhite::convexity_bias` |
| 50-step Hull-White Bermudan swaption | `hullwhite::bermudan` |
| 50-step G2 Bermudan swaption | `g2tree::price` |
| BermudanSwaption diagonal calibration | `bermudan_cal::calibrate_hw`, `bermudan_cal::calibrate_g2` |
| calibrated Hull-White and G2 bermudan trees | `hullwhite::bermudan_at`, `g2tree::price_deal` |
| `G2::discountBond` | `gauss1d::discount_bond` |
| `CPI::laggedFixing` flat and linear | `inflation::lagged_fixing`, `inflation::linear_fixing` |
| `BlackCallableZeroCouponBondEngine` clean price | `callable::price` |
| Hull-White callable, puttable, and callable-puttable tree clean prices | `callable::tree_clean`, `callable::tree_put`, `callable::tree_both` |
| one-step lognormal caplet and its Monte Carlo mean | `lmm::caplet`, `lmm::one_step` |
| European zero-coupon Tsiveriotis-Fernandes | `convertible::npv` |
| 801-step CRR zero-coupon convertible | `convertible::crr` |
| eggholder, Ackley, and Rosenbrock differential evolution | `optim::eggholder_min`, `optim::ackley_min`, `optim::rosenbrock_min` |
| firefly eggholder and particle-swarm Rosenbrock | `optim::firefly_min`, `optim::swarm_min` |
| one-factor Gaussian joint survival and expected loss | `latent::joint_survival`, `latent::expected_loss` |
| Gaussian and Student-t probability of at least N defaults | `latent::prob_at_least`, `latent::prob_at_least_t` |
| Gaussian large-homogeneous-pool tranche loss | `basket::expected_tranche_loss` |
| Gaussian random-default and random-loss tranche means | `basket::random_default_tranche`, `basket::random_loss_tranche` |
| payer swap CVA and the basis-point fair-rate correction | `cva::amount`, `cva::correction` |

Market kind numbers above 9 live in `markets_west`, `markets_north`, `markets_east`, `markets_americas`, `markets_asia`, `markets_seasia`, and `markets_other` as those files land. Each file's header lists its constants.
