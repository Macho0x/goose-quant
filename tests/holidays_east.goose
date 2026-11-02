import os;
import quant from "..";
import quant.date;
import quant.markets_east;

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
    let key: i32 = y * 10000 + m * 100 + day;
    var i: i64 = 0;
    while i < hol.len {
        if hol[i] == key { return true; }
        i += 1;
    }
    return false;
}

fn closed_weekend(kind: i32, w: i32) -> bool {
    if kind == markets_east::MALTA_MSE {
        return w == date::FRIDAY || w == date::SATURDAY;
    }
    return w == date::SATURDAY || w == date::SUNDAY;
}

fn check_span(kind: i32, from: date::Date, to: date::Date, hol: i32[:], weekends: bool, extra: u8[:], missed: u8[:]) {
    var serial = from.serial;
    while serial <= to.serial {
        let t, ok = date::from_serial(serial);
        if !ok { fail("serial"); }
        let w = date::weekday(t);
        let weekend = closed_weekend(kind, w);
        let biz = markets_east::is_business_day(kind, t);
        let day = date::day_of_month(t);
        let m = date::month(t);
        let y = date::year(t);
        let listed = in_hol(hol, day, m, y);
        if listed && biz { fail_ymd(missed, day, m, y); }
        if !biz && !listed && (weekends || !weekend) { fail_ymd(extra, day, m, y); }
        if !weekends && weekend && biz { fail_ymd(extra, day, m, y); }
        serial += 1;
    }
}

fn holiday(kind: i32, day: i32, m: i32, y: i32, msg: u8[:]) {
    if markets_east::is_business_day(kind, ymd(day, m, y)) { fail_ymd(msg, day, m, y); }
}

fn open(kind: i32, day: i32, m: i32, y: i32, msg: u8[:]) {
    if !markets_east::is_business_day(kind, ymd(day, m, y)) { fail_ymd(msg, day, m, y); }
}

