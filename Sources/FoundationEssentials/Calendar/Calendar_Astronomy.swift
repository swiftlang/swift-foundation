//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(os)
internal import os
#elseif canImport(Bionic)
@preconcurrency import Bionic
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(CRT)
import CRT
#elseif os(WASI)
@preconcurrency import WASILibc
#endif

/// Shared astronomical and Gregorian day-number toolkit for the non-arithmetic calendars (Chinese today; Islamic and Hindu variants can build on it). Solar/lunar theory follows Reingold & Dershowitz, Calendrical Calculations (built on the Meeus and Bretagnon & Simon series); all APIs are calendar-agnostic.
internal enum _CalendarAstronomy {
    static let meanSynodicMonth = 29.530588861
    static let j2000 = 730120.5
    static let newMoonZero = 11.458922815770109

    static func polynomial<let count: Int>(_ x: Double, _ coefficients: InlineArray<count, Double>) -> Double {
        var result = 0.0
        var power = 1.0
        for i in 0..<count {
            result += coefficients[i] * power
            power *= x
        }
        return result
    }

    static func mod360(_ x: Double) -> Double {
        var r = x.truncatingRemainder(dividingBy: 360.0)
        if r < 0 { r += 360.0 }
        return r
    }

    static func sinDegrees(_ d: Double) -> Double { sin(d * .pi / 180.0) }
    static func cosDegrees(_ d: Double) -> Double { cos(d * .pi / 180.0) }

    // Proleptic Gregorian y/m/d -> Rata Die (day 1 = 0001-01-01).
    static func gregorianRataDie(_ y: Int, _ m: Int, _ d: Int) -> Int {
        func floorDivide(_ a: Int, _ b: Int) -> Int { a >= 0 ? a / b : -((-a + b - 1) / b) }
        let ym1 = y - 1
        let leap = (floorDivide(y, 4) * 4 == y && floorDivide(y, 100) * 100 != y) || floorDivide(y, 400) * 400 == y
        var r = 365 * ym1 + floorDivide(ym1, 4) - floorDivide(ym1, 100) + floorDivide(ym1, 400)
        r += floorDivide(367 * m - 362, 12) + (m <= 2 ? 0 : (leap ? -1 : -2)) + d
        return r
    }

    static func gregorianYear(ofRataDie day: Int) -> Int {
        var y = Int((Double(day) / 365.2425).rounded(.down)) + 1
        while gregorianRataDie(y, 1, 1) > day { y -= 1 }
        while gregorianRataDie(y + 1, 1, 1) <= day { y += 1 }
        return y
    }

    // Delta-T (dynamical minus universal time) as a fraction of a day. Espenak & Meeus polynomial expressions, published by NASA Goddard.
    static func ephemerisCorrection(_ moment: Double) -> Double {
        let year = moment / 365.2425
        let yearInt = Int(year > 0 ? year + 1 : year)
        let fixedMidYear = gregorianRataDie(yearInt, 7, 1)
        let c = (Double(fixedMidYear) - 693596.0) / 36525.0
        let y2000 = Double(yearInt - 2000)
        let y1700 = Double(yearInt - 1700)
        let y1600 = Double(yearInt - 1600)
        let y1000 = Double(yearInt - 1000) / 100.0
        let y0 = Double(yearInt) / 100.0
        let y1820 = Double(yearInt - 1820) / 100.0

        switch yearInt {
        case 2051...2150:
            return (-20.0 + 32.0 * Double((yearInt - 1820) * (yearInt - 1820)) / 10000.0
                    + 0.5628 * Double(2150 - yearInt)) / 86400.0
        case 2006...2050:
            return (62.92 + 0.32217 * y2000 + 0.005589 * y2000 * y2000) / 86400.0
        case 1987...2005:
            return polynomial(y2000, [63.86, 0.3345, -0.060374, 0.0017275,
                                0.000651814, 0.00002373599]) / 86400.0
        case 1900...1986:
            return polynomial(c, [-0.00002, 0.000297, 0.025184, -0.181133,
                            0.553040, -0.861938, 0.677066, -0.212591])
        case 1800...1899:
            return polynomial(c, [-0.000009, 0.003844, 0.083563, 0.865736,
                            4.867575, 15.845535, 31.332267, 38.291999,
                            28.316289, 11.636204, 2.043794])
        case 1700...1799:
            return polynomial(y1700, [8.118780842, -0.005092142, 0.003336121,
                                -0.0000266484]) / 86400.0
        case 1600...1699:
            return polynomial(y1600, [120.0, -0.9808, -0.01532, 0.000140272128]) / 86400.0
        case 500...1599:
            return polynomial(y1000, [1574.2, -556.01, 71.23472, 0.319781,
                                -0.8503463, -0.005050998, 0.0083572073]) / 86400.0
        case -499...499:
            return polynomial(y0, [10583.6, -1014.41, 33.78311, -5.952053,
                             -0.1798452, 0.022174192, 0.0090316521]) / 86400.0
        default:
            return (-20.0 + 32.0 * y1820 * y1820) / 86400.0
        }
    }

