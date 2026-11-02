// Market holiday rules. A market is an i32. A day is a business day when
// is_business_day returns true. Western Easter Monday is easter::western(year),
// a day-of-year. Tabulated dates are yyyymmdd.
//
// ISRAEL_SETTLEMENT  210  Israel::Settlement (TelAvivImpl)
// ISRAEL_TASE        211  Israel::TASE (TelAvivImpl)
// ISRAEL_SHIR        212  Israel::SHIR
// ISRAEL_TELBOR      213  Israel::Telbor
// SAUDI_ARABIA       214  SaudiArabia::Tadawul
// SOUTH_AFRICA       215  SouthAfrica() settlement
// TURKEY             216  Turkey
// BOTSWANA           217  Botswana
// UZBEKISTAN         218  Uzbekistan::UZSE

import date;
import easter;

namespace markets_other;

const ISRAEL_SETTLEMENT: i32 = 210;
const ISRAEL_TASE: i32 = 211;
const ISRAEL_SHIR: i32 = 212;
const ISRAEL_TELBOR: i32 = 213;
const SAUDI_ARABIA: i32 = 214;
const SOUTH_AFRICA: i32 = 215;
const TURKEY: i32 = 216;
const BOTSWANA: i32 = 217;
const UZBEKISTAN: i32 = 218;

