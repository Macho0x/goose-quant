// Eastern European holiday rules. A market is an i32. A day is a
// business day when is_business_day returns true.
// Western Easter Monday is easter::western(year), a day-of-year.
// Orthodox Easter Monday is easter::orthodox(year).
// Weekend is Saturday and Sunday, except Malta (Friday and Saturday).
//
// CZECH_PSE 70: CzechRepublic::PSE
// HUNGARY 71: Hungary
// POLAND_SETTLEMENT 72: Poland::Settlement
// POLAND_WSE 73: Poland::WSE
// ROMANIA_PUBLIC 74: Romania::Public
// ROMANIA_BVB 75: Romania::BVB
// RUSSIA_SETTLEMENT 76: Russia::Settlement
// RUSSIA_MOEX 77: Russia::MOEX
// SLOVAKIA_BSSE 78: Slovakia::BSSE
// SLOVENIA_LSE 79: Slovenia::LSE
// UKRAINE_USE 80: Ukraine::USE
// CROATIA_ZSE 81: Croatia::ZSE
// SERBIA_BSE 82: Serbia::BSE
// MONTENEGRO_MNSE 83: Montenegro::MNSE
// NORTH_MACEDONIA_MSE 84: NorthMacedonia::MSE
// MALTA_MSE 85: Malta::MSE

import date;
import easter;

namespace markets_east;

const CZECH_PSE: i32 = 70;
const HUNGARY: i32 = 71;
const POLAND_SETTLEMENT: i32 = 72;
const POLAND_WSE: i32 = 73;
const ROMANIA_PUBLIC: i32 = 74;
const ROMANIA_BVB: i32 = 75;
const RUSSIA_SETTLEMENT: i32 = 76;
const RUSSIA_MOEX: i32 = 77;
const SLOVAKIA_BSSE: i32 = 78;
const SLOVENIA_LSE: i32 = 79;
const UKRAINE_USE: i32 = 80;
const CROATIA_ZSE: i32 = 81;
const SERBIA_BSE: i32 = 82;
const MONTENEGRO_MNSE: i32 = 83;
const NORTH_MACEDONIA_MSE: i32 = 84;
const MALTA_MSE: i32 = 85;

// One-off Russian settlement holidays, yyyymmdd.
const RU_SETTLE_EXTRA: i32[18] = [
    20170224, 20170508, 20171106,
    20180309, 20180430, 20180502, 20180611, 20181231,
    20190502, 20190503, 20190510,
    20200330, 20200331, 20200401, 20200402, 20200403, 20200504, 20200505,
];

// MOEX weekends that are open, yyyymmdd.
const RU_MOEX_OPEN: i32[9] = [
    20120311, 20120428, 20120505, 20120512, 20120609,
    20160220,
    20180428, 20180609, 20181229,
];

// One-off MOEX holidays, yyyymmdd.
const RU_MOEX_EXTRA: i32[39] = [
    20120102, 20120309, 20120430, 20120611,
    20130101, 20130102, 20130103, 20130104, 20130107,
    20140101, 20140102, 20140103, 20140107,
    20150101, 20150102, 20150107,
    20160101, 20160107, 20160108, 20160502, 20160503, 20160613, 20161230,
    20170102, 20170508,
    20180101, 20180102, 20180108, 20181231,
    20190101, 20190102, 20190107, 20191231,
    20200101, 20200102, 20200107, 20200224, 20200624, 20200701,
];

// North Macedonia Eid al-Fitr and Eid al-Adha, yyyymmdd.
const NM_FITR: i32[16] = [
    20260320, 20270310, 20280227, 20290215, 20300205, 20310125, 20320114, 20330102,
    20331223, 20341212, 20351201, 20361119, 20371108, 20381029, 20391019, 20401007,
];

const NM_ADHA: i32[16] = [
    20260527, 20270517, 20280505, 20290424, 20300413, 20310403, 20320322, 20330311,
    20340228, 20350218, 20360207, 20370127, 20380116, 20390105, 20391226, 20401215,
];

fn known(kind: i32) -> bool {
    return kind >= CZECH_PSE && kind <= MALTA_MSE;
}

