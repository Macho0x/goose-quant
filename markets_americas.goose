// Americas holiday rules. A market is an i32. A day is a business day
// when is_business_day returns true. Western Easter Monday is
// easter::western(year), a day-of-year. Weekend is Saturday and Sunday.
// UnitedStates::Settlement and Brazil::Settlement stay in markets.goose.
//
// 110 ARGENTINA_MERVAL      Argentina::Merval = 0
// 111 AUSTRALIA_SETTLEMENT  Australia::Settlement = 0
// 112 AUSTRALIA_ASX         Australia::ASX = 1
// 113 CANADA_SETTLEMENT     Canada::Settlement = 0
// 114 CANADA_TSX            Canada::TSX = 1
// 115 CHILE_SSE             Chile::SSE = 0
// 116 MEXICO_BMV            Mexico::BMV = 0
// 117 NZ_WELLINGTON         NewZealand::Wellington = 0
// 118 NZ_AUCKLAND           NewZealand::Auckland = 1
// 119 US_NYSE               UnitedStates::NYSE = 1
// 120 US_GOVERNMENT_BOND    UnitedStates::GovernmentBond = 2
// 121 US_NERC               UnitedStates::NERC = 3
// 122 US_LIBOR_IMPACT       UnitedStates::LiborImpact = 4
// 123 US_FEDERAL_RESERVE    UnitedStates::FederalReserve = 5
// 124 US_SOFR               UnitedStates::SOFR = 6
// 125 BRAZIL_EXCHANGE       Brazil::Exchange = 1

import date;
import easter;

namespace markets_americas;

const ARGENTINA_MERVAL: i32 = 110;
const AUSTRALIA_SETTLEMENT: i32 = 111;
const AUSTRALIA_ASX: i32 = 112;
const CANADA_SETTLEMENT: i32 = 113;
const CANADA_TSX: i32 = 114;
const CHILE_SSE: i32 = 115;
const MEXICO_BMV: i32 = 116;
const NZ_WELLINGTON: i32 = 117;
const NZ_AUCKLAND: i32 = 118;
const US_NYSE: i32 = 119;
const US_GOVERNMENT_BOND: i32 = 120;
const US_NERC: i32 = 121;
const US_LIBOR_IMPACT: i32 = 122;
const US_FEDERAL_RESERVE: i32 = 123;
const US_SOFR: i32 = 124;
const BRAZIL_EXCHANGE: i32 = 125;

// Chile::isAboriginalPeopleDay, June day-of-month for 2021-2199.
const ABORIGINAL: i32[179] = [
    21, 21, 21, 20, 20, 21, 21, 20, 20,
    21, 21, 20, 20, 21, 21, 20, 20, 21, 21,
    20, 20, 21, 21, 20, 20, 21, 21, 20, 20,
    20, 21, 20, 20, 20, 21, 20, 20, 20, 21,
    20, 20, 20, 21, 20, 20, 20, 21, 20, 20,
    20, 21, 20, 20, 20, 21, 20, 20, 20, 20,
    20, 20, 20, 20, 20, 20, 20, 20, 20, 20,
    20, 20, 20, 20, 20, 20, 20, 20, 20, 20,
    21, 21, 21, 21, 21, 21, 21, 21, 20, 21,
    21, 21, 20, 21, 21, 21, 20, 21, 21, 21,
    20, 21, 21, 21, 20, 21, 21, 21, 20, 21,
    21, 21, 20, 21, 21, 21, 20, 20, 21, 21,
    20, 20, 21, 21, 20, 20, 21, 21, 20, 20,
    21, 21, 20, 20, 21, 21, 20, 20, 21, 21,
    20, 20, 21, 21, 20, 20, 21, 21, 20, 20,
    20, 21, 20, 20, 20, 21, 20, 20, 20, 21,
    20, 20, 20, 21, 20, 20, 20, 21, 20, 20,
    20, 21, 20, 20, 20, 21, 20, 20, 20, 20,
];

// Chile one-offs: papal visit, 2017 census, 16 September 2022.
const CHILE_ONE_OFF: i32[3] = [20180116, 20170419, 20220916];

// NewZealand::CommonImpl Matariki dates and the 2022 royal funeral.
const NZ_ONE_OFF: i32[32] = [
    20250620, 20300621, 20520621, 20220624, 20330624, 20440624,
    20270625, 20380625, 20490625, 20240628, 20350629, 20460629,
    20510630, 20320702, 20430703, 20480703, 20290706, 20400706,
    20340707, 20450707, 20260710, 20370710, 20310711, 20420711,
    20230714, 20280714, 20390715, 20500715, 20360718, 20410719,
    20470719, 20220926,
];