// Purim, Israel 2000-2050.
const PURIM: i32[51] = [
    20000321, 20010309, 20020226, 20030318, 20040307, 20050325, 20060314, 20070304,
    20080321, 20090310, 20100228, 20110320, 20120308, 20130224, 20140316, 20150305,
    20160324, 20170312, 20180301, 20190321, 20200310, 20210226, 20220317, 20230307,
    20240324, 20250314, 20260303, 20270323, 20280312, 20290301, 20300319, 20310309,
    20320226, 20330315, 20340305, 20350325, 20360313, 20370301, 20380321, 20390310,
    20400228, 20410317, 20420306, 20430326, 20440313, 20450303, 20460322, 20470312,
    20480228, 20490318, 20500308,
];
// Passover I, Israel 2000-2050.
const PASSOVER: i32[51] = [
    20000420, 20010408, 20020328, 20030417, 20040406, 20050424, 20060413, 20070403,
    20080420, 20090409, 20100330, 20110419, 20120407, 20130326, 20140415, 20150404,
    20160423, 20170411, 20180331, 20190420, 20200409, 20210328, 20220416, 20230406,
    20240423, 20250413, 20260402, 20270422, 20280411, 20290331, 20300418, 20310408,
    20320327, 20330414, 20340404, 20350424, 20360412, 20370331, 20380420, 20390409,
    20400329, 20410416, 20420405, 20430425, 20440412, 20450402, 20460421, 20470411,
    20480329, 20490417, 20500407,
];
// Independence Day, Israel 2000-2050.
const INDEPENDENCE: i32[51] = [
    20000510, 20010426, 20020417, 20030507, 20040427, 20050512, 20060503, 20070424,
    20080508, 20090429, 20100420, 20110510, 20120426, 20130416, 20140506, 20150423,
    20160512, 20170502, 20180419, 20190509, 20200429, 20210415, 20220505, 20230426,
    20240514, 20250501, 20260422, 20270512, 20280502, 20290419, 20300508, 20310429,
    20320415, 20330504, 20340425, 20350515, 20360501, 20370421, 20380510, 20390428,
    20400418, 20410507, 20420424, 20430514, 20440503, 20450420, 20460510, 20470501,
    20480416, 20490506, 20500427,
];
// Shavuot, Israel 2000-2050.
const SHAVUOT: i32[51] = [
    20000609, 20010528, 20020517, 20030606, 20040526, 20050613, 20060602, 20070523,
    20080609, 20090529, 20100519, 20110608, 20120527, 20130515, 20140604, 20150524,
    20160612, 20170531, 20180520, 20190609, 20200529, 20210517, 20220605, 20230526,
    20240612, 20250602, 20260522, 20270611, 20280531, 20290520, 20300607, 20310528,
    20320516, 20330603, 20340524, 20350613, 20360601, 20370520, 20380609, 20390529,
    20400518, 20410605, 20420525, 20430614, 20440601, 20450522, 20460610, 20470531,
    20480518, 20490606, 20500527,
];
// Fast of Ninth of Av, Israel 2000-2050.
const FAST_DAY: i32[51] = [
    20000810, 20010729, 20020718, 20030807, 20040727, 20050814, 20060803, 20070724,
    20080810, 20090730, 20100720, 20110809, 20120729, 20130716, 20140805, 20150726,
    20160814, 20170801, 20180722, 20190811, 20200730, 20210718, 20220807, 20230727,
    20240813, 20250803, 20260723, 20270812, 20280801, 20290722, 20300808, 20310729,
    20320718, 20330804, 20340725, 20350814, 20360803, 20370721, 20380810, 20390731,
    20400719, 20410806, 20420727, 20430816, 20440802, 20450723, 20460812, 20470801,
    20480719, 20490808, 20500728,
];
// Rosh Hashanah, Israel 2000-2050.
const ROSH: i32[51] = [
    20000930, 20010917, 20020907, 20030927, 20040916, 20051004, 20060923, 20070913,
    20080930, 20090919, 20100909, 20110929, 20120917, 20130905, 20140925, 20150914,
    20161003, 20170921, 20180910, 20190930, 20200919, 20210907, 20220926, 20230916,
    20241003, 20250923, 20260912, 20271002, 20280921, 20290910, 20300928, 20310918,
    20320906, 20330924, 20340914, 20351004, 20360922, 20370910, 20380930, 20390919,
    20400908, 20410926, 20420915, 20431005, 20440922, 20450912, 20461001, 20470921,
    20480908, 20490927, 20500917,
];
// Tadawul Eid al-Adha windows, inclusive yyyymmdd pairs.
const EID_ADHA: i32[66] = [
    19980406, 19980411, 19990326, 19990331, 20000315, 20000320, 20010304, 20010309,
    20020222, 20020227, 20030211, 20030216, 20040131, 20040205, 20050120, 20050125,
    20060109, 20060114, 20061230, 20070104, 20071219, 20071224, 20081207, 20081212,
    20091126, 20091201, 20101115, 20101120, 20111105, 20111110, 20121025, 20121103,
    20131011, 20131019, 20141003, 20141011, 20150922, 20150927, 20160910, 20160915,
    20170831, 20170905, 20180822, 20180827, 20190811, 20190816, 20200730, 20200804,
    20210719, 20210724, 20220709, 20220714, 20230623, 20230701, 20240614, 20240622,
    20250605, 20250610, 20260522, 20260530, 20270516, 20270520, 20280503, 20280509,
    20290422, 20290426,
];
// Tadawul Eid al-Fitr windows, inclusive yyyymmdd pairs.
const EID_FITR: i32[58] = [
    20011215, 20011220, 20021204, 20021209, 20031124, 20031129, 20041112, 20041117,
    20051102, 20051107, 20061022, 20061027, 20071011, 20071016, 20080929, 20081004,
    20090919, 20090924, 20100909, 20100914, 20110829, 20110903, 20120816, 20120824,
    20130806, 20130812, 20140725, 20140803, 20150718, 20150721, 20160705, 20160710,
    20170624, 20170629, 20180614, 20180619, 20190603, 20190608, 20200523, 20200528,
    20210512, 20210517, 20220501, 20220506, 20230417, 20230425, 20240404, 20240414,
    20250327, 20250402, 20260317, 20260323, 20270307, 20270311, 20280227, 20280302,
    20290212, 20290218,
];
// MoonSightingMethod Eid al-Fitr, from islamicholidays.cpp.
const MOON_FITR: i32[16] = [
    20260320, 20270310, 20280227, 20290215, 20300205, 20310125, 20320114, 20330102,
    20331223, 20341212, 20351201, 20361119, 20371108, 20381029, 20391019, 20401007,
];
// MoonSightingMethod Eid al-Adha, from islamicholidays.cpp.
const MOON_ADHA: i32[16] = [
    20260527, 20270517, 20280505, 20290424, 20300413, 20310403, 20320322, 20330311,
    20340228, 20350218, 20360207, 20370127, 20380116, 20390105, 20391226, 20401215,
];
fn known(kind: i32) -> bool {
    return kind >= ISRAEL_SETTLEMENT && kind <= UZBEKISTAN;
}

fn is_business_day(kind: i32, d: date::Date) -> bool {
    if kind == ISRAEL_SETTLEMENT || kind == ISRAEL_TASE { return israel_tase(d); }
    if kind == ISRAEL_SHIR { return israel_shir(d); }
    if kind == ISRAEL_TELBOR { return israel_telbor(d); }
    if kind == SAUDI_ARABIA { return saudi(d); }
    if kind == SOUTH_AFRICA { return south_africa(d); }
    if kind == TURKEY { return turkey(d); }
    if kind == BOTSWANA { return botswana(d); }
    if kind == UZBEKISTAN { return uzbekistan(d); }
    return true;
}