fn is_business_day(kind: i32, d: date::Date) -> bool {
    if kind == CZECH_PSE { return czech_pse(d); }
    if kind == HUNGARY { return hungary(d); }
    if kind == POLAND_SETTLEMENT { return poland_settlement(d); }
    if kind == POLAND_WSE { return poland_wse(d); }
    if kind == ROMANIA_PUBLIC { return romania_public(d); }
    if kind == ROMANIA_BVB { return romania_bvb(d); }
    if kind == RUSSIA_SETTLEMENT { return russia_settlement(d); }
    if kind == RUSSIA_MOEX { return russia_moex(d); }
    if kind == SLOVAKIA_BSSE { return slovakia_bsse(d); }
    if kind == SLOVENIA_LSE { return slovenia_lse(d); }
    if kind == UKRAINE_USE { return ukraine_use(d); }
    if kind == CROATIA_ZSE { return croatia_zse(d); }
    if kind == SERBIA_BSE { return serbia_bse(d); }
    if kind == MONTENEGRO_MNSE { return montenegro_mnse(d); }
    if kind == NORTH_MACEDONIA_MSE { return north_macedonia_mse(d); }
    if kind == MALTA_MSE { return malta_mse(d); }
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

fn moved_monday(day: i32, w: i32, base: i32) -> bool {
    if day == base { return true; }
    if w == date::MONDAY && (day == base + 1 || day == base + 2) { return true; }
    return false;
}

fn czech_pse(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if day == 1 && m == 1 { return false; }
    if doy == em - 3 && y >= 2016 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 8 && m == 5 { return false; }
    if day == 5 && m == 7 { return false; }
    if day == 6 && m == 7 { return false; }
    if day == 28 && m == 9 { return false; }
    if day == 28 && m == 10 { return false; }
    if day == 17 && m == 11 { return false; }
    if day == 24 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    if day == 2 && m == 1 && y == 2004 { return false; }
    if day == 31 && m == 12 && y == 2004 { return false; }
    return true;
}

fn hungary(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if doy == em - 3 && y >= 2017 { return false; }
    if doy == em { return false; }
    if doy == em + 49 { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 15 && m == 3 { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 20 && m == 8 { return false; }
    if day == 23 && m == 10 { return false; }
    if day == 1 && m == 11 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    return true;
}

fn poland_settlement(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if doy == em { return false; }
    if doy == em + 59 { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 6 && m == 1 && y >= 2011 { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 3 && m == 5 { return false; }
    if day == 15 && m == 8 { return false; }
    if day == 1 && m == 11 { return false; }
    if day == 11 && m == 11 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    return true;
}

fn poland_wse(d: date::Date) -> bool {
    let day = date::day_of_month(d);
    let m = date::month(d);
    if day == 24 && m == 12 { return false; }
    if day == 31 && m == 12 { return false; }
    return poland_settlement(d);
}

fn romania_public(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::orthodox(y);
    if weekend(w) { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 2 && m == 1 { return false; }
    if day == 6 && m == 1 && y >= 2024 { return false; }
    if day == 7 && m == 1 && y >= 2024 { return false; }
    if day == 24 && m == 1 { return false; }
    if doy == em - 3 && y >= 2018 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if doy == em + 49 { return false; }
    if day == 1 && m == 6 && y >= 2017 { return false; }
    if day == 15 && m == 8 { return false; }
    if day == 30 && m == 11 { return false; }
    if day == 1 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    return true;
}

fn romania_bvb(d: date::Date) -> bool {
    if !romania_public(d) { return false; }
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    if day == 24 && m == 12 && y == 2014 { return false; }
    if day == 31 && m == 12 && y == 2014 { return false; }
    return true;
}

fn russia_settlement(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    if weekend(w) { return false; }
    if y <= 2005 && day <= 2 && m == 1 { return false; }
    if y >= 2005 && day <= 5 && m == 1 { return false; }
    if y == 2012 && day == 6 && m == 1 { return false; }
    if moved_monday(day, w, 7) && m == 1 { return false; }
    if moved_monday(day, w, 23) && m == 2 { return false; }
    if moved_monday(day, w, 8) && m == 3 { return false; }
    if moved_monday(day, w, 1) && m == 5 { return false; }
    if moved_monday(day, w, 9) && m == 5 { return false; }
    if moved_monday(day, w, 12) && m == 6 { return false; }
    if moved_monday(day, w, 4) && m == 11 { return false; }
    if on_list(RU_SETTLE_EXTRA, y, m, day) { return false; }
    return true;
}

fn russia_moex(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    // QuantLib throws before 2012. There is no holiday rule to apply.
    if y < 2012 { return true; }
    if on_list(RU_MOEX_OPEN, y, m, day) { return true; }
    if weekend(w) { return false; }
    if day == 23 && m == 2 { return false; }
    if moved_monday(day, w, 8) && m == 3 { return false; }
    if day == 1 && m == 5 { return false; }
    if moved_monday(day, w, 9) && m == 5 { return false; }
    if day == 12 && m == 6 { return false; }
    if moved_monday(day, w, 4) && m == 11 { return false; }
    if day == 31 && m == 12 { return false; }
    if on_list(RU_MOEX_EXTRA, y, m, day) { return false; }
    return true;
}

fn slovakia_bsse(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 6 && m == 1 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 8 && m == 5 { return false; }
    if day == 5 && m == 7 { return false; }
    if day == 29 && m == 8 { return false; }
    if day == 1 && m == 9 { return false; }
    if day == 15 && m == 9 { return false; }
    if day == 1 && m == 11 { return false; }
    if day == 17 && m == 11 { return false; }
    if day == 24 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    if day >= 24 && day <= 31 && m == 12 && y == 2004 { return false; }
    if day >= 24 && day <= 31 && m == 12 && y == 2005 { return false; }
    return true;
}

fn slovenia_lse(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 2 && m == 1 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 2 && m == 5 { return false; }
    if day == 25 && m == 6 { return false; }
    if day == 15 && m == 8 { return false; }
    if day == 31 && m == 10 { return false; }
    if day == 24 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    if day == 31 && m == 12 { return false; }
    return true;
}

fn ukraine_use(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::orthodox(y);
    if weekend(w) { return false; }
    if (day == 1 || ((day == 2 || day == 3) && w == date::MONDAY)) && m == 1 { return false; }
    if moved_monday(day, w, 7) && m == 1 { return false; }
    if moved_monday(day, w, 8) && m == 3 { return false; }
    if doy == em { return false; }
    if doy == em + 49 { return false; }
    if (day == 1 || day == 2 || (day == 3 && w == date::MONDAY)) && m == 5 { return false; }
    if moved_monday(day, w, 9) && m == 5 { return false; }
    if day == 28 && m == 6 { return false; }
    if day == 24 && m == 8 { return false; }
    if day == 14 && m == 10 && y >= 2015 { return false; }
    return true;
}

fn croatia_zse(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 6 && m == 1 { return false; }
    if doy == em - 3 && y >= 2016 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 30 && m == 5 { return false; }
    if doy == em + 59 { return false; }
    if day == 22 && m == 6 { return false; }
    if day == 5 && m == 8 { return false; }
    if day == 15 && m == 8 { return false; }
    if day == 18 && m == 11 { return false; }
    if day == 24 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    if day == 31 && m == 12 { return false; }
    return true;
}

fn feb_both_weekend(y: i32) -> bool {
    let a, aok = date::from_ymd(15, 2, y);
    let b, bok = date::from_ymd(16, 2, y);
    if !aok || !bok { return false; }
    return weekend(date::weekday(a)) && weekend(date::weekday(b));
}

fn serbia_bse(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if weekend(w) { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 2 && m == 1 { return false; }
    if day == 7 && m == 1 { return false; }
    if day == 15 && m == 2 { return false; }
    if day == 16 && m == 2 { return false; }
    if day == 17 && m == 2 && feb_both_weekend(y) { return false; }
    if doy == em - 3 && y >= 2016 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 11 && m == 11 { return false; }
    if day == 31 && m == 12 { return false; }
    return true;
}

fn montenegro_mnse(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    if weekend(w) { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 2 && m == 1 { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 2 && m == 5 { return false; }
    if day == 21 && m == 5 { return false; }
    if day == 22 && m == 5 { return false; }
    if day == 13 && m == 7 { return false; }
    if day == 14 && m == 7 { return false; }
    if day == 13 && m == 11 { return false; }
    if day == 14 && m == 11 { return false; }
    return true;
}

fn north_macedonia_mse(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::orthodox(y);
    if weekend(w) { return false; }
    if on_list(NM_FITR, y, m, day) { return false; }
    if on_list(NM_ADHA, y, m, day) { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 7 && m == 1 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 24 && m == 5 { return false; }
    if day == 2 && m == 8 { return false; }
    if day == 8 && m == 9 { return false; }
    if day == 11 && m == 10 { return false; }
    if day == 23 && m == 10 { return false; }
    if day == 8 && m == 12 { return false; }
    return true;
}

fn malta_mse(d: date::Date) -> bool {
    let w = date::weekday(d);
    let day = date::day_of_month(d);
    let m = date::month(d);
    let y = date::year(d);
    let doy = date::day_of_year(d);
    let em = easter::western(y);
    if w == date::FRIDAY || w == date::SATURDAY { return false; }
    if day == 1 && m == 1 { return false; }
    if day == 10 && m == 2 { return false; }
    if day == 19 && m == 3 { return false; }
    if day == 31 && m == 3 { return false; }
    if doy == em - 3 { return false; }
    if doy == em { return false; }
    if day == 1 && m == 5 { return false; }
    if day == 29 && m == 6 { return false; }
    if day == 15 && m == 8 { return false; }
    if day == 8 && m == 9 { return false; }
    if day == 21 && m == 9 { return false; }
    if day == 8 && m == 12 { return false; }
    if day == 13 && m == 12 { return false; }
    if day == 24 && m == 12 { return false; }
    if day == 25 && m == 12 { return false; }
    if day == 26 && m == 12 { return false; }
    if day == 31 && m == 12 { return false; }
    return true;
}