// UnitedStates::NyseImpl special closings, including multi-day closings.
const NYSE_ONE_OFF: i32[26] = [
    20250109, 20181205, 20121029, 20121030, 20070102, 20040611,
    20010911, 20010912, 20010913, 20010914, 19940427, 19850927,
    19770714, 19730125, 19721228, 19690721, 19690331, 19690210,
    19680705, 19680409, 19631125, 19610529, 19581226, 19541224,
    19561224, 19651224,
];

// UnitedStates::GovernmentBondImpl special closings. Sandy is the 30th only.
const BOND_ONE_OFF: i32[3] = [20181205, 20121030, 20040611];

fn known(kind: i32) -> bool {
    return kind >= ARGENTINA_MERVAL && kind <= BRAZIL_EXCHANGE;
}

fn is_business_day(kind: i32, d: date::Date) -> bool {
    if kind == ARGENTINA_MERVAL { return argentina(d); }
    if kind == AUSTRALIA_SETTLEMENT { return australia(d, true); }
    if kind == AUSTRALIA_ASX { return australia(d, false); }
    if kind == CANADA_SETTLEMENT { return canada(d, true); }
    if kind == CANADA_TSX { return canada(d, false); }
    if kind == CHILE_SSE { return chile(d); }
    if kind == MEXICO_BMV { return mexico(d); }
    if kind == NZ_WELLINGTON { return nz_wellington(d); }
    if kind == NZ_AUCKLAND { return nz_auckland(d); }
    if kind == US_NYSE { return nyse(d); }
    if kind == US_GOVERNMENT_BOND { return government_bond(d); }
    if kind == US_NERC { return nerc(d); }
    if kind == US_LIBOR_IMPACT { return libor(d); }
    if kind == US_FEDERAL_RESERVE { return federal_reserve(d); }
    if kind == US_SOFR { return sofr(d); }
    if kind == BRAZIL_EXCHANGE { return brazil_exchange(d); }
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

fn mlk(day: i32, w: i32, m: i32) -> bool {
    return day >= 15 && day <= 21 && w == date::MONDAY && m == date::JANUARY;
}

fn washington(day: i32, m: i32, y: i32, w: i32) -> bool {
    if y >= 1971 {
        return day >= 15 && day <= 21 && w == date::MONDAY && m == date::FEBRUARY;
    }
    return (day == 22 || (day == 23 && w == date::MONDAY) || (day == 21 && w == date::FRIDAY)) && m == date::FEBRUARY;
}

fn memorial(day: i32, m: i32, y: i32, w: i32) -> bool {
    if y >= 1971 {
        return day >= 25 && w == date::MONDAY && m == date::MAY;
    }
    return (day == 30 || (day == 31 && w == date::MONDAY) || (day == 29 && w == date::FRIDAY)) && m == date::MAY;
}

fn labor(day: i32, w: i32, m: i32) -> bool {
    return day <= 7 && w == date::MONDAY && m == date::SEPTEMBER;
}

fn columbus(day: i32, m: i32, y: i32, w: i32) -> bool {
    return day >= 8 && day <= 14 && w == date::MONDAY && m == date::OCTOBER && y >= 1971;
}

fn veterans(day: i32, m: i32, y: i32, w: i32) -> bool {
    if y <= 1970 || y >= 1978 {
        return (day == 11 || (day == 12 && w == date::MONDAY) || (day == 10 && w == date::FRIDAY)) && m == date::NOVEMBER;
    }
    return day >= 22 && day <= 28 && w == date::MONDAY && m == date::OCTOBER;
}

fn veterans_no_saturday(day: i32, m: i32, y: i32, w: i32) -> bool {
    if y <= 1970 || y >= 1978 {
        return (day == 11 || (day == 12 && w == date::MONDAY)) && m == date::NOVEMBER;
    }
    return day >= 22 && day <= 28 && w == date::MONDAY && m == date::OCTOBER;
}

fn juneteenth(day: i32, m: i32, y: i32, w: i32, to_friday: bool) -> bool {
    if m != date::JUNE || y < 2022 { return false; }
    if day == 19 { return true; }
    if day == 20 && w == date::MONDAY { return true; }
    if day == 18 && w == date::FRIDAY && to_friday { return true; }
    return false;
}

fn independence(day: i32, w: i32, m: i32) -> bool {
    return (day == 4 || (day == 5 && w == date::MONDAY) || (day == 3 && w == date::FRIDAY)) && m == date::JULY;
}

fn independence_monday(day: i32, w: i32, m: i32) -> bool {
    return (day == 4 || (day == 5 && w == date::MONDAY)) && m == date::JULY;
}

fn thanksgiving(day: i32, w: i32, m: i32) -> bool {
    return day >= 22 && day <= 28 && w == date::THURSDAY && m == date::NOVEMBER;
}

fn christmas(day: i32, w: i32, m: i32) -> bool {
    return (day == 25 || (day == 26 && w == date::MONDAY) || (day == 24 && w == date::FRIDAY)) && m == date::DECEMBER;
}

fn christmas_monday(day: i32, w: i32, m: i32) -> bool {
    return (day == 25 || (day == 26 && w == date::MONDAY)) && m == date::DECEMBER;
}

fn new_year(day: i32, w: i32, m: i32) -> bool {
    return (day == 1 || (day == 2 && w == date::MONDAY)) && m == date::JANUARY;
}

fn box_pair(day: i32, w: i32, m: i32) -> bool {
    if (day == 25 || (day == 27 && (w == date::MONDAY || w == date::TUESDAY))) && m == date::DECEMBER { return true; }
    if (day == 26 || (day == 28 && (w == date::MONDAY || w == date::TUESDAY))) && m == date::DECEMBER { return true; }
    return false;
}

fn argentina(d: date::Date) -> bool {
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
    if day == 1 && m == date::MAY { return false; }
    if day == 25 && m == date::MAY { return false; }
    if day >= 15 && day <= 21 && w == date::MONDAY && m == date::JUNE { return false; }
    if day == 9 && m == date::JULY { return false; }
    if day >= 15 && day <= 21 && w == date::MONDAY && m == date::AUGUST { return false; }
    if (day == 10 || day == 11 || day == 12 || day == 15 || day == 16) && w == date::MONDAY && m == date::OCTOBER { return false; }
    if day == 8 && m == date::DECEMBER { return false; }
    if day == 24 && m == date::DECEMBER { return false; }
    if (day == 31 || (day == 30 && w == date::FRIDAY)) && m == date::DECEMBER { return false; }
    return true;
}

fn australia(d: date::Date, settlement: bool) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if (day == 1 || ((day == 2 || day == 3) && w == date::MONDAY)) && m == date::JANUARY { return false; }
    if (day == 26 || ((day == 27 || day == 28) && w == date::MONDAY)) && m == date::JANUARY { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if day == 25 && m == date::APRIL { return false; }
    if day > 7 && day <= 14 && w == date::MONDAY && m == date::JUNE { return false; }
    if settlement {
        if day <= 7 && w == date::MONDAY && m == date::AUGUST { return false; }
        if day <= 7 && w == date::MONDAY && m == date::OCTOBER { return false; }
    }
    if box_pair(day, w, m) { return false; }
    if day == 22 && m == date::SEPTEMBER && y == 2022 { return false; }
    return true;
}

fn canada(d: date::Date, settlement: bool) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if (day == 1 || ((day == 2 || day == 3) && w == date::MONDAY)) && m == date::JANUARY { return false; }
    if day >= 15 && day <= 21 && w == date::MONDAY && m == date::FEBRUARY && y >= 2008 { return false; }
    if doy == em - 3 { return false; }
    if day > 17 && day <= 24 && w == date::MONDAY && m == date::MAY { return false; }
    if (day == 1 || ((day == 2 || day == 3) && w == date::MONDAY)) && m == date::JULY { return false; }
    if day <= 7 && w == date::MONDAY && m == date::AUGUST { return false; }
    if day <= 7 && w == date::MONDAY && m == date::SEPTEMBER { return false; }
    if settlement && y >= 2021 {
        if day == 30 && m == date::SEPTEMBER { return false; }
        if day <= 2 && m == date::OCTOBER && w == date::MONDAY { return false; }
    }
    if day > 7 && day <= 14 && w == date::MONDAY && m == date::OCTOBER { return false; }
    if settlement {
        if (day == 11 || ((day == 12 || day == 13) && w == date::MONDAY)) && m == date::NOVEMBER { return false; }
    }
    if box_pair(day, w, m) { return false; }
    return true;
}