fn listed(xs: i32[:], n: i32) -> bool {
    var i: i64 = 0;
    while i < xs.len {
        if xs[i] == n { return true; }
        i += 1;
    }
    return false;
}

fn pack(d: date::Date) -> i32 {
    return date::year(d) * 10000 + date::month(d) * 100 + date::day_of_month(d);
}

fn on_table(xs: i32[:], d: date::Date, shift: i32) -> bool {
    let s, ok = date::plus_days(d, shift);
    if !ok { return false; }
    return listed(xs, pack(s));
}

fn in_span(xs: i32[:], n: i32) -> bool {
    var i: i64 = 0;
    while i + 1 < xs.len {
        if n >= xs[i] && n <= xs[i + 1] { return true; }
        i += 2;
    }
    return false;
}

fn weekend(w: i32) -> bool {
    return w == date::SATURDAY || w == date::SUNDAY;
}

fn tase_weekend(d: date::Date) -> bool {
    let w = date::weekday(d);
    if pack(d) >= 20260105 { return weekend(w); }
    return w == date::FRIDAY || w == date::SATURDAY;
}

fn saudi_weekend(d: date::Date) -> bool {
    let w = date::weekday(d);
    if pack(d) < 20130629 { return w == date::THURSDAY || w == date::FRIDAY; }
    return w == date::FRIDAY || w == date::SATURDAY;
}

fn israel_tase(d: date::Date) -> bool {
    let y = date::year(d);
    if tase_weekend(d) { return false; }
    if on_table(PURIM, d, 0) { return false; }
    if y <= 2020 && on_table(PASSOVER, d, 1) { return false; }
    if on_table(PASSOVER, d, 0) || on_table(PASSOVER, d, -5) || on_table(PASSOVER, d, -6) { return false; }
    if on_table(INDEPENDENCE, d, 1) || on_table(INDEPENDENCE, d, 0) { return false; }
    if y <= 2020 && on_table(SHAVUOT, d, 1) { return false; }
    if on_table(SHAVUOT, d, 0) || on_table(FAST_DAY, d, 0) { return false; }
    if y <= 2019 && on_table(ROSH, d, 1) { return false; }
    if on_table(ROSH, d, 0) || on_table(ROSH, d, -1) { return false; }
    if on_table(ROSH, d, -8) || on_table(ROSH, d, -9) { return false; }
    if on_table(ROSH, d, -13) || on_table(ROSH, d, -14) { return false; }
    if on_table(ROSH, d, -20) || on_table(ROSH, d, -21) { return false; }
    return true;
}

fn israel_shir(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    if weekend(w) { return false; }
    if on_table(PURIM, d, 0) || on_table(PURIM, d, -1) { return false; }
    if on_table(PASSOVER, d, 1) || on_table(PASSOVER, d, 0) || on_table(PASSOVER, d, -6) { return false; }
    if on_table(INDEPENDENCE, d, 0) { return false; }
    if on_table(SHAVUOT, d, 0) || on_table(FAST_DAY, d, 0) { return false; }
    if on_table(ROSH, d, 1) || on_table(ROSH, d, 0) || on_table(ROSH, d, -1) { return false; }
    if on_table(ROSH, d, -8) || on_table(ROSH, d, -9) { return false; }
    if on_table(ROSH, d, -14) || on_table(ROSH, d, -21) { return false; }
    if day == 27 && m == 2 && y == 2024 { return false; }
    if day == 1 && m == 1 { return false; }
    if doy == easter::western(y) - 3 { return false; }
    if day >= 25 && w == date::MONDAY && m == 5 && y != 2022 { return false; }
    if day == 3 && m == 6 && y == 2022 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    if day == 1 && m == 11 && y == 2022 { return false; }
    if day == 2 && m == 1 && y == 2023 { return false; }
    if day == 10 && m == 4 && y == 2023 { return false; }
    return true;
}

