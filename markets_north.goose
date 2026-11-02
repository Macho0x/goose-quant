// Northern market holiday rules. A market is an i32.
// DENMARK 40: Denmark::Impl
// FINLAND 41: Finland::Impl
// ICELAND 42: Iceland::IcexImpl, market ICEX
// NORWAY 43: Norway::Impl
// SWEDEN 44: Sweden::Impl
// UK_EXCHANGE 45: UnitedKingdom::ExchangeImpl, market Exchange
// UK_METALS 46: UnitedKingdom::MetalsImpl, market Metals
// Western Easter Monday is easter::western(year), a day-of-year.
// Weekend is Saturday and Sunday.

import date;
import easter;

namespace markets_north;

const DENMARK: i32 = 40;
const FINLAND: i32 = 41;
const ICELAND: i32 = 42;
const NORWAY: i32 = 43;
const SWEDEN: i32 = 44;
const UK_EXCHANGE: i32 = 45;
const UK_METALS: i32 = 46;

// Single-date holidays from UnitedKingdom::isBankHoliday and the
// 31 December 1999 clause. Exchange and Metals share that list.
const UK_ONE_OFF: i32[12] = [
    19950508, 19991231, 20020603, 20020604, 20110429, 20120604,
    20120605, 20200508, 20220602, 20220603, 20220919, 20230508,
];

fn known(kind: i32) -> bool {
    if kind == DENMARK || kind == FINLAND || kind == ICELAND { return true; }
    if kind == NORWAY || kind == SWEDEN { return true; }
    if kind == UK_EXCHANGE || kind == UK_METALS { return true; }
    return false;
}

fn is_business_day(kind: i32, d: date::Date) -> bool {
    if kind == DENMARK { return denmark(d); }
    if kind == FINLAND { return finland(d); }
    if kind == ICELAND { return iceland(d); }
    if kind == NORWAY { return norway(d); }
    if kind == SWEDEN { return sweden(d); }
    if kind == UK_EXCHANGE || kind == UK_METALS { return uk_exchange(d); }
    return true;
}

fn weekend(w: i32) -> bool {
    return w == date::SATURDAY || w == date::SUNDAY;
}

fn on_list(days: i32[:], y: i32, m: i32, day: i32) -> bool {
    let key: i32 = y * 10000 + m * 100 + day;
    var i: i64 = 0;
    while i < days.len {
        if days[i] == key { return true; }
        i += 1;
    }
    return false;
}

fn denmark(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if doy == em - 4 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if doy == em + 25 && y <= 2023 { return false; }
    if doy == em + 38 { return false; }
    if doy == em + 39 && y >= 2009 { return false; }
    if doy == em + 49 { return false; }
    if day == 1 && m == date::JANUARY { return false; }
    if day == 5 && m == date::JUNE { return false; }
    if day == 24 && m == date::DECEMBER { return false; }
    if day == 25 && m == date::DECEMBER { return false; }
    if day == 26 && m == date::DECEMBER { return false; }
    if day == 31 && m == date::DECEMBER { return false; }
    return true;
}

fn finland(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if day == 1 && m == date::JANUARY { return false; }
    if day == 6 && m == date::JANUARY { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if doy == em + 38 { return false; }
    if day == 1 && m == date::MAY { return false; }
    if w == date::FRIDAY && day >= 19 && day <= 25 && m == date::JUNE { return false; }
    if day == 6 && m == date::DECEMBER { return false; }
    if day == 24 && m == date::DECEMBER { return false; }
    if day == 25 && m == date::DECEMBER { return false; }
    if day == 26 && m == date::DECEMBER { return false; }
    return true;
}

fn iceland(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if day == 1 && m == date::JANUARY { return false; }
    if doy == em - 4 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if day >= 19 && day <= 25 && w == date::THURSDAY && m == date::APRIL { return false; }
    if doy == em + 38 { return false; }
    if doy == em + 49 { return false; }
    if day == 1 && m == date::MAY { return false; }
    if day == 17 && m == date::JUNE { return false; }
    if day <= 7 && w == date::MONDAY && m == date::AUGUST { return false; }
    if day == 25 && m == date::DECEMBER { return false; }
    if day == 26 && m == date::DECEMBER { return false; }
    return true;
}

fn norway(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if doy == em - 4 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if doy == em + 38 { return false; }
    if doy == em + 49 { return false; }
    if day == 1 && m == date::JANUARY { return false; }
    if day == 1 && m == date::MAY { return false; }
    if day == 17 && m == date::MAY { return false; }
    if day == 24 && m == date::DECEMBER && y >= 2002 { return false; }
    if day == 25 && m == date::DECEMBER { return false; }
    if day == 26 && m == date::DECEMBER { return false; }
    return true;
}

fn sweden(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if doy == em + 38 { return false; }
    if doy == em + 49 && y < 2005 { return false; }
    if day == 1 && m == date::JANUARY { return false; }
    if day == 6 && m == date::JANUARY { return false; }
    if day == 1 && m == date::MAY { return false; }
    if day == 6 && m == date::JUNE && y >= 2005 { return false; }
    if w == date::FRIDAY && day >= 19 && day <= 25 && m == date::JUNE { return false; }
    if day == 24 && m == date::DECEMBER { return false; }
    if day == 25 && m == date::DECEMBER { return false; }
    if day == 26 && m == date::DECEMBER { return false; }
    if day == 31 && m == date::DECEMBER { return false; }
    return true;
}

fn uk_bank(day: i32, w: i32, m: i32, y: i32) -> bool {
    if day <= 7 && w == date::MONDAY && m == date::MAY && y != 1995 && y != 2020 { return true; }
    if day >= 25 && w == date::MONDAY && m == date::MAY && y != 2002 && y != 2012 && y != 2022 { return true; }
    if day >= 25 && w == date::MONDAY && m == date::AUGUST { return true; }
    return false;
}

fn uk_exchange(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if (day == 1 || ((day == 2 || day == 3) && w == date::MONDAY)) && m == date::JANUARY { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if uk_bank(day, w, m, y) { return false; }
    if (day == 25 || (day == 27 && (w == date::MONDAY || w == date::TUESDAY))) && m == date::DECEMBER { return false; }
    if (day == 26 || (day == 28 && (w == date::MONDAY || w == date::TUESDAY))) && m == date::DECEMBER { return false; }
    if on_list(UK_ONE_OFF, y, m, day) { return false; }
    return true;
}
