import os;
import quant from "..";
import quant.date;
import quant.period;
import quant.daycount;
import quant.calendar;
import quant.markets;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn near(got: f64, want: f64) -> bool {
    var d = got - want;
    if d < 0.0 { d = -d; }
    return d <= 1.0e-10;
}

fn ymd(day: i32, m: i32, y: i32) -> date::Date {
    let d, ok = date::from_ymd(day, m, y);
    if !ok { fail("ymd"); }
    return d;
}

fn in_hol(hol: i32[:], day: i32, m: i32, y: i32) -> bool {
    var i: i64 = 0;
    while i + 2 < hol.len {
        if hol[i] == day && hol[i + 1] == m && hol[i + 2] == y { return true; }
        i += 3;
    }
    return false;
}

fn check_holidays(kind: i32, from: date::Date, to: date::Date, hol: i32[:]) {
    var hole: i32[1] = [0];
    var serial = from.serial;
    while serial <= to.serial {
        let t, ok = date::from_serial(serial);
        if !ok { fail("holiday serial"); }
        let w = date::weekday(t);
        let weekend = w == date::SATURDAY || w == date::SUNDAY;
        let biz = calendar::is_business_day(kind, t, hole[0..0], hole[0..0]);
        let day = date::day_of_month(t);
        let m = date::month(t);
        let y = date::year(t);
        let listed = in_hol(hol, day, m, y);
        if !weekend && !biz && !listed { fail("extra holiday"); }
        if listed && biz { fail("missed holiday"); }
        serial += 1;
    }
}

const TARGET_HOL: i32[111] = [
    1, 1, 1999, 31, 12, 1999,
    21, 4, 2000, 24, 4, 2000, 1, 5, 2000, 25, 12, 2000, 26, 12, 2000,
    1, 1, 2001, 13, 4, 2001, 16, 4, 2001, 1, 5, 2001, 25, 12, 2001, 26, 12, 2001, 31, 12, 2001,
    1, 1, 2002, 29, 3, 2002, 1, 4, 2002, 1, 5, 2002, 25, 12, 2002, 26, 12, 2002,
    1, 1, 2003, 18, 4, 2003, 21, 4, 2003, 1, 5, 2003, 25, 12, 2003, 26, 12, 2003,
    1, 1, 2004, 9, 4, 2004, 12, 4, 2004,
    25, 3, 2005, 28, 3, 2005, 26, 12, 2005,
    14, 4, 2006, 17, 4, 2006, 1, 5, 2006, 25, 12, 2006, 26, 12, 2006,
];

const BRAZIL_HOL: i32[60] = [
    7, 2, 2005, 8, 2, 2005, 25, 3, 2005, 21, 4, 2005, 26, 5, 2005,
    7, 9, 2005, 12, 10, 2005, 2, 11, 2005, 15, 11, 2005,
    27, 2, 2006, 28, 2, 2006, 14, 4, 2006, 21, 4, 2006, 1, 5, 2006, 15, 6, 2006,
    7, 9, 2006, 12, 10, 2006, 2, 11, 2006, 15, 11, 2006, 25, 12, 2006,
];