fn israel_telbor(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    if weekend(w) { return false; }
    if day == 1 && m == 1 { return false; }
    if ((day == 9 && m == 4) || (day == 17 && m == 9)) && y == 2019 { return false; }
    if day == 2 && m == 3 && y == 2020 { return false; }
    if ((day == 22 && m == 4) || (day == 27 && m == 5)) && y == 2019 { return false; }
    if (((day == 10 || day == 13) && m == 4) || ((day == 8 || day == 25) && m == 5)) && y == 2020 { return false; }
    if on_table(PURIM, d, 0) || on_table(PURIM, d, -1) { return false; }
    if on_table(PASSOVER, d, 1) || on_table(PASSOVER, d, 0) || on_table(PASSOVER, d, -6) { return false; }
    if on_table(INDEPENDENCE, d, 0) { return false; }
    if on_table(SHAVUOT, d, 0) || on_table(FAST_DAY, d, 0) { return false; }
    if on_table(ROSH, d, 0) || on_table(ROSH, d, -1) { return false; }
    if on_table(ROSH, d, -9) || on_table(ROSH, d, -14) || on_table(ROSH, d, -21) { return false; }
    if day >= 25 && w == date::MONDAY && m == 5 && y != 2002 && y != 2012 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 && y >= 2000 && y != 2020 { return false; }
    return true;
}

fn saudi(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let n = pack(d);
    if saudi_weekend(d) { return false; }
    if in_span(EID_ADHA, n) || in_span(EID_FITR, n) { return false; }
    if day == 23 && m == 9 { return false; }
    if (day == 22 || ((day == 23 || day == 24) && w == date::SUNDAY)) && m == 2 && y >= 2022 { return false; }
    if day == 26 && m == 2 && y == 2011 { return false; }
    if day == 19 && m == 3 && y == 2011 { return false; }
    return true;
}

fn south_africa(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if (day == 1 || (day == 2 && w == date::MONDAY)) && m == 1 { return false; }
    if doy == em - 3 || doy == em { return false; }
    if (day == 21 || (day == 22 && w == date::MONDAY)) && m == 3 { return false; }
    if (day == 27 || (day == 28 && w == date::MONDAY)) && m == 4 { return false; }
    if (day == 1 || (day == 2 && w == date::MONDAY)) && m == 5 { return false; }
    if (day == 16 || (day == 17 && w == date::MONDAY)) && m == 6 { return false; }
    if (day == 9 || (day == 10 && w == date::MONDAY)) && m == 8 { return false; }
    if (day == 24 || (day == 25 && w == date::MONDAY)) && m == 9 { return false; }
    if (day == 16 || (day == 17 && w == date::MONDAY)) && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if (day == 26 || (day == 27 && w == date::MONDAY)) && m == 12 { return false; }
    if day == 14 && m == 4 && y == 2004 { return false; }
    if day == 22 && m == 4 && y == 2009 { return false; }
    if day == 3 && m == 8 && y == 2016 { return false; }
    if day == 1 && m == 11 && y == 2021 { return false; }
    if day == 29 && m == 5 && y == 2024 { return false; }
    if day == 4 && m == 11 && y == 2026 { return false; }
    if day == 27 && m == 12 && y == 2022 { return false; }
    if day == 15 && m == 12 && y == 2023 { return false; }
    return true;
}