    static func universalFromDynamical(_ dynamical: Double) -> Double {
        dynamical - ephemerisCorrection(dynamical)
    }

    static func julianCenturies(_ moment: Double) -> Double {
        (moment + ephemerisCorrection(moment) - j2000) / 36525.0
    }

    static func nutation(_ c: Double) -> Double {
        let a = 124.90 - 1934.134 * c + 0.002063 * c * c
        let b = 201.11 + 72001.5377 * c + 0.00057 * c * c
        return -0.004778 * sinDegrees(a) - 0.0003667 * sinDegrees(b)
    }

    static func aberration(_ c: Double) -> Double {
        0.0000974 * cosDegrees(177.63 + 35999.01848 * c) - 0.005575
    }

    private static let solarTerms: InlineArray<49, (coefficient: Double, addend: Double, multiplier: Double)> = [
        (403406, 270.54861, 0.9287892),
        (195207, 340.19128, 35999.1376958),
        (119433, 63.91854, 35999.4089666),
        (112392, 331.26220, 35998.7287385),
        (3891, 317.843, 71998.20261),
        (2819, 86.631, 71998.4403),
        (1721, 240.052, 36000.35726),
        (660, 310.26, 71997.4812),
        (350, 247.23, 32964.4678),
        (334, 260.87, -19.4410),
        (314, 297.82, 445267.1117),
        (268, 343.14, 45036.8840),
        (242, 166.79, 3.1008),
        (234, 81.53, 22518.4434),
        (158, 3.50, -19.9739),
        (132, 132.75, 65928.9345),
        (129, 182.95, 9038.0293),
        (114, 162.03, 3034.7684),
        (99, 29.8, 33718.148),
        (93, 266.4, 3034.448),
        (86, 249.2, -2280.773),
        (78, 157.6, 29929.992),
        (72, 257.8, 31556.493),
        (68, 185.1, 149.588),
        (64, 69.9, 9037.750),
        (46, 8.0, 107997.405),
        (38, 197.1, -4444.176),
        (37, 250.4, 151.771),
        (32, 65.3, 67555.316),
        (29, 162.7, 31556.080),
        (28, 341.5, -4561.540),
        (27, 291.6, 107996.706),
        (27, 98.5, 1221.655),
        (25, 146.7, 62894.167),
        (24, 110.0, 31437.369),
        (21, 5.2, 14578.298),
        (21, 342.6, -31931.757),
        (20, 230.9, 34777.243),
        (18, 256.1, 1221.999),
        (17, 45.3, 62894.511),
        (14, 242.9, -4442.039),
        (13, 115.2, 107997.909),
        (13, 151.8, 119.066),
        (13, 285.3, 16859.071),
        (12, 53.3, -4.578),
        (10, 126.6, 26895.292),
        (10, 205.7, -39.127),
        (10, 85.9, 12297.536),
        (10, 146.1, 90073.778),
    ]

    // Solar longitude in degrees [0, 360), 49-term Bretagnon & Simon series.
    static func solarLongitude(at moment: Double) -> Double {
        let c = julianCenturies(moment)
        var lambda = 0.0
        for i in 0..<49 {
            let term = solarTerms[i]
            lambda += term.coefficient * sinDegrees(term.addend + term.multiplier * c)
        }
        lambda *= 0.000005729577951308232
        lambda += 282.7771834 + 36000.76953744 * c
        return mod360(lambda + aberration(c) + nutation(c))
    }


    private static let newMoonTerms: InlineArray<24, (sine: Double, solar: Double, lunar: Double, argument: Double)> = [
        (sine: -0.40720, solar: 0, lunar: 1, argument: 0),
        (sine: 0.17241, solar: 1, lunar: 0, argument: 0),
        (sine: 0.01608, solar: 0, lunar: 2, argument: 0),
        (sine: 0.01039, solar: 0, lunar: 0, argument: 2),
        (sine: 0.00739, solar: -1, lunar: 1, argument: 0),
        (sine: -0.00514, solar: 1, lunar: 1, argument: 0),
        (sine: 0.00208, solar: 2, lunar: 0, argument: 0),
        (sine: -0.00111, solar: 0, lunar: 1, argument: -2),
        (sine: -0.00057, solar: 0, lunar: 1, argument: 2),
        (sine: 0.00056, solar: 1, lunar: 2, argument: 0),
        (sine: -0.00042, solar: 0, lunar: 3, argument: 0),
        (sine: 0.00042, solar: 1, lunar: 0, argument: 2),
        (sine: 0.00038, solar: 1, lunar: 0, argument: -2),
        (sine: -0.00024, solar: -1, lunar: 2, argument: 0),
        (sine: -0.00007, solar: 2, lunar: 1, argument: 0),
        (sine: 0.00004, solar: 0, lunar: 2, argument: -2),
        (sine: 0.00004, solar: 3, lunar: 0, argument: 0),
        (sine: 0.00003, solar: 1, lunar: 1, argument: -2),
        (sine: 0.00003, solar: 0, lunar: 2, argument: 2),
        (sine: -0.00003, solar: 1, lunar: 1, argument: 2),
        (sine: 0.00003, solar: -1, lunar: 1, argument: 2),
        (sine: -0.00002, solar: -1, lunar: 1, argument: -2),
        (sine: -0.00002, solar: 1, lunar: 3, argument: 0),
        (sine: 0.00002, solar: 0, lunar: 4, argument: 0),
    ]