const MOEX_HOL: i32[569] = [
    20120101, 20120102, 20120107, 20120108, 20120114, 20120115, 20120121, 20120122,
    20120128, 20120129, 20120204, 20120205, 20120211, 20120212, 20120218, 20120219,
    20120223, 20120225, 20120226, 20120303, 20120304, 20120308, 20120309, 20120310,
    20120317, 20120318, 20120324, 20120325, 20120331, 20120401, 20120407, 20120408,
    20120414, 20120415, 20120421, 20120422, 20120429, 20120430, 20120501, 20120506,
    20120509, 20120513, 20120519, 20120520, 20120526, 20120527, 20120602, 20120603,
    20120610, 20120611, 20120612, 20120616, 20120617, 20120623, 20120624, 20120630,
    20120701, 20120707, 20120708, 20120714, 20120715, 20120721, 20120722, 20120728,
    20120729, 20120804, 20120805, 20120811, 20120812, 20120818, 20120819, 20120825,
    20120826, 20120901, 20120902, 20120908, 20120909, 20120915, 20120916, 20120922,
    20120923, 20120929, 20120930, 20121006, 20121007, 20121013, 20121014, 20121020,
    20121021, 20121027, 20121028, 20121103, 20121104, 20121105, 20121110, 20121111,
    20121117, 20121118, 20121124, 20121125, 20121201, 20121202, 20121208, 20121209,
    20121215, 20121216, 20121222, 20121223, 20121229, 20121230, 20121231, 20130101,
    20130102, 20130103, 20130104, 20130105, 20130106, 20130107, 20130112, 20130113,
    20130119, 20130120, 20130126, 20130127, 20130202, 20130203, 20130209, 20130210,
    20130216, 20130217, 20130223, 20130224, 20130302, 20130303, 20130308, 20130309,
    20130310, 20130316, 20130317, 20130323, 20130324, 20130330, 20130331, 20130406,
    20130407, 20130413, 20130414, 20130420, 20130421, 20130427, 20130428, 20130501,
    20130504, 20130505, 20130509, 20130511, 20130512, 20130518, 20130519, 20130525,
    20130526, 20130601, 20130602, 20130608, 20130609, 20130612, 20130615, 20130616,
    20130622, 20130623, 20130629, 20130630, 20130706, 20130707, 20130713, 20130714,
    20130720, 20130721, 20130727, 20130728, 20130803, 20130804, 20130810, 20130811,
    20130817, 20130818, 20130824, 20130825, 20130831, 20130901, 20130907, 20130908,
    20130914, 20130915, 20130921, 20130922, 20130928, 20130929, 20131005, 20131006,
    20131012, 20131013, 20131019, 20131020, 20131026, 20131027, 20131102, 20131103,
    20131104, 20131109, 20131110, 20131116, 20131117, 20131123, 20131124, 20131130,
    20131201, 20131207, 20131208, 20131214, 20131215, 20131221, 20131222, 20131228,
    20131229, 20131231, 20140101, 20140102, 20140103, 20140104, 20140105, 20140107,
    20140111, 20140112, 20140118, 20140119, 20140125, 20140126, 20140201, 20140202,
    20140208, 20140209, 20140215, 20140216, 20140222, 20140223, 20140301, 20140302,
    20140308, 20140309, 20140310, 20140315, 20140316, 20140322, 20140323, 20140329,
    20140330, 20140405, 20140406, 20140412, 20140413, 20140419, 20140420, 20140426,
    20140427, 20140501, 20140503, 20140504, 20140509, 20140510, 20140511, 20140517,
    20140518, 20140524, 20140525, 20140531, 20140601, 20140607, 20140608, 20140612,
    20140614, 20140615, 20140621, 20140622, 20140628, 20140629, 20140705, 20140706,
    20140712, 20140713, 20140719, 20140720, 20140726, 20140727, 20140802, 20140803,
    20140809, 20140810, 20140816, 20140817, 20140823, 20140824, 20140830, 20140831,
    20140906, 20140907, 20140913, 20140914, 20140920, 20140921, 20140927, 20140928,
    20141004, 20141005, 20141011, 20141012, 20141018, 20141019, 20141025, 20141026,
    20141101, 20141102, 20141104, 20141108, 20141109, 20141115, 20141116, 20141122,
    20141123, 20141129, 20141130, 20141206, 20141207, 20141213, 20141214, 20141220,
    20141221, 20141227, 20141228, 20141231, 20150101, 20150102, 20150103, 20150104,
    20150107, 20150110, 20150111, 20150117, 20150118, 20150124, 20150125, 20150131,
    20150201, 20150207, 20150208, 20150214, 20150215, 20150221, 20150222, 20150223,
    20150228, 20150301, 20150307, 20150308, 20150309, 20150314, 20150315, 20150321,
    20150322, 20150328, 20150329, 20150404, 20150405, 20150411, 20150412, 20150418,
    20150419, 20150425, 20150426, 20150501, 20150502, 20150503, 20150509, 20150510,
    20150511, 20150516, 20150517, 20150523, 20150524, 20150530, 20150531, 20150606,
    20150607, 20150612, 20150613, 20150614, 20150620, 20150621, 20150627, 20150628,
    20150704, 20150705, 20150711, 20150712, 20150718, 20150719, 20150725, 20150726,
    20150801, 20150802, 20150808, 20150809, 20150815, 20150816, 20150822, 20150823,
    20150829, 20150830, 20150905, 20150906, 20150912, 20150913, 20150919, 20150920,
    20150926, 20150927, 20151003, 20151004, 20151010, 20151011, 20151017, 20151018,
    20151024, 20151025, 20151031, 20151101, 20151104, 20151107, 20151108, 20151114,
    20151115, 20151121, 20151122, 20151128, 20151129, 20151205, 20151206, 20151212,
    20151213, 20151219, 20151220, 20151226, 20151227, 20151231, 20160101, 20160102,
    20160103, 20160107, 20160108, 20160109, 20160110, 20160116, 20160117, 20160123,
    20160124, 20160130, 20160131, 20160206, 20160207, 20160213, 20160214, 20160221,
    20160223, 20160227, 20160228, 20160305, 20160306, 20160308, 20160312, 20160313,
    20160319, 20160320, 20160326, 20160327, 20160402, 20160403, 20160409, 20160410,
    20160416, 20160417, 20160423, 20160424, 20160430, 20160501, 20160502, 20160503,
    20160507, 20160508, 20160509, 20160514, 20160515, 20160521, 20160522, 20160528,
    20160529, 20160604, 20160605, 20160611, 20160612, 20160613, 20160618, 20160619,
    20160625, 20160626, 20160702, 20160703, 20160709, 20160710, 20160716, 20160717,
    20160723, 20160724, 20160730, 20160731, 20160806, 20160807, 20160813, 20160814,
    20160820, 20160821, 20160827, 20160828, 20160903, 20160904, 20160910, 20160911,
    20160917, 20160918, 20160924, 20160925, 20161001, 20161002, 20161008, 20161009,
    20161015, 20161016, 20161022, 20161023, 20161029, 20161030, 20161104, 20161105,
    20161106, 20161112, 20161113, 20161119, 20161120, 20161126, 20161127, 20161203,
    20161204, 20161210, 20161211, 20161217, 20161218, 20161224, 20161225, 20161230,
    20161231,
];