fn aboriginal(day: i32, m: i32, y: i32) -> bool {
    if m != date::JUNE || y < 2021 { return false; }
    return day == ABORIGINAL[y - 2021];
}

fn chile(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if day == 1 && m == date::JANUARY { return false; }
    if day == 2 && m == date::JANUARY && w == date::MONDAY && y > 2016 { return false; }
    if doy == em - 3 { return false; }
    if doy == em - 2 { return false; }
    if day == 1 && m == date::MAY { return false; }
    if day == 21 && m == date::MAY { return false; }
    if aboriginal(day, m, y) { return false; }
    if day >= 26 && day <= 29 && m == date::JUNE && w == date::MONDAY { return false; }
    if day == 2 && m == date::JULY && w == date::MONDAY { return false; }
    if day == 16 && m == date::JULY { return false; }
    if day == 15 && m == date::AUGUST { return false; }
    if day == 17 && m == date::SEPTEMBER && ((w == date::MONDAY && y >= 2007) || (w == date::FRIDAY && y > 2016)) { return false; }
    if day == 18 && m == date::SEPTEMBER { return false; }
    if day == 19 && m == date::SEPTEMBER { return false; }
    if day == 20 && m == date::SEPTEMBER && w == date::FRIDAY && y >= 2007 { return false; }
    if day >= 9 && day <= 12 && m == date::OCTOBER && w == date::MONDAY { return false; }
    if day == 15 && m == date::OCTOBER && w == date::MONDAY { return false; }
    if y >= 2008 {
        if day == 27 && m == date::OCTOBER && w == date::FRIDAY { return false; }
        if day == 31 && m == date::OCTOBER && w != date::TUESDAY && w != date::WEDNESDAY { return false; }
        if day == 2 && m == date::NOVEMBER && w == date::FRIDAY { return false; }
    }
    if day == 1 && m == date::NOVEMBER { return false; }
    if day == 8 && m == date::DECEMBER { return false; }
    if day == 25 && m == date::DECEMBER { return false; }
    if day == 31 && m == date::DECEMBER { return false; }
    if on_list(CHILE_ONE_OFF, y, m, day) { return false; }
    return true;
}

