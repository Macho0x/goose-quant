// Market holiday rules. A market is an i32. A day is a business day when
// this returns true. Western Easter Monday comes from easter.goose.

import date;
import easter;
import markets_west;
import markets_north;
import markets_americas;
import markets_seasia;
import markets_east;
import markets_asia;
import markets_other;

namespace markets;

const NULL_CAL: i32 = 0;
const WEEKENDS: i32 = 1;
const TARGET: i32 = 2;
const US_SETTLEMENT: i32 = 3;
const UK_SETTLEMENT: i32 = 4;
const BRAZIL: i32 = 5;

fn is_business_day(kind: i32, d: date::Date) -> bool {
    if kind == NULL_CAL { return true; }
    if kind == WEEKENDS { return !western_weekend(date::weekday(d)); }
    if kind == TARGET { return target(d); }
    if kind == US_SETTLEMENT { return us_settlement(d); }
    if kind == UK_SETTLEMENT { return uk_settlement(d); }
    if kind == BRAZIL { return brazil(d); }
    if markets_west::known(kind) { return markets_west::is_business_day(kind, d); }
    if markets_north::known(kind) { return markets_north::is_business_day(kind, d); }
    if markets_americas::known(kind) { return markets_americas::is_business_day(kind, d); }
    if markets_seasia::known(kind) { return markets_seasia::is_business_day(kind, d); }
    if markets_east::known(kind) { return markets_east::is_business_day(kind, d); }
    if markets_asia::known(kind) { return markets_asia::is_business_day(kind, d); }
    if markets_other::known(kind) { return markets_other::is_business_day(kind, d); }
    return true;
}

fn western_weekend(w: i32) -> bool {
    return w == date::SATURDAY || w == date::SUNDAY;
}

fn target(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if western_weekend(w) { return false; }
    if day == 1 && m == 1 { return false; }
    if doy == em - 3 && y >= 2000 { return false; }
    if doy == em && y >= 2000 { return false; }
    if day == 1 && m == 5 && y >= 2000 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 && y >= 2000 { return false; }
    if day == 31 && m == 12 && (y == 1998 || y == 1999 || y == 2001) { return false; }
    return true;
}

fn us_settlement(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    if western_weekend(w) { return false; }
    if (day == 1 || (day == 2 && w == date::MONDAY)) && m == 1 { return false; }
    if (day >= 15 && day <= 21) && w == date::MONDAY && m == 1 && y >= 1983 { return false; }
    if (day == 20 || (day == 21 && w == date::MONDAY) || (day == 19 && w == date::FRIDAY)) && m == 2 && y >= 1971 { return false; }
    if day == 16 && m == 1 && y == 2025 { return false; }
    if day == 31 && m == 3 && y == 2026 { return false; }
    let memorial = day >= 25 && w == date::MONDAY && m == 5 && y >= 1971;
    let memorial_old = day == 30 && w == date::FRIDAY && m == 5 && y < 1971;
    if memorial || memorial_old { return false; }
    if day == 19 && m == 6 && y >= 2022 { return false; }
    if day == 20 && w == date::MONDAY && m == 6 && y >= 2022 { return false; }
    if day == 18 && w == date::FRIDAY && m == 6 && y >= 2022 { return false; }
    if (day == 4 || (day == 5 && w == date::MONDAY) || (day == 3 && w == date::FRIDAY)) && m == 7 && y >= 1954 { return false; }
    if day >= 1 && day <= 7 && w == date::MONDAY && m == 9 { return false; }
    if day >= 8 && day <= 14 && w == date::MONDAY && m == 10 { return false; }
    if (day == 11 || (day == 12 && w == date::MONDAY) || (day == 10 && w == date::FRIDAY)) && m == 11 { return false; }
    if day >= 22 && day <= 28 && w == date::THURSDAY && m == 11 { return false; }
    if (day == 25 || (day == 26 && w == date::MONDAY) || (day == 24 && w == date::FRIDAY)) && m == 12 { return false; }
    return true;
}

fn uk_bank(day: i32, w: i32, m: i32, y: i32) -> bool {
    if day <= 7 && w == date::MONDAY && m == 5 && y != 1995 && y != 2020 { return true; }
    if day == 8 && m == 5 && (y == 1995 || y == 2020) { return true; }
    if day >= 25 && w == date::MONDAY && m == 5 && y != 2002 && y != 2012 && y != 2022 { return true; }
    if (day == 3 || day == 4) && m == 6 && y == 2002 { return true; }
    if (day == 4 || day == 5) && m == 6 && y == 2012 { return true; }
    if (day == 2 || day == 3) && m == 6 && y == 2022 { return true; }
    if day >= 25 && w == date::MONDAY && m == 8 { return true; }
    if day == 29 && m == 4 && y == 2011 { return true; }
    if day == 19 && m == 9 && y == 2022 { return true; }
    if day == 8 && m == 5 && y == 2023 { return true; }
    return false;
}

fn uk_settlement(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if western_weekend(w) { return false; }
    if (day == 1 || ((day == 2 || day == 3) && w == date::MONDAY)) && m == 1 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if uk_bank(day, w, m, y) { return false; }
    if (day == 25 || (day == 27 && (w == date::MONDAY || w == date::TUESDAY))) && m == 12 { return false; }
    if (day == 26 || (day == 28 && (w == date::MONDAY || w == date::TUESDAY))) && m == 12 { return false; }
    if day == 31 && m == 12 && y == 1999 { return false; }
    return true;
}

fn brazil(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if western_weekend(w) { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 21 && m == 4 { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 7 && m == 9 { return false; }
    if day == 12 && m == 10 { return false; }
    if day == 2 && m == 11 { return false; }
    if day == 15 && m == 11 { return false; }
    if day == 20 && m == 11 && y >= 2024 { return false; }
    if day == 25 && m == 12 { return false; }
    if doy == em - 3 { return false; }
    if doy == em - 49 || doy == em - 48 { return false; }
    if doy == em + 59 { return false; }
    return true;
}