const MALTA_HOL: i32[22] = [
    20260101, 20260210, 20260319, 20260331, 20260406, 20260629, 20260908, 20260921,
    20261208, 20261213, 20261224, 20261231, 20270210, 20270329, 20270331, 20270629,
    20270815, 20270908, 20270921, 20271208, 20271213, 20271226,
];

const MONTENEGRO_HOL: i32[12] = [
    20260101, 20260102, 20260501, 20260521, 20260522, 20260713, 20260714, 20261113,
    20270101, 20270521, 20270713, 20270714,
];

const MACEDONIA_HOL: i32[19] = [
    20260101, 20260107, 20260320, 20260413, 20260501, 20260527, 20260908, 20261023,
    20261208, 20270101, 20270107, 20270310, 20270503, 20270517, 20270524, 20270802,
    20270908, 20271011, 20271208,
];

const SERBIA_HOL: i32[17] = [
    20260101, 20260102, 20260107, 20260216, 20260403, 20260406, 20260501, 20261111,
    20261231, 20270101, 20270107, 20270215, 20270216, 20270326, 20270329, 20271111,
    20271231,
];

const SLOVENIA_HOL: i32[15] = [
    20260101, 20260102, 20260403, 20260406, 20260501, 20260625, 20261224, 20261225,
    20261231, 20270101, 20270326, 20270329, 20270625, 20271224, 20271231,
];

const CROATIA_HOL: i32[22] = [
    20260101, 20260106, 20260403, 20260406, 20260501, 20260604, 20260622, 20260805,
    20261118, 20261224, 20261225, 20261231, 20270101, 20270106, 20270326, 20270329,
    20270527, 20270622, 20270805, 20271118, 20271224, 20271231,
];