fn mexico(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if day == 1 && m == date::JANUARY { return false; }
    if y <= 2005 && day == 5 && m == date::FEBRUARY { return false; }
    if y >= 2006 && day <= 7 && w == date::MONDAY && m == date::FEBRUARY { return false; }
    if y <= 2005 && day == 21 && m == date::MARCH { return false; }
    if y >= 2006 && day >= 15 && day <= 21 && w == date::MONDAY && m == date::MARCH { return false; }
    if doy == em - 4 { return false; }
    if doy == em - 3 { return false; }
    if day == 1 && m == date::MAY { return false; }
    if day == 16 && m == date::SEPTEMBER { return false; }
    if day == 1 && m == date::OCTOBER && y >= 2024 && (y - 2024) % 6 == 0 { return false; }
    if day == 2 && m == date::NOVEMBER { return false; }
    if y <= 2005 && day == 20 && m == date::NOVEMBER { return false; }
    if y >= 2006 && day >= 15 && day <= 21 && w == date::MONDAY && m == date::NOVEMBER { return false; }
    if day == 12 && m == date::DECEMBER { return false; }
    if day == 25 && m == date::DECEMBER { return false; }
    return true;
}

fn nz_common(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if (day == 1 || (day == 3 && (w == date::MONDAY || w == date::TUESDAY))) && m == date::JANUARY { return false; }
    if (day == 2 || (day == 4 && (w == date::MONDAY || w == date::TUESDAY))) && m == date::JANUARY { return false; }
    if day == 6 && m == date::FEBRUARY { return false; }
    if (day == 7 || day == 8) && w == date::MONDAY && m == date::FEBRUARY && y > 2013 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if day == 25 && m == date::APRIL { return false; }
    if (day == 26 || day == 27) && w == date::MONDAY && m == date::APRIL && y > 2013 { return false; }
    if day <= 7 && w == date::MONDAY && m == date::JUNE { return false; }
    if day >= 22 && day <= 28 && w == date::MONDAY && m == date::OCTOBER { return false; }
    if box_pair(day, w, m) { return false; }
    if on_list(NZ_ONE_OFF, y, m, day) { return false; }
    return true;
}

fn nz_wellington(d: date::Date) -> bool {
    if !nz_common(d) { return false; }
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    if day >= 19 && day <= 25 && w == date::MONDAY && m == date::JANUARY { return false; }
    return true;
}

fn nz_auckland(d: date::Date) -> bool {
    if !nz_common(d) { return false; }
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    if day >= 26 && w == date::MONDAY && m == date::JANUARY { return false; }
    if day == 1 && w == date::MONDAY && m == date::FEBRUARY { return false; }
    return true;
}