fn turkey_local(day: i32, m: i32, y: i32) -> bool {
    if y == 2004 { return (m == 2 && day <= 4) || (m == 11 && day >= 14 && day <= 16); }
    if y == 2005 { return (m == 1 && day >= 19 && day <= 21) || (m == 11 && day >= 2 && day <= 5); }
    if y == 2006 { return (m == 1 && day >= 10 && day <= 13) || (m == 10 && day >= 23 && day <= 25) || (m == 12 && day == 31); }
    if y == 2007 { return (m == 1 && day <= 3) || (m == 10 && day >= 12 && day <= 14) || (m == 12 && day >= 20 && day <= 23); }
    if y == 2008 { return (m == 9 && day == 30) || (m == 10 && day <= 2) || (m == 12 && day >= 8 && day <= 11); }
    if y == 2009 { return (m == 9 && day >= 20 && day <= 22) || (m == 11 && day >= 27 && day <= 30); }
    if y == 2010 { return (m == 9 && day >= 9 && day <= 11) || (m == 11 && day >= 16 && day <= 19); }
    if y == 2011 { return (m == 10 && day == 1) || (m == 11 && day >= 9 && day <= 13); }
    if y == 2012 { return (m == 8 && day >= 18 && day <= 21) || (m == 10 && day >= 24 && day <= 28); }
    if y == 2013 { return (m == 8 && day >= 7 && day <= 10) || (m == 10 && day >= 14 && day <= 18) || (m == 10 && day == 28); }
    if y == 2014 { return (m == 7 && day >= 27 && day <= 30) || (m == 10 && day >= 4 && day <= 7) || (m == 10 && day == 29); }
    if y == 2015 { return (m == 7 && day >= 17 && day <= 19) || (m == 10 && day >= 24 && day <= 27); }
    if y == 2016 { return (m == 7 && day >= 5 && day <= 7) || (m == 9 && day >= 12 && day <= 15); }
    if y == 2017 { return (m == 6 && day >= 25 && day <= 27) || (m == 9 && day >= 1 && day <= 4); }
    if y == 2018 { return (m == 6 && day >= 15 && day <= 17) || (m == 8 && day >= 21 && day <= 24); }
    if y == 2019 { return (m == 6 && day >= 4 && day <= 6) || (m == 8 && day >= 11 && day <= 14); }
    if y == 2020 { return (m == 5 && day >= 24 && day <= 26) || (m == 7 && day == 31) || (m == 8 && day >= 1 && day <= 3); }
    if y == 2021 { return (m == 5 && day >= 13 && day <= 15) || (m == 7 && day >= 20 && day <= 23); }
    if y == 2022 { return (m == 5 && day >= 2 && day <= 4) || (m == 7 && day >= 9 && day <= 12); }
    if y == 2023 { return (m == 4 && day >= 21 && day <= 23) || (m == 6 && day >= 28 && day <= 30); }
    if y == 2024 { return (m == 4 && day >= 10 && day <= 12) || (m == 6 && day >= 17 && day <= 19); }
    if y == 2025 { return (m == 3 && day == 31) || (m == 4 && day >= 1 && day <= 2) || (m == 6 && day >= 6 && day <= 9); }
    if y == 2026 { return (m == 3 && day >= 20 && day <= 22) || (m == 5 && day >= 26 && day <= 29); }
    if y == 2027 { return (m == 3 && day >= 10 && day <= 12) || (m == 5 && day >= 16 && day <= 19); }
    if y == 2028 { return (m == 2 && day >= 27 && day <= 29) || (m == 5 && day >= 4 && day <= 7); }
    if y == 2029 { return (m == 2 && day >= 15 && day <= 17) || (m == 4 && day >= 23 && day <= 26); }
    if y == 2030 { return (m == 2 && day >= 5 && day <= 7) || (m == 4 && day >= 13 && day <= 16); }
    if y == 2031 { return (m == 1 && day >= 25 && day <= 27) || (m == 4 && day >= 2 && day <= 5); }
    if y == 2032 { return (m == 1 && day >= 14 && day <= 16) || (m == 3 && day >= 21 && day <= 24); }
    if y == 2033 { return (m == 1 && day >= 3 && day <= 5) || (m == 12 && day == 23) || (m == 3 && day >= 11 && day <= 14); }
    if y == 2034 { return (m == 12 && day >= 12 && day <= 14) || (m == 2 && day == 28) || (m == 3 && day >= 1 && day <= 3); }
    return false;
}

fn turkey(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    if weekend(w) { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 23 && m == 4 { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 19 && m == 5 { return false; }
    if day == 15 && m == 7 && y >= 2017 { return false; }
    if day == 30 && m == 8 { return false; }
    if day == 29 && m == 10 { return false; }
    if turkey_local(day, m, y) { return false; }
    return true;
}

fn botswana(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let doy = date::day_of_year(d);
    let em = easter::western(date::year(d));
    if weekend(w) { return false; }
    if (day == 1 || (day == 2 && w == date::MONDAY) || (day == 3 && w == date::TUESDAY)) && m == 1 { return false; }
    if doy == em - 3 || doy == em || doy == em + 38 { return false; }
    if (day == 1 || (day == 2 && w == date::MONDAY)) && m == 5 { return false; }
    if (day == 1 || (day == 2 && w == date::MONDAY)) && m == 7 { return false; }
    if day >= 15 && day <= 21 && w == date::MONDAY && m == 7 { return false; }
    if (day == 30 && m == 9) || (day == 1 && w == date::MONDAY && m == 10) { return false; }
    if (day == 1 || (day == 2 && w == date::MONDAY) || (day == 3 && w == date::TUESDAY)) && m == 10 { return false; }
    if day == 25 && m == 12 { return false; }
    if (day == 26 || (day == 27 && w == date::MONDAY)) && m == 12 { return false; }
    return true;
}

fn uzbekistan(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let n = pack(d);
    if weekend(w) { return false; }
    if listed(MOON_FITR, n) || listed(MOON_ADHA, n) { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 8 && m == 3 { return false; }
    if day == 21 && m == 3 { return false; }
    if day == 9 && m == 5 { return false; }
    if day == 1 && m == 9 { return false; }
    if day == 1 && m == 10 { return false; }
    if day == 8 && m == 12 { return false; }
    return true;
}