fn ::main() {
    if markets_east::known(69) || markets_east::known(86) { fail("known other"); }
    if !markets_east::known(markets_east::CZECH_PSE) { fail("known czech"); }
    if !markets_east::known(markets_east::HUNGARY) { fail("known hungary"); }
    if !markets_east::known(markets_east::POLAND_SETTLEMENT) { fail("known poland"); }
    if !markets_east::known(markets_east::POLAND_WSE) { fail("known poland wse"); }
    if !markets_east::known(markets_east::ROMANIA_PUBLIC) { fail("known romania"); }
    if !markets_east::known(markets_east::ROMANIA_BVB) { fail("known bvb"); }
    if !markets_east::known(markets_east::RUSSIA_SETTLEMENT) { fail("known russia"); }
    if !markets_east::known(markets_east::RUSSIA_MOEX) { fail("known moex"); }
    if !markets_east::known(markets_east::SLOVAKIA_BSSE) { fail("known slovakia"); }
    if !markets_east::known(markets_east::SLOVENIA_LSE) { fail("known slovenia"); }
    if !markets_east::known(markets_east::UKRAINE_USE) { fail("known ukraine"); }
    if !markets_east::known(markets_east::CROATIA_ZSE) { fail("known croatia"); }
    if !markets_east::known(markets_east::SERBIA_BSE) { fail("known serbia"); }
    if !markets_east::known(markets_east::MONTENEGRO_MNSE) { fail("known montenegro"); }
    if !markets_east::known(markets_east::NORTH_MACEDONIA_MSE) { fail("known macedonia"); }
    if !markets_east::known(markets_east::MALTA_MSE) { fail("known malta"); }
    let sat = ymd(6, 1, 2024);
    if date::weekday(sat) != date::SATURDAY { fail("sat"); }
    if !markets_east::is_business_day(69, sat) { fail("unknown day"); }
    if !markets_east::is_business_day(69, ymd(4, 1, 2024)) { fail("unknown day"); }

    check_span(markets_east::RUSSIA_MOEX, ymd(1, 1, 2012), ymd(31, 12, 2016), MOEX_HOL, true, "extra moex", "missed moex");
    holiday(markets_east::RUSSIA_SETTLEMENT, 6, 1, 2012, "russia settlement");
    open(markets_east::RUSSIA_MOEX, 6, 1, 2012, "russia moex");

    holiday(markets_east::CZECH_PSE, 28, 10, 2024, "czech");
    open(markets_east::CZECH_PSE, 29, 10, 2024, "czech");
    holiday(markets_east::HUNGARY, 15, 3, 2024, "hungary");
    open(markets_east::HUNGARY, 14, 3, 2024, "hungary");
    holiday(markets_east::POLAND_SETTLEMENT, 6, 1, 2025, "poland settlement");
    holiday(markets_east::POLAND_WSE, 6, 1, 2025, "poland wse");
    open(markets_east::POLAND_SETTLEMENT, 7, 1, 2025, "poland settlement");
    open(markets_east::POLAND_WSE, 7, 1, 2025, "poland wse");
    holiday(markets_east::SLOVAKIA_BSSE, 1, 9, 2025, "slovakia");
    open(markets_east::SLOVAKIA_BSSE, 2, 9, 2025, "slovakia");
    holiday(markets_east::UKRAINE_USE, 14, 10, 2024, "ukraine");
    open(markets_east::UKRAINE_USE, 15, 10, 2024, "ukraine");

    holiday(markets_east::ROMANIA_PUBLIC, 1, 1, 2024, "romania");
    holiday(markets_east::ROMANIA_PUBLIC, 24, 1, 2024, "romania");
    holiday(markets_east::ROMANIA_PUBLIC, 1, 5, 2024, "romania");
    holiday(markets_east::ROMANIA_PUBLIC, 1, 6, 2024, "romania");
    holiday(markets_east::ROMANIA_PUBLIC, 6, 4, 2018, "romania");
    holiday(markets_east::ROMANIA_PUBLIC, 6, 1, 2025, "romania");
    holiday(markets_east::ROMANIA_PUBLIC, 7, 1, 2025, "romania");
    open(markets_east::ROMANIA_PUBLIC, 14, 4, 2017, "romania");
    open(markets_east::ROMANIA_PUBLIC, 6, 1, 2023, "romania");
    holiday(markets_east::ROMANIA_BVB, 1, 1, 2014, "bvb");
    holiday(markets_east::ROMANIA_BVB, 18, 4, 2025, "bvb");
    holiday(markets_east::ROMANIA_BVB, 6, 1, 2026, "bvb");
    holiday(markets_east::ROMANIA_BVB, 7, 1, 2026, "bvb");
    holiday(markets_east::ROMANIA_BVB, 10, 4, 2026, "bvb");
    open(markets_east::ROMANIA_BVB, 3, 1, 2024, "bvb");

    check_span(markets_east::MALTA_MSE, ymd(1, 1, 2026), ymd(31, 12, 2027), MALTA_HOL, false, "extra malta", "missed malta");
    check_span(markets_east::MONTENEGRO_MNSE, ymd(1, 1, 2026), ymd(31, 12, 2027), MONTENEGRO_HOL, false, "extra montenegro", "missed montenegro");
    check_span(markets_east::NORTH_MACEDONIA_MSE, ymd(1, 1, 2026), ymd(31, 12, 2027), MACEDONIA_HOL, false, "extra macedonia", "missed macedonia");
    check_span(markets_east::SERBIA_BSE, ymd(1, 1, 2026), ymd(31, 12, 2027), SERBIA_HOL, false, "extra serbia", "missed serbia");
    check_span(markets_east::SLOVENIA_LSE, ymd(1, 1, 2026), ymd(31, 12, 2027), SLOVENIA_HOL, false, "extra slovenia", "missed slovenia");
    check_span(markets_east::CROATIA_ZSE, ymd(1, 1, 2026), ymd(31, 12, 2027), CROATIA_HOL, false, "extra croatia", "missed croatia");

    holiday(markets_east::NORTH_MACEDONIA_MSE, 20, 3, 2026, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 10, 3, 2027, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 27, 2, 2028, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 15, 2, 2029, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 5, 2, 2030, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 25, 1, 2031, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 14, 1, 2032, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 2, 1, 2033, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 23, 12, 2033, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 12, 12, 2034, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 1, 12, 2035, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 19, 11, 2036, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 8, 11, 2037, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 29, 10, 2038, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 19, 10, 2039, "ramazan");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 7, 10, 2040, "ramazan");

    holiday(markets_east::NORTH_MACEDONIA_MSE, 27, 5, 2026, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 17, 5, 2027, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 5, 5, 2028, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 24, 4, 2029, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 13, 4, 2030, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 3, 4, 2031, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 22, 3, 2032, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 11, 3, 2033, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 28, 2, 2034, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 18, 2, 2035, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 7, 2, 2036, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 27, 1, 2037, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 16, 1, 2038, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 5, 1, 2039, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 26, 12, 2039, "kurban");
    holiday(markets_east::NORTH_MACEDONIA_MSE, 15, 12, 2040, "kurban");

    holiday(markets_east::SERBIA_BSE, 17, 2, 2025, "serbia bridge");
    open(markets_east::SERBIA_BSE, 18, 2, 2025, "serbia bridge");
    open(markets_east::SERBIA_BSE, 17, 2, 2026, "serbia bridge");

    write_stdout("east ok\n");
}