fn nyse(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if new_year(day, w, m) { return false; }
    if washington(day, m, y, w) { return false; }
    if doy == em - 3 { return false; }
    if memorial(day, m, y, w) { return false; }
    if juneteenth(day, m, y, w, true) { return false; }
    if independence(day, w, m) { return false; }
    if labor(day, w, m) { return false; }
    if thanksgiving(day, w, m) { return false; }
    if christmas(day, w, m) { return false; }
    if y >= 1998 && mlk(day, w, m) { return false; }
    if (y <= 1968 || (y <= 1980 && y % 4 == 0)) && m == date::NOVEMBER && day <= 7 && w == date::TUESDAY { return false; }
    if on_list(NYSE_ONE_OFF, y, m, day) { return false; }
    if y == 1968 && doy >= 163 && w == date::WEDNESDAY { return false; }
    return true;
}

fn government_bond(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if new_year(day, w, m) { return false; }
    if mlk(day, w, m) && y >= 1983 { return false; }
    if washington(day, m, y, w) { return false; }
    if doy == em - 3 && (y < 1996 || day > 7) { return false; }
    if memorial(day, m, y, w) { return false; }
    if juneteenth(day, m, y, w, true) { return false; }
    if independence(day, w, m) { return false; }
    if labor(day, w, m) { return false; }
    if columbus(day, m, y, w) { return false; }
    if veterans_no_saturday(day, m, y, w) { return false; }
    if thanksgiving(day, w, m) { return false; }
    if christmas(day, w, m) { return false; }
    if on_list(BOND_ONE_OFF, y, m, day) { return false; }
    return true;
}

fn nerc(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    if weekend(w) { return false; }
    if new_year(day, w, m) { return false; }
    if memorial(day, m, y, w) { return false; }
    if independence_monday(day, w, m) { return false; }
    if labor(day, w, m) { return false; }
    if thanksgiving(day, w, m) { return false; }
    if christmas_monday(day, w, m) { return false; }
    return true;
}

fn us_settlement(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    if weekend(w) { return false; }
    if new_year(day, w, m) { return false; }
    if day == 31 && w == date::FRIDAY && m == date::DECEMBER { return false; }
    if mlk(day, w, m) && y >= 1983 { return false; }
    if washington(day, m, y, w) { return false; }
    if memorial(day, m, y, w) { return false; }
    if juneteenth(day, m, y, w, true) { return false; }
    if independence(day, w, m) { return false; }
    if labor(day, w, m) { return false; }
    if columbus(day, m, y, w) { return false; }
    if veterans(day, m, y, w) { return false; }
    if thanksgiving(day, w, m) { return false; }
    if christmas(day, w, m) { return false; }
    return true;
}

fn libor(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    if ((day == 5 && w == date::MONDAY) || (day == 3 && w == date::FRIDAY)) && m == date::JULY && y >= 2015 {
        return true;
    }
    return us_settlement(d);
}

fn federal_reserve(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    if weekend(w) { return false; }
    if new_year(day, w, m) { return false; }
    if mlk(day, w, m) && y >= 1983 { return false; }
    if washington(day, m, y, w) { return false; }
    if memorial(day, m, y, w) { return false; }
    if juneteenth(day, m, y, w, false) { return false; }
    if independence_monday(day, w, m) { return false; }
    if labor(day, w, m) { return false; }
    if columbus(day, m, y, w) { return false; }
    if veterans_no_saturday(day, m, y, w) { return false; }
    if thanksgiving(day, w, m) { return false; }
    if christmas_monday(day, w, m) { return false; }
    return true;
}

fn sofr(d: date::Date) -> bool {
    let y = date::year(d);
    let doy = date::day_of_year(d);
    if doy == easter::western(y) - 3 { return false; }
    return government_bond(d);
}

fn brazil_exchange(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if day == 1 && m == date::JANUARY { return false; }
    if day == 25 && m == date::JANUARY && y < 2022 { return false; }
    if day == 21 && m == date::APRIL { return false; }
    if day == 1 && m == date::MAY { return false; }
    if day == 9 && m == date::JULY && y < 2022 { return false; }
    if day == 7 && m == date::SEPTEMBER { return false; }
    if day == 12 && m == date::OCTOBER { return false; }
    if day == 2 && m == date::NOVEMBER { return false; }
    if day == 15 && m == date::NOVEMBER { return false; }
    if day == 20 && m == date::NOVEMBER && y >= 2007 && y != 2022 && y != 2023 { return false; }
    if day == 24 && m == date::DECEMBER { return false; }
    if day == 25 && m == date::DECEMBER { return false; }
    if doy == em - 3 { return false; }
    if doy == em - 49 || doy == em - 48 { return false; }
    if doy == em + 59 { return false; }
    if m == date::DECEMBER && (day == 31 || (day >= 29 && w == date::FRIDAY)) { return false; }
    return true;
}