    private static let newMoonExtraTerms: InlineArray<13, (addend: Double, multiplier: Double, coefficient: Double)> = [
        (addend: 251.88, multiplier: 0.016321, coefficient: 0.000165),
        (addend: 251.83, multiplier: 26.651886, coefficient: 0.000164),
        (addend: 349.42, multiplier: 36.412478, coefficient: 0.000126),
        (addend: 84.66, multiplier: 18.206239, coefficient: 0.000110),
        (addend: 141.74, multiplier: 53.303771, coefficient: 0.000062),
        (addend: 207.14, multiplier: 2.453732, coefficient: 0.000060),
        (addend: 154.84, multiplier: 7.306860, coefficient: 0.000056),
        (addend: 34.52, multiplier: 27.261239, coefficient: 0.000047),
        (addend: 207.19, multiplier: 0.121824, coefficient: 0.000042),
        (addend: 291.34, multiplier: 1.844379, coefficient: 0.000040),
        (addend: 161.72, multiplier: 24.198154, coefficient: 0.000037),
        (addend: 239.56, multiplier: 25.513099, coefficient: 0.000035),
        (addend: 331.55, multiplier: 3.592518, coefficient: 0.000023),
    ]

    // Moment of the nth new moon since the 24724-indexed epoch; Meeus 24+13 terms.
    static func nthNewMoon(_ n: Int) -> Double {
        let k = Double(n) - 24724.0
        let c = k / 1236.85
        let approx = j2000
            + (5.09766 + meanSynodicMonth * 1236.85 * c
               + 0.00015437 * c * c
               - 0.00000015 * c * c * c
               + 0.00000000073 * c * c * c * c)
        let e = 1.0 - 0.002516 * c - 0.0000074 * c * c
        let solarAnomaly = 2.5534 + 1236.85 * 29.10535670 * c
            - 0.0000014 * c * c - 0.00000011 * c * c * c
        let lunarAnomaly = 201.5643 + 385.81693528 * 1236.85 * c
            + 0.0107582 * c * c + 0.00001238 * c * c * c
            - 0.000000058 * c * c * c * c
        let moonArgument = 160.7108 + 390.67050284 * 1236.85 * c
            - 0.0016118 * c * c - 0.00000227 * c * c * c
            + 0.000000011 * c * c * c * c
        let omega = 124.7746 + (-1.56375588) * 1236.85 * c
            + 0.0020672 * c * c + 0.00000215 * c * c * c

        var correction = -0.00017 * sinDegrees(omega)
        for i in 0..<24 {
            let term = newMoonTerms[i]
            let ePow = pow(e, abs(term.solar))
            let arg = term.solar * solarAnomaly + term.lunar * lunarAnomaly + term.argument * moonArgument
            correction += term.sine * ePow * sinDegrees(arg)
        }
        let extra = 0.000325 * sinDegrees(299.77 + 132.8475848 * c - 0.009173 * c * c)
        var additional = 0.0
        for i in 0..<13 {
            let term = newMoonExtraTerms[i]
            additional += term.coefficient * sinDegrees(term.addend + term.multiplier * k)
        }
        return universalFromDynamical(approx + correction + extra + additional)
    }

    static func numberOfNewMoonAtOrAfter(_ moment: Double) -> Int {
        let rawN = ((moment - newMoonZero) / meanSynodicMonth).rounded()
        var n = Int(rawN)
        while nthNewMoon(n) < moment { n += 1 }
        while nthNewMoon(n - 1) >= moment { n -= 1 }
        return n
    }

    static func newMoonAtOrAfter(_ moment: Double) -> Double {
        nthNewMoon(numberOfNewMoonAtOrAfter(moment))
    }

    static func newMoonBefore(_ moment: Double) -> Double {
        nthNewMoon(numberOfNewMoonAtOrAfter(moment) - 1)
    }
}