fn ::main() {
    let d, ok = date::from_ymd(1, date::JANUARY, 1901);
    if !ok || d.serial != 367 { fail("serial 1901"); }
    if date::weekday(d) != date::TUESDAY { fail("tuesday"); }
    let back, bok = date::from_ymd(date::day_of_month(d), date::month(d), date::year(d));
    if !bok || back.serial != d.serial { fail("roundtrip"); }

    var serial = date::MIN_SERIAL;
    var prev_doy = 0;
    while serial <= date::MAX_SERIAL {
        let t, tok = date::from_serial(serial);
        if !tok { fail("serial"); }
        let y = date::year(t);
        let m = date::month(t);
        let day = date::day_of_month(t);
        let again, aok = date::from_ymd(day, m, y);
        if !aok || again.serial != serial { fail("consistency"); }
        let w = serial % 7;
        var want = w;
        if w == 0 { want = 7; }
        if date::weekday(t) != want { fail("weekday"); }
        if m < 1 || m > 12 || day < 1 { fail("ymd"); }
        let doy = date::day_of_year(t);
        if serial > date::MIN_SERIAL {
            if doy != 1 && doy != prev_doy + 1 { fail("doy"); }
            if doy == 1 && prev_doy != 365 && prev_doy != 366 { fail("year roll"); }
        }
        prev_doy = doy;
        serial += 1;
    }

    let iso, iok = date::parse_iso("2006-01-15");
    if !iok || date::day_of_month(iso) != 15 || date::month(iso) != 1 || date::year(iso) != 2006 {
        fail("iso");
    }
    if date::blank().serial != 0 { fail("null"); }
    let bad, badok = date::from_ymd(29, 2, 2001);
    if badok { fail("not leap"); }
    let leap, lok = date::from_ymd(29, 2, 2000);
    if !lok { fail("leap"); }
    let clamped, cok = date::plus_years(leap, 1);
    if !cok || date::day_of_month(clamped) != 28 { fail("feb 29 advance"); }

    let p = period::normalize(period::months(24));
    if p.n != 2 || p.unit != period::YEARS { fail("normalize"); }
    let f = period::frequency(period::months(3));
    if f != period::QUARTERLY { fail("frequency"); }
    let added, addok = period::add(period::years(1), period::months(6));
    if !addok || added.n != 18 { fail("add"); }

    let a, aok = date::from_ymd(1, date::NOVEMBER, 2003);
    let b, bok2 = date::from_ymd(1, date::MAY, 2004);
    if !aok || !bok2 { fail("dates"); }
    let yf, yok = daycount::year_fraction(daycount::actual_actual_isda(), a, b, date::blank(), date::blank());
    if !yok || !near(yf, 0.497724380567) { fail("isda"); }
    let y2, y2ok = daycount::year_fraction(daycount::actual_actual_isma(), a, b, a, b);
    if !y2ok || !near(y2, 0.5) { fail("isma"); }
    let y3, y3ok = daycount::year_fraction(daycount::actual_actual_afb(), a, b, date::blank(), date::blank());
    if !y3ok || !near(y3, 0.497267759563) { fail("afb"); }

    let s1, s1ok = date::from_ymd(20, date::AUGUST, 2006);
    let s2, s2ok = date::from_ymd(20, date::FEBRUARY, 2007);
    if !s1ok || !s2ok { fail("30 dates"); }
    if daycount::day_count(daycount::thirty360_bond(), s1, s2) != 180 { fail("bond basis"); }
    if daycount::day_count(daycount::thirty360_usa(), s1, s2) != 180 { fail("usa"); }
    let act, actok = daycount::year_fraction(daycount::actual360(), s1, s2, date::blank(), date::blank());
    if !actok { fail("act360"); }
    let want = date::days_between(s1, s2) / 360.0;
    if !near(act, want) { fail("act360 value"); }

    let t365a = ymd(17, 6, 2011);
    let t365b = ymd(30, 12, 2012);
    if daycount::day_count(daycount::make(daycount::T365), t365a, t365b) != 553 { fail("30/365"); }
    if daycount::day_count(daycount::make(daycount::T365), ymd(31, 3, 2025), ymd(30, 4, 2025)) != 30 { fail("30/365 m"); }
    if daycount::day_count(daycount::make(daycount::T365), ymd(30, 9, 2024), ymd(31, 3, 2025)) != 180 { fail("30/365 span"); }
    if daycount::day_count(daycount::make(daycount::T365), ymd(30, 3, 2025), ymd(31, 3, 2025)) != 0 { fail("30/365 zero"); }

    check_holidays(markets::TARGET, ymd(1, 1, 1999), ymd(31, 12, 2006), TARGET_HOL);
    check_holidays(markets::BRAZIL, ymd(1, 1, 2005), ymd(31, 12, 2006), BRAZIL_HOL);

    var hole: i32[1] = [0];
    let gap = calendar::business_days_between(markets::BRAZIL, ymd(1, 2, 2002), ymd(4, 2, 2002), true, false, hole[0..0], hole[0..0]);
    if gap != 1 { fail("brazil days"); }

    let advanced, aok2 = calendar::advance(markets::TARGET, ymd(15, 1, 2004), 1, period::YEARS, calendar::MODIFIED_FOLLOWING, false, hole[0..0], hole[0..0]);
    if !aok2 || advanced.serial != ymd(17, 1, 2005).serial { fail("target 1y"); }

    const BUS: i32[45] = [
        1, 2, 2002, 4, 2, 2002, 16, 5, 2003, 17, 12, 2003, 17, 12, 2004,
        19, 12, 2005, 2, 1, 2006, 13, 3, 2006, 15, 5, 2006, 17, 3, 2006,
        15, 5, 2006, 26, 7, 2006, 28, 6, 2007, 16, 9, 2009, 26, 7, 2016,
    ];
    const BUS_YF: f64[14] = [
        0.0039682539683, 1.2738095238095, 0.6031746031746, 0.9960317460317,
        1.0, 0.0396825396825, 0.1904761904762, 0.1666666666667,
        -0.1507936507937, 0.1507936507937, 0.2023809523810, 0.912698412698,
        2.214285714286, 6.84126984127,
    ];
    var bi: i64 = 0;
    while bi < 14 {
        let left = ymd(BUS[bi * 3], BUS[bi * 3 + 1], BUS[bi * 3 + 2]);
        let right = ymd(BUS[(bi + 1) * 3], BUS[(bi + 1) * 3 + 1], BUS[(bi + 1) * 3 + 2]);
        let yf252, yfok = daycount::year_fraction(daycount::business252(), left, right, date::blank(), date::blank());
        if !yfok || !near(yf252, BUS_YF[bi]) { fail("business/252"); }
        bi += 1;
    }

    write_stdout("quant ok\n");
}
