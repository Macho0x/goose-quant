// Western European market holidays. A market is an i32. A day is a
// business day when is_business_day returns true. Easter Monday is
// easter::western (day of year). Weekend is Saturday and Sunday.
//
// GERMANY_SETTLEMENT  10  Germany::Settlement
// GERMANY_FRANKFURT   11  Germany::FrankfurtStockExchange
// GERMANY_XETRA       12  Germany::Xetra
// GERMANY_EUREX       13  Germany::Eurex
// GERMANY_EUWAX       14  Germany::Euwax
// AUSTRIA_SETTLEMENT  15  Austria::Settlement
// AUSTRIA_EXCHANGE    16  Austria::Exchange
// SWITZERLAND         17  Switzerland
// FRANCE_SETTLEMENT   18  France::Settlement
// FRANCE_EXCHANGE     19  France::Exchange
// ITALY_SETTLEMENT    20  Italy::Settlement
// ITALY_EXCHANGE      21  Italy::Exchange

import date;
import easter;

namespace markets_west;

const GERMANY_SETTLEMENT: i32 = 10;
const GERMANY_FRANKFURT: i32 = 11;
const GERMANY_XETRA: i32 = 12;
const GERMANY_EUREX: i32 = 13;
const GERMANY_EUWAX: i32 = 14;
const AUSTRIA_SETTLEMENT: i32 = 15;
const AUSTRIA_EXCHANGE: i32 = 16;
const SWITZERLAND: i32 = 17;
const FRANCE_SETTLEMENT: i32 = 18;
const FRANCE_EXCHANGE: i32 = 19;
const ITALY_SETTLEMENT: i32 = 20;
const ITALY_EXCHANGE: i32 = 21;

fn known(kind: i32) -> bool {
    return kind >= GERMANY_SETTLEMENT && kind <= ITALY_EXCHANGE;
}

fn is_business_day(kind: i32, d: date::Date) -> bool {
    if kind == GERMANY_SETTLEMENT { return germany_settlement(d); }
    if kind == GERMANY_FRANKFURT || kind == GERMANY_XETRA { return germany_frankfurt(d); }
    if kind == GERMANY_EUREX { return germany_eurex(d); }
    if kind == GERMANY_EUWAX { return germany_euwax(d); }
    if kind == AUSTRIA_SETTLEMENT { return austria_settlement(d); }
    if kind == AUSTRIA_EXCHANGE { return austria_exchange(d); }
    if kind == SWITZERLAND { return switzerland(d); }
    if kind == FRANCE_SETTLEMENT { return france_settlement(d); }
    if kind == FRANCE_EXCHANGE { return france_exchange(d); }
    if kind == ITALY_SETTLEMENT { return italy_settlement(d); }
    if kind == ITALY_EXCHANGE { return italy_exchange(d); }
    return true;
}

fn germany_settlement(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if w == date::SATURDAY || w == date::SUNDAY { return false; }
    if day == 1 && m == 1 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if doy == em + 38 { return false; }
    if doy == em + 49 { return false; }
    if doy == em + 59 { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 3 && m == 10 { return false; }
    if day == 24 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    return true;
}

fn germany_frankfurt(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if w == date::SATURDAY || w == date::SUNDAY { return false; }
    if day == 1 && m == 1 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 24 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    return true;
}

fn germany_eurex(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if w == date::SATURDAY || w == date::SUNDAY { return false; }
    if day == 1 && m == 1 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 24 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    if day == 31 && m == 12 { return false; }
    return true;
}

fn germany_euwax(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if w == date::SATURDAY || w == date::SUNDAY { return false; }
    if day == 1 && m == 1 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if doy == em + 49 { return false; }
    if day == 24 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    return true;
}

fn austria_settlement(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if w == date::SATURDAY || w == date::SUNDAY { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 6 && m == 1 { return false; }
    if doy == em { return false; }
    if doy == em + 38 { return false; }
    if doy == em + 49 { return false; }
    if doy == em + 59 { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 15 && m == 8 { return false; }
    if day == 26 && m == 10 && y >= 1967 { return false; }
    if day == 12 && m == 11 && y >= 1919 && y <= 1934 { return false; }
    if day == 1 && m == 11 { return false; }
    if day == 8 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    return true;
}

fn austria_exchange(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if w == date::SATURDAY || w == date::SUNDAY { return false; }
    if day == 1 && m == 1 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if doy == em + 49 { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 26 && m == 10 && y >= 1967 { return false; }
    if day == 12 && m == 11 && y >= 1919 && y <= 1934 { return false; }
    if day == 24 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    if day == 31 && m == 12 { return false; }
    return true;
}

fn switzerland(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if w == date::SATURDAY || w == date::SUNDAY { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 2 && m == 1 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if doy == em + 38 { return false; }
    if doy == em + 49 { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 1 && m == 8 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    return true;
}

fn france_settlement(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if w == date::SATURDAY || w == date::SUNDAY { return false; }
    if day == 1 && m == 1 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 8 && m == 5 { return false; }
    if doy == em + 38 { return false; }
    if doy == em + 49 { return false; }
    if day == 14 && m == 7 { return false; }
    if day == 15 && m == 8 { return false; }
    if day == 1 && m == 11 { return false; }
    if day == 11 && m == 11 { return false; }
    if day == 25 && m == 12 { return false; }
    return true;
}

fn france_exchange(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if w == date::SATURDAY || w == date::SUNDAY { return false; }
    if day == 1 && m == 1 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 24 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    if day == 31 && m == 12 { return false; }
    return true;
}

fn italy_settlement(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if w == date::SATURDAY || w == date::SUNDAY { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 6 && m == 1 { return false; }
    if doy == em { return false; }
    if day == 25 && m == 4 { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 2 && m == 6 && y >= 2000 { return false; }
    if day == 15 && m == 8 { return false; }
    if day == 4 && m == 10 && y >= 2026 { return false; }
    if day == 1 && m == 11 { return false; }
    if day == 8 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    if day == 31 && m == 12 && y == 1999 { return false; }
    return true;
}

fn italy_exchange(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if w == date::SATURDAY || w == date::SUNDAY { return false; }
    if day == 1 && m == 1 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 15 && m == 8 { return false; }
    if day == 24 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    if day == 31 && m == 12 { return false; }
    return true;
}
