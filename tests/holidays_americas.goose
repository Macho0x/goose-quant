import os;
import quant from "..";
import quant.date;
import quant.markets_americas;

fn fail(msg: u8[:]) {
    write_stdout(msg);
    write_stdout("\n");
    exit(1);
}

fn fail_ymd(msg: u8[:], day: i32, m: i32, y: i32) {
    var line: u8[>..] = [];
    format(line, msg);
    format(line, " ");
    format_int(line, day, 10, 2, '0');
    format(line, "-");
    format_int(line, m, 10, 2, '0');
    format(line, "-");
    format_int(line, y, 10, 4, '0');
    format(line, "\n");
    write_stdout(line);
    exit(1);
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

fn check_holidays(kind: i32, from: date::Date, to: date::Date, hol: i32[:], extra: u8[:], missed: u8[:]) {
    var serial = from.serial;
    while serial <= to.serial {
        let t, ok = date::from_serial(serial);
        if !ok { fail("holiday serial"); }
        let w = date::weekday(t);
        let weekend = w == date::SATURDAY || w == date::SUNDAY;
        let biz = markets_americas::is_business_day(kind, t);
        let day = date::day_of_month(t);
        let m = date::month(t);
        let y = date::year(t);
        let listed = in_hol(hol, day, m, y);
        if !weekend && !biz && !listed { fail_ymd(extra, day, m, y); }
        if listed && biz { fail_ymd(missed, day, m, y); }
        serial += 1;
    }
}

fn must_holiday(kind: i32, day: i32, m: i32, y: i32, msg: u8[:]) {
    if markets_americas::is_business_day(kind, ymd(day, m, y)) { fail_ymd(msg, day, m, y); }
}

fn must_business(kind: i32, day: i32, m: i32, y: i32, msg: u8[:]) {
    if !markets_americas::is_business_day(kind, ymd(day, m, y)) { fail_ymd(msg, day, m, y); }
}

fn each_holiday(kind: i32, dates: i32[:], msg: u8[:]) {
    var i: i64 = 0;
    while i < dates.len {
        let n = dates[i];
        let y = n / 10000;
        let m = (n / 100) % 100;
        let day = n % 100;
        must_holiday(kind, day, m, y, msg);
        i += 1;
    }
}

// UnitedStates::Settlement lists for 2004-2005 and 1961. LiborImpact
// matches Settlement before the 2015 Independence Day exception.
const LIBOR_2004: i32[60] = [
    1, 1, 2004, 19, 1, 2004, 16, 2, 2004, 31, 5, 2004, 5, 7, 2004,
    6, 9, 2004, 11, 10, 2004, 11, 11, 2004, 25, 11, 2004, 24, 12, 2004,
    31, 12, 2004, 17, 1, 2005, 21, 2, 2005, 30, 5, 2005, 4, 7, 2005,
    5, 9, 2005, 10, 10, 2005, 11, 11, 2005, 24, 11, 2005, 26, 12, 2005,
];

const LIBOR_1961: i32[24] = [
    2, 1, 1961, 22, 2, 1961, 30, 5, 1961, 4, 7, 1961,
    4, 9, 1961, 10, 11, 1961, 23, 11, 1961, 25, 12, 1961,
];

const BOND_2004: i32[36] = [
    1, 1, 2004, 19, 1, 2004, 16, 2, 2004, 9, 4, 2004, 31, 5, 2004, 11, 6, 2004,
    5, 7, 2004, 6, 9, 2004, 11, 10, 2004, 11, 11, 2004, 25, 11, 2004, 24, 12, 2004,
];

const NYSE_2004: i32[81] = [
    1, 1, 2004, 19, 1, 2004, 16, 2, 2004, 9, 4, 2004, 31, 5, 2004, 11, 6, 2004,
    5, 7, 2004, 6, 9, 2004, 25, 11, 2004, 24, 12, 2004,
    17, 1, 2005, 21, 2, 2005, 25, 3, 2005, 30, 5, 2005, 4, 7, 2005, 5, 9, 2005,
    24, 11, 2005, 26, 12, 2005,
    2, 1, 2006, 16, 1, 2006, 20, 2, 2006, 14, 4, 2006, 29, 5, 2006, 4, 7, 2006,
    4, 9, 2006, 23, 11, 2006, 25, 12, 2006,
];

const NYSE_HIST: i32[39] = [
    20121030, 20121029, 20040611, 20010914, 20010913, 20010912, 20010911,
    19940427, 19850927, 19770714, 19730125, 19721228, 19690721, 19690331,
    19690210, 19680705, 19680409, 19651224, 19631125, 19610529, 19581226,
    19561224, 19541224, 19680612, 19680619, 19680626, 19680703, 19680710,
    19680717, 19681120, 19681127, 19681204, 19681211, 19681218, 19801104,
    19761102, 19721107, 19681105, 19641103,
];

const SOFR_GOOD_FRIDAY: i32[15] = [
    20170414, 20180330, 20190419, 20200410, 20210402, 20220415, 20230407,
    20240329, 20250418, 20260403, 20270326, 20280414, 20290330, 20300419,
    20310411,
];

const FED_JUNETEENTH: i32[10] = [
    20220620, 20230619, 20240619, 20250619, 20270619, 20280619, 20290619,
    20300619, 20310619, 20330620,
];

fn nz_shared(kind: i32) {
    must_holiday(kind, 1, 1, 2025, "nz new year");
    must_holiday(kind, 2, 1, 2025, "nz new year");
    must_business(kind, 3, 1, 2025, "nz new year");
    must_holiday(kind, 1, 1, 2023, "nz new year");
    must_holiday(kind, 2, 1, 2023, "nz new year");
    must_holiday(kind, 3, 1, 2023, "nz new year");
    must_business(kind, 4, 1, 2023, "nz new year");
    must_holiday(kind, 1, 1, 2022, "nz new year");
    must_holiday(kind, 2, 1, 2022, "nz new year");
    must_holiday(kind, 3, 1, 2022, "nz new year");
    must_holiday(kind, 4, 1, 2022, "nz new year");
    must_business(kind, 5, 1, 2022, "nz new year");
    must_holiday(kind, 1, 1, 2027, "nz new year");
    must_holiday(kind, 2, 1, 2027, "nz new year");
    must_holiday(kind, 3, 1, 2027, "nz new year");
    must_holiday(kind, 4, 1, 2027, "nz new year");
    must_business(kind, 5, 1, 2027, "nz new year");
    must_holiday(kind, 25, 12, 2024, "nz christmas");
    must_holiday(kind, 26, 12, 2024, "nz christmas");
    must_business(kind, 27, 12, 2024, "nz christmas");
    must_holiday(kind, 25, 12, 2022, "nz christmas");
    must_holiday(kind, 26, 12, 2022, "nz christmas");
    must_holiday(kind, 27, 12, 2022, "nz christmas");
    must_business(kind, 28, 12, 2022, "nz christmas");
    must_holiday(kind, 25, 12, 2021, "nz christmas");
    must_holiday(kind, 26, 12, 2021, "nz christmas");
    must_holiday(kind, 27, 12, 2021, "nz christmas");
    must_holiday(kind, 28, 12, 2021, "nz christmas");
    must_business(kind, 29, 12, 2021, "nz christmas");
    must_holiday(kind, 25, 12, 2026, "nz christmas");
    must_holiday(kind, 26, 12, 2026, "nz christmas");
    must_holiday(kind, 27, 12, 2026, "nz christmas");
    must_holiday(kind, 28, 12, 2026, "nz christmas");
    must_business(kind, 29, 12, 2026, "nz christmas");
    must_holiday(kind, 8, 2, 2021, "nz waitangi");
    must_holiday(kind, 7, 2, 2022, "nz waitangi");
    must_business(kind, 8, 2, 2010, "nz waitangi");
    must_business(kind, 7, 2, 2011, "nz waitangi");
    must_holiday(kind, 27, 4, 2020, "nz anzac");
    must_holiday(kind, 26, 4, 2021, "nz anzac");
    must_business(kind, 27, 4, 2009, "nz anzac");
    must_business(kind, 26, 4, 2010, "nz anzac");
}

fn ::main() {
    if markets_americas::known(109) || markets_americas::known(126) { fail("unknown kind"); }
    if !markets_americas::known(markets_americas::ARGENTINA_MERVAL) { fail("known"); }
    if !markets_americas::known(markets_americas::BRAZIL_EXCHANGE) { fail("known"); }
    let sat = ymd(6, 1, 2024);
    if date::weekday(sat) != date::SATURDAY { fail("sat"); }
    if !markets_americas::is_business_day(109, sat) { fail("unknown day"); }
    if !markets_americas::is_business_day(109, ymd(1, 1, 2024)) { fail("unknown day"); }

    let libor = markets_americas::US_LIBOR_IMPACT;
    check_holidays(libor, ymd(1, 1, 2004), ymd(31, 12, 2005), LIBOR_2004, "extra libor", "missed libor");
    check_holidays(libor, ymd(1, 1, 1961), ymd(31, 12, 1961), LIBOR_1961, "extra libor 1961", "missed libor 1961");
    must_business(libor, 3, 7, 2020, "libor independence");
    must_holiday(markets_americas::US_NYSE, 3, 7, 2020, "nyse independence");
    must_holiday(markets_americas::US_GOVERNMENT_BOND, 3, 7, 2020, "bond independence");
    must_business(markets_americas::US_NERC, 3, 7, 2020, "nerc independence");
    must_business(markets_americas::US_FEDERAL_RESERVE, 3, 7, 2020, "fed independence");

    let bond = markets_americas::US_GOVERNMENT_BOND;
    check_holidays(bond, ymd(1, 1, 2004), ymd(31, 12, 2004), BOND_2004, "extra bond", "missed bond");
    must_business(bond, 2, 4, 2021, "bond good friday");
    must_business(bond, 7, 4, 2023, "bond good friday");
    must_holiday(bond, 18, 6, 2027, "bond juneteenth");
    must_business(bond, 10, 11, 2023, "bond veterans");
    must_holiday(bond, 28, 10, 1974, "bond veterans october");
    must_business(bond, 11, 11, 1974, "bond veterans november");
    must_holiday(bond, 24, 12, 2021, "bond christmas");

    let nyse = markets_americas::US_NYSE;
    check_holidays(nyse, ymd(1, 1, 2004), ymd(31, 12, 2006), NYSE_2004, "extra nyse", "missed nyse");
    each_holiday(nyse, NYSE_HIST, "nyse hist");
    must_holiday(nyse, 1, 5, 2004, "nyse saturday");
    must_business(nyse, 26, 4, 2004, "nyse business");
    must_holiday(nyse, 2, 4, 2021, "nyse good friday");
    must_holiday(nyse, 7, 4, 2023, "nyse good friday");
    must_holiday(nyse, 19, 1, 1998, "nyse mlk");
    must_business(nyse, 20, 1, 1997, "nyse mlk");
    must_holiday(nyse, 18, 6, 2027, "nyse juneteenth");
    must_holiday(nyse, 20, 6, 2022, "nyse juneteenth");
    must_holiday(nyse, 24, 12, 2021, "nyse christmas");
    must_business(libor, 2, 4, 2021, "libor good friday");
    must_holiday(libor, 17, 1, 1983, "libor mlk");
    must_business(libor, 18, 1, 1982, "libor mlk");
    must_business(nyse, 17, 1, 1983, "nyse mlk early");
    must_holiday(libor, 10, 11, 2023, "libor veterans");
    must_holiday(libor, 28, 10, 1974, "libor veterans october");
    must_business(libor, 11, 11, 1974, "libor veterans november");
    must_holiday(libor, 24, 12, 2021, "libor christmas");

    let sofr = markets_americas::US_SOFR;
    each_holiday(sofr, SOFR_GOOD_FRIDAY, "sofr");

    let fed = markets_americas::US_FEDERAL_RESERVE;
    each_holiday(fed, FED_JUNETEENTH, "fed juneteenth");
    must_business(fed, 18, 6, 2027, "fed juneteenth");
    must_business(fed, 10, 11, 2023, "fed veterans");
    must_holiday(fed, 28, 10, 1974, "fed veterans october");
    must_business(fed, 11, 11, 1974, "fed veterans november");
    must_business(fed, 24, 12, 2021, "fed christmas");

    let nerc = markets_americas::US_NERC;
    must_business(nerc, 19, 6, 2024, "nerc juneteenth");
    must_holiday(fed, 19, 6, 2024, "fed juneteenth day");
    must_business(nerc, 18, 6, 2027, "nerc juneteenth friday");
    must_business(nerc, 24, 12, 2021, "nerc christmas");

    must_holiday(markets_americas::ARGENTINA_MERVAL, 1, 1, 2024, "argentina");
    must_holiday(markets_americas::ARGENTINA_MERVAL, 28, 3, 2024, "argentina");
    must_holiday(markets_americas::ARGENTINA_MERVAL, 29, 3, 2024, "argentina");
    must_holiday(markets_americas::ARGENTINA_MERVAL, 17, 6, 2024, "argentina");
    must_holiday(markets_americas::ARGENTINA_MERVAL, 19, 8, 2024, "argentina");
    must_holiday(markets_americas::ARGENTINA_MERVAL, 24, 12, 2024, "argentina");
    must_business(markets_americas::ARGENTINA_MERVAL, 2, 1, 2024, "argentina");

    let au = markets_americas::AUSTRALIA_SETTLEMENT;
    let asx = markets_americas::AUSTRALIA_ASX;
    must_holiday(au, 1, 1, 2024, "australia");
    must_holiday(au, 26, 1, 2024, "australia");
    must_holiday(au, 25, 4, 2024, "australia");
    must_holiday(asx, 29, 3, 2024, "australia asx");
    must_holiday(asx, 10, 6, 2024, "australia asx");
    must_business(asx, 2, 1, 2024, "australia asx");
    must_holiday(au, 5, 8, 2024, "australia bank");
    must_business(asx, 5, 8, 2024, "australia asx bank");
    must_holiday(au, 7, 10, 2024, "australia labour");
    must_business(asx, 7, 10, 2024, "australia asx labour");

    let ca = markets_americas::CANADA_SETTLEMENT;
    let tsx = markets_americas::CANADA_TSX;
    must_holiday(ca, 1, 1, 2024, "canada");
    must_holiday(ca, 19, 2, 2024, "canada");
    must_holiday(ca, 1, 7, 2024, "canada");
    must_holiday(tsx, 29, 3, 2024, "canada tsx");
    must_business(tsx, 11, 11, 2024, "canada tsx");
    must_business(tsx, 2, 1, 2024, "canada tsx");
    must_holiday(ca, 11, 11, 2024, "canada remembrance");
    must_holiday(ca, 30, 9, 2024, "canada reconciliation");
    must_business(tsx, 30, 9, 2024, "canada tsx reconciliation");

    let chile = markets_americas::CHILE_SSE;
    must_holiday(chile, 1, 1, 2024, "chile");
    must_holiday(chile, 29, 3, 2024, "chile");
    must_holiday(chile, 21, 5, 2024, "chile");
    must_holiday(chile, 18, 9, 2024, "chile");
    must_holiday(chile, 19, 9, 2024, "chile");
    must_business(chile, 2, 1, 2024, "chile");

    let mx = markets_americas::MEXICO_BMV;
    must_holiday(mx, 1, 10, 2024, "mexico");
    must_holiday(mx, 1, 10, 2030, "mexico");
    must_holiday(mx, 1, 10, 2036, "mexico");
    must_holiday(mx, 1, 10, 2042, "mexico");
    must_holiday(mx, 1, 10, 2048, "mexico");
    must_business(mx, 1, 10, 2018, "mexico");
    must_business(mx, 1, 10, 2025, "mexico");
    must_business(mx, 1, 10, 2026, "mexico");
    must_business(mx, 1, 10, 2027, "mexico");
    must_business(mx, 1, 10, 2029, "mexico");
    must_business(mx, 1, 10, 2031, "mexico");
    must_business(mx, 1, 10, 2032, "mexico");
    must_business(mx, 1, 10, 2035, "mexico");

    let wel = markets_americas::NZ_WELLINGTON;
    let auck = markets_americas::NZ_AUCKLAND;
    nz_shared(wel);
    nz_shared(auck);
    must_business(auck, 22, 1, 2024, "nz anniversary");
    must_holiday(wel, 22, 1, 2024, "nz anniversary");
    must_holiday(auck, 29, 1, 2024, "nz anniversary");
    must_business(wel, 29, 1, 2024, "nz anniversary");
    must_business(auck, 19, 1, 2026, "nz anniversary");
    must_holiday(wel, 19, 1, 2026, "nz anniversary");
    must_holiday(auck, 26, 1, 2026, "nz anniversary");
    must_business(wel, 26, 1, 2026, "nz anniversary");
    must_business(auck, 25, 1, 2027, "nz anniversary");
    must_holiday(wel, 25, 1, 2027, "nz anniversary");
    must_holiday(auck, 1, 2, 2027, "nz anniversary");
    must_business(wel, 1, 2, 2027, "nz anniversary");

    let bx = markets_americas::BRAZIL_EXCHANGE;
    must_holiday(bx, 24, 12, 2024, "brazil exchange");
    must_holiday(bx, 25, 1, 2021, "brazil city");
    must_business(bx, 25, 1, 2022, "brazil city");
    must_holiday(bx, 9, 7, 2021, "brazil revolution");
    must_business(bx, 9, 7, 2024, "brazil revolution");
    must_holiday(bx, 20, 11, 2007, "brazil black");
    must_business(bx, 20, 11, 2023, "brazil black");
    must_holiday(bx, 20, 11, 2024, "brazil black");
    must_holiday(bx, 31, 12, 2024, "brazil year end");

    write_stdout("americas ok\n");
}
