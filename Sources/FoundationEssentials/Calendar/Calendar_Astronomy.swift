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

    static func poly(_ x: Double, _ coefficients: [Double]) -> Double {
        var result = 0.0
        var power = 1.0
        for c in coefficients {
            result += c * power
            power *= x
        }
        return result
    }

    static func mod360(_ x: Double) -> Double {
        var r = x.truncatingRemainder(dividingBy: 360.0)
        if r < 0 { r += 360.0 }
        return r
    }

    static func sinDeg(_ d: Double) -> Double { sin(d * .pi / 180.0) }
    static func cosDeg(_ d: Double) -> Double { cos(d * .pi / 180.0) }

    // Proleptic Gregorian y/m/d -> Rata Die (day 1 = 0001-01-01).
    static func gregorianRD(_ y: Int, _ m: Int, _ d: Int) -> Int {
        func fd(_ a: Int, _ b: Int) -> Int { a >= 0 ? a / b : -((-a + b - 1) / b) }
        let ym1 = y - 1
        let leap = (fd(y, 4) * 4 == y && fd(y, 100) * 100 != y) || fd(y, 400) * 400 == y
        var r = 365 * ym1 + fd(ym1, 4) - fd(ym1, 100) + fd(ym1, 400)
        r += fd(367 * m - 362, 12) + (m <= 2 ? 0 : (leap ? -1 : -2)) + d
        return r
    }

    static func gregorianYear(ofRD day: Int) -> Int {
        var y = Int((Double(day) / 365.2425).rounded(.down)) + 1
        while gregorianRD(y, 1, 1) > day { y -= 1 }
        while gregorianRD(y + 1, 1, 1) <= day { y += 1 }
        return y
    }

    // Dynamical-minus-universal time (fraction of a day). Meeus/NASA fits.
    static func ephemerisCorrection(_ moment: Double) -> Double {
        let year = moment / 365.2425
        let yearInt = Int(year > 0 ? year + 1 : year)
        let fixedMidYear = gregorianRD(yearInt, 7, 1)
        let c = (Double(fixedMidYear) - 693596.0) / 36525.0
        let y2000 = Double(yearInt - 2000)
        let y1700 = Double(yearInt - 1700)
        let y1600 = Double(yearInt - 1600)
        let y1000 = Double(yearInt - 1000) / 100.0
        let y0 = Double(yearInt) / 100.0
        let y1820 = Double(yearInt - 1820) / 100.0

        if (2051...2150).contains(yearInt) {
            return (-20.0 + 32.0 * Double((yearInt - 1820) * (yearInt - 1820)) / 10000.0
                    + 0.5628 * Double(2150 - yearInt)) / 86400.0
        } else if (2006...2050).contains(yearInt) {
            return (62.92 + 0.32217 * y2000 + 0.005589 * y2000 * y2000) / 86400.0
        } else if (1987...2005).contains(yearInt) {
            return poly(y2000, [63.86, 0.3345, -0.060374, 0.0017275,
                                0.000651814, 0.00002373599]) / 86400.0
        } else if (1900...1986).contains(yearInt) {
            return poly(c, [-0.00002, 0.000297, 0.025184, -0.181133,
                            0.553040, -0.861938, 0.677066, -0.212591])
        } else if (1800...1899).contains(yearInt) {
            return poly(c, [-0.000009, 0.003844, 0.083563, 0.865736,
                            4.867575, 15.845535, 31.332267, 38.291999,
                            28.316289, 11.636204, 2.043794])
        } else if (1700...1799).contains(yearInt) {
            return poly(y1700, [8.118780842, -0.005092142, 0.003336121,
                                -0.0000266484]) / 86400.0
        } else if (1600...1699).contains(yearInt) {
            return poly(y1600, [120.0, -0.9808, -0.01532, 0.000140272128]) / 86400.0
        } else if (500...1599).contains(yearInt) {
            return poly(y1000, [1574.2, -556.01, 71.23472, 0.319781,
                                -0.8503463, -0.005050998, 0.0083572073]) / 86400.0
        } else if (-499...499).contains(yearInt) {
            return poly(y0, [10583.6, -1014.41, 33.78311, -5.952053,
                             -0.1798452, 0.022174192, 0.0090316521]) / 86400.0
        } else {
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
        return -0.004778 * sinDeg(a) - 0.0003667 * sinDeg(b)
    }

    static func aberration(_ c: Double) -> Double {
        0.0000974 * cosDeg(177.63 + 35999.01848 * c) - 0.005575
    }

    // Static so the hot lunation/solstice paths don't allocate arrays per call.
    private static let solarCoefficients: [Double] = [
        403406, 195207, 119433, 112392, 3891, 2819, 1721, 660, 350, 334,
        314, 268, 242, 234, 158, 132, 129, 114, 99, 93, 86, 78, 72,
        68, 64, 46, 38, 37, 32, 29, 28, 27, 27, 25, 24, 21, 21,
        20, 18, 17, 14, 13, 13, 13, 12, 10, 10, 10, 10,
    ]
    private static let solarAddends: [Double] = [
        270.54861, 340.19128, 63.91854, 331.26220, 317.843, 86.631, 240.052, 310.26, 247.23,
        260.87, 297.82, 343.14, 166.79, 81.53, 3.50, 132.75, 182.95, 162.03, 29.8, 266.4,
        249.2, 157.6, 257.8, 185.1, 69.9, 8.0, 197.1, 250.4, 65.3, 162.7, 341.5, 291.6, 98.5,
        146.7, 110.0, 5.2, 342.6, 230.9, 256.1, 45.3, 242.9, 115.2, 151.8, 285.3, 53.3, 126.6,
        205.7, 85.9, 146.1,
    ]
    private static let solarMultipliers: [Double] = [
        0.9287892, 35999.1376958, 35999.4089666, 35998.7287385, 71998.20261, 71998.4403,
        36000.35726, 71997.4812, 32964.4678, -19.4410, 445267.1117, 45036.8840, 3.1008,
        22518.4434, -19.9739, 65928.9345, 9038.0293, 3034.7684, 33718.148, 3034.448,
        -2280.773, 29929.992, 31556.493, 149.588, 9037.750, 107997.405, -4444.176, 151.771,
        67555.316, 31556.080, -4561.540, 107996.706, 1221.655, 62894.167, 31437.369,
        14578.298, -31931.757, 34777.243, 1221.999, 62894.511, -4442.039, 107997.909,
        119.066, 16859.071, -4.578, 26895.292, -39.127, 12297.536, 90073.778,
    ]

    // Solar longitude in degrees [0, 360), 49-term Bretagnon & Simon series.
    static func solarLongitude(at moment: Double) -> Double {
        let c = julianCenturies(moment)
        var lambda = 0.0
        for i in 0..<49 {
            lambda += solarCoefficients[i] * sinDeg(solarAddends[i] + solarMultipliers[i] * c)
        }
        lambda *= 0.000005729577951308232
        lambda += 282.7771834 + 36000.76953744 * c
        return mod360(lambda + aberration(c) + nutation(c))
    }


    private static let newMoonSineCoefficients: [Double] = [
        -0.40720, 0.17241, 0.01608, 0.01039, 0.00739, -0.00514, 0.00208, -0.00111, -0.00057,
        0.00056, -0.00042, 0.00042, 0.00038, -0.00024, -0.00007, 0.00004, 0.00004, 0.00003,
        0.00003, -0.00003, 0.00003, -0.00002, -0.00002, 0.00002,
    ]
    private static let newMoonSolarFactors: [Double] = [
        0, 1, 0, 0, -1, 1, 2, 0, 0, 1, 0, 1, 1, -1, 2, 0, 3, 1, 0, 1, -1, -1, 1, 0,
    ]
    private static let newMoonLunarFactors: [Double] = [
        1, 0, 2, 0, 1, 1, 0, 1, 1, 2, 3, 0, 0, 2, 1, 2, 0, 1, 2, 1, 1, 1, 3, 4,
    ]
    private static let newMoonArgumentFactors: [Double] = [
        0, 0, 0, 2, 0, 0, 0, -2, 2, 0, 0, 2, -2, 0, 0, -2, 0, -2, 2, 2, 2, -2, 0, 0,
    ]
    private static let newMoonExtraAddends: [Double] = [
        251.88, 251.83, 349.42, 84.66, 141.74, 207.14, 154.84, 34.52, 207.19, 291.34, 161.72, 239.56, 331.55,
    ]
    private static let newMoonExtraMultipliers: [Double] = [
        0.016321, 26.651886, 36.412478, 18.206239, 53.303771, 2.453732, 7.306860, 27.261239,
        0.121824, 1.844379, 24.198154, 25.513099, 3.592518,
    ]
    private static let newMoonExtraCoefficients: [Double] = [
        0.000165, 0.000164, 0.000126, 0.000110, 0.000062, 0.000060, 0.000056, 0.000047,
        0.000042, 0.000040, 0.000037, 0.000035, 0.000023,
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

        var correction = -0.00017 * sinDeg(omega)
        for i in 0..<24 {
            let ePow = pow(e, abs(newMoonSolarFactors[i]))
            let arg = newMoonSolarFactors[i] * solarAnomaly + newMoonLunarFactors[i] * lunarAnomaly
                + newMoonArgumentFactors[i] * moonArgument
            correction += newMoonSineCoefficients[i] * ePow * sinDeg(arg)
        }
        let extra = 0.000325 * sinDeg(299.77 + 132.8475848 * c - 0.009173 * c * c)
        var additional = 0.0
        for i in 0..<13 {
            additional += newMoonExtraCoefficients[i] * sinDeg(newMoonExtraAddends[i] + newMoonExtraMultipliers[i] * k)
        }
        return universalFromDynamical(approx + correction + extra + additional)
    }

    static func numOfNewMoonAtOrAfter(_ moment: Double) -> Int {
        let rawN = ((moment - newMoonZero) / meanSynodicMonth).rounded()
        var n = Int(rawN)
        while nthNewMoon(n) < moment { n += 1 }
        while nthNewMoon(n - 1) >= moment { n -= 1 }
        return n
    }

    static func newMoonAtOrAfter(_ moment: Double) -> Double {
        nthNewMoon(numOfNewMoonAtOrAfter(moment))
    }

    static func newMoonBefore(_ moment: Double) -> Double {
        nthNewMoon(numOfNewMoonAtOrAfter(moment) - 1)
    }
}

