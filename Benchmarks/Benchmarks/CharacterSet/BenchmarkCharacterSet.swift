//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
import FoundationInternationalization
#else
import Foundation
#endif

let benchmarks: @Sendable () -> Void = {
    #if FOUNDATION_FRAMEWORK
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .throughput, .peakMemoryResident]
    
    let string = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz234567"
    let range = UnicodeScalar(0x61)!..<UnicodeScalar(0x7B)!
    let data = CharacterSet.urlQueryAllowed
        .subtracting(CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[]"))
        .bitmapRepresentation

    // MARK: Initialize CharacterSet

    Benchmark("Init String") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet(charactersIn: string))
        }
    }

    Benchmark("Init Range") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet(charactersIn: range))
        }
    }

    Benchmark("Init Predefined") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet.whitespacesAndNewlines)
        }
    }

    Benchmark("Init Data") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet(bitmapRepresentation: data))
        }
    }

    // MARK: Get Bitmap Representation of CharacterSet

    let stringCs = CharacterSet(charactersIn: string)
    Benchmark("String BitmapRepresentation") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(stringCs.bitmapRepresentation)
        }
    }

    let rangeCs = CharacterSet(charactersIn: range)
    Benchmark("Range BitmapRepresentation") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(rangeCs.bitmapRepresentation)
        }
    }

    let predefinedCs = CharacterSet.whitespacesAndNewlines
    Benchmark("Predefined BitmapRepresentation") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(predefinedCs.bitmapRepresentation)
        }
    }

    let dataCs = CharacterSet(bitmapRepresentation: data)
    Benchmark("Data BitmapRepresentation") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(dataCs.bitmapRepresentation)
        }
    }
    
    // MARK: Check Membership
    let stringMembershipCS = CharacterSet(charactersIn: string)
    Benchmark("String Membership") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(stringMembershipCS.contains(UnicodeScalar("A")))
        }
    }

    let rangeMembershipCS = CharacterSet(charactersIn: range)
    Benchmark("Range Membership") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(rangeMembershipCS.contains(UnicodeScalar("m")))
        }
    }

    let predefinedMembershipCS = CharacterSet.whitespacesAndNewlines
    Benchmark("Predefined Membership") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(predefinedMembershipCS.contains(UnicodeScalar(" ")))
        }
    }

    let dataMembershipCS = CharacterSet(bitmapRepresentation: data)
    Benchmark("Data Membership") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(dataMembershipCS.contains(UnicodeScalar("a")))
        }
    }
    
    // MARK: Hash & Equality & Bitmap Representation
    Benchmark("Hash Predefined CharacterSet") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs = CharacterSet.whitespacesAndNewlines
            var hasher = Hasher()
            cs.hash(into: &hasher)
            blackHole(hasher.finalize())
        }
    }
    
    Benchmark("Hash BMP-Only CharacterSet") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs: CharacterSet = {
                var cs = CharacterSet(charactersIn: "a"..."f")
                cs.insert(charactersIn: "A"..."F")
                cs.insert(charactersIn: "0"..."9")
                return cs
            }()
            var hasher = Hasher()
            cs.hash(into: &hasher)
            blackHole(hasher.finalize())
        }
    }
    
    Benchmark("Hash Multi-Plane CharacterSet") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs: CharacterSet = {
                var cs = CharacterSet(charactersIn: "a"..."z")
                cs.insert(charactersIn: "A"..."Z")
                cs.insert(
                    charactersIn:
                        "_\u{00A8}\u{00AA}\u{00AD}\u{00AF}\u{00B2}\u{00B3}\u{00B4}\u{00B5}\u{00B7}\u{00B8}\u{00B9}\u{00BA}\u{00BC}\u{00BD}\u{00BE}"
                )
                cs.insert(charactersIn: "\u{00C0}"..."\u{00D6}")
                cs.insert(charactersIn: "\u{00D8}"..."\u{00F6}")
                cs.insert(charactersIn: "\u{00F8}"..."\u{00FF}")
                cs.insert(charactersIn: "\u{0100}"..."\u{02FF}")
                cs.insert(charactersIn: "\u{0370}"..."\u{167F}")
                cs.insert(charactersIn: "\u{1681}"..."\u{180D}")
                cs.insert(charactersIn: "\u{180F}"..."\u{1DBF}")
                cs.insert(charactersIn: "\u{1E00}"..."\u{1FFF}")
                cs.insert(charactersIn: "\u{200B}"..."\u{200D}")
                cs.insert(charactersIn: "\u{202A}"..."\u{202E}")
                cs.insert(charactersIn: "\u{203F}"..."\u{2040}")
                cs.insert(charactersIn: "\u{2054}")
                cs.insert(charactersIn: "\u{2060}"..."\u{206F}")
                cs.insert(charactersIn: "\u{2070}"..."\u{20CF}")
                cs.insert(charactersIn: "\u{2100}"..."\u{218F}")
                cs.insert(charactersIn: "\u{2460}"..."\u{24FF}")
                cs.insert(charactersIn: "\u{2776}"..."\u{2793}")
                cs.insert(charactersIn: "\u{2C00}"..."\u{2DFF}")
                cs.insert(charactersIn: "\u{2E80}"..."\u{2FFF}")
                cs.insert(charactersIn: "\u{3004}"..."\u{3007}")
                cs.insert(charactersIn: "\u{3021}"..."\u{302F}")
                cs.insert(charactersIn: "\u{3031}"..."\u{303F}")
                cs.insert(charactersIn: "\u{3040}"..."\u{D7FF}")
                cs.insert(charactersIn: "\u{F900}"..."\u{FD3D}")
                cs.insert(charactersIn: "\u{FD40}"..."\u{FDCF}")
                cs.insert(charactersIn: "\u{FDF0}"..."\u{FE1F}")
                cs.insert(charactersIn: "\u{FE30}"..."\u{FE44}")
                cs.insert(charactersIn: "\u{FE47}"..."\u{FFFD}")
                cs.insert(charactersIn: "\u{10000}"..."\u{1FFFD}")
                cs.insert(charactersIn: "\u{20000}"..."\u{2FFFD}")
                cs.insert(charactersIn: "\u{30000}"..."\u{3FFFD}")
                cs.insert(charactersIn: "\u{40000}"..."\u{4FFFD}")
                cs.insert(charactersIn: "\u{50000}"..."\u{5FFFD}")
                cs.insert(charactersIn: "\u{60000}"..."\u{6FFFD}")
                cs.insert(charactersIn: "\u{70000}"..."\u{7FFFD}")
                cs.insert(charactersIn: "\u{80000}"..."\u{8FFFD}")
                cs.insert(charactersIn: "\u{90000}"..."\u{9FFFD}")
                cs.insert(charactersIn: "\u{A0000}"..."\u{AFFFD}")
                cs.insert(charactersIn: "\u{B0000}"..."\u{BFFFD}")
                cs.insert(charactersIn: "\u{C0000}"..."\u{CFFFD}")
                cs.insert(charactersIn: "\u{D0000}"..."\u{DFFFD}")
                cs.insert(charactersIn: "\u{E0000}"..."\u{EFFFD}")
                return cs
            }()
            var hasher = Hasher()
            cs.hash(into: &hasher)
            blackHole(hasher.finalize())
        }
    }
    
    Benchmark("Hash Almost Everything") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs: CharacterSet = {
                var characterSet = CharacterSet(charactersIn: "\u{0000}"..."\u{10FFFF}")
                characterSet.remove(charactersIn: "\"\\\n\r\t\u{0008}\u{000C}")
                return characterSet
            }()
            var hasher = Hasher()
            cs.hash(into: &hasher)
            blackHole(hasher.finalize())
        }
    }
    
    let csSample1: CharacterSet = {
        var cs = CharacterSet(charactersIn: "a"..."z")
        cs.insert(charactersIn: "A"..."Z")
        cs.insert(charactersIn: "\u{10000}"..."\u{1FFFD}")
        cs.insert(charactersIn: "\u{20000}"..."\u{2FFFD}")
        return cs
    }()
    let csSample1Copy = csSample1
    Benchmark("Equal between Two Bitmaps") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(csSample1 == csSample1Copy)
        }
    }
    
    let csSample2: CharacterSet = {
        var cs = CharacterSet(charactersIn: "ABC")
        cs.invert()
        return cs
    }()
    let csSample3: CharacterSet = {
        var cs = CharacterSet(charactersIn: "\u{0000}"..."\u{10FFFF}")
        cs.remove(charactersIn: "ABC")
        return cs
    }()
    Benchmark("Equal between Bitmap and String") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(csSample2 == csSample3)
        }
    }
    
    let csSample4: CharacterSet = {
        var cs = CharacterSet(charactersIn: "a"..."z")
        cs.insert(charactersIn: "A"..."Z")
        cs.insert(charactersIn: "\u{10000}"..."\u{1FFFD}")
        return cs
    }()
    Benchmark("Not Equal between Two Bitmaps") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(csSample1 == csSample4)
        }
    }
    
    let csSample5: CharacterSet = {
        var cs = CharacterSet(charactersIn: "Hello, World!")
        return cs
    }()
    Benchmark("Not Equal between Bitmap and String") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(csSample1 == csSample5)
        }
    }

    // MARK: Common Usage Patterns
    
    let trimWhitespaceInput = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift\n"
    Benchmark("Trim Whitespaces and Newlines") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(trimWhitespaceInput.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    
    let pathWithSlashes = "/documentation/swiftdoc/articles/"
    let slashSet = CharacterSet(charactersIn: "/")
    Benchmark("Trim Path Slashes") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(pathWithSlashes.trimmingCharacters(in: slashSet))
        }
    }

    let whitespaceSplitInput = "swift test --package-path FoundationPreview --filter CharacterSet"
    Benchmark("Split String by Whitespaces") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(whitespaceSplitInput.components(separatedBy: .whitespaces))
        }
    }
    
    let multilineLogInput = "[1/3] Compiling Foundation\n[2/3] Compiling FoundationInternationalization\n\n[3/3] Linking libFoundation.dylib\n"
    Benchmark("Split String by Newlines") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(multilineLogInput.components(separatedBy: .newlines).filter { !$0.isEmpty })
        }
    }
    
    let applicationTag = "com.hello.apple.SwiftFoundation.shared-test"
    let dotSet = CharacterSet(charactersIn: ".")
    Benchmark("Split Identifier by Dots") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(applicationTag.components(separatedBy: dotSet))
        }
    }

    let digitExtractionInput = "+1 (650) 555-1234"
    Benchmark("Extract Decimal Digits") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(digitExtractionInput.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
        }
    }
    
    let pemBody = """
        MIIDdzCCAl+gAwIBAgIEAgAAuTANBgkqhkiG9w0BAQUFADBa
        MQswCQYDVQQGEwJJRTESMBAGA1UEChMJQmFsdGltb3JlMRMw
        EQYDVQQLEwpDeWJlclRydXN0MSIwIAYDVQQDExlCYWx0aW1v
        cmUgQ3liZXJUcnVzdCBSb290
        """
    Benchmark("Strip Whitespace From Base64 Block") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(pemBody.components(separatedBy: .whitespacesAndNewlines).joined())
        }
    }
    
    let includeLineSample = "#include <Foundation/Foundation.h>"
    let includeBoundarySet = CharacterSet(charactersIn: "\"<")
    Benchmark("Find Quote Or Bracket In Input") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(includeLineSample.rangeOfCharacter(from: includeBoundarySet))
        }
    }

    let validFilenameInput = "MyPhotoFromVacationDay2024Apr15"
    let invalidFilenameInput = "MyPhotoFromVacation-Day2024Apr15"
    let invertedAlphanumerics = CharacterSet.alphanumerics.inverted
    Benchmark("Validate Filenames") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(validFilenameInput.rangeOfCharacter(from: invertedAlphanumerics) == nil)
            blackHole(invalidFilenameInput.rangeOfCharacter(from: invertedAlphanumerics) != nil)
        }
    }

    let base32Allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz234567")
    let candidateSecretKey = "JBSWY3DPEHPK3PXPABCDEFGHIJKLMNOP"
    Benchmark("Validate Base32-Alphabet String") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet(charactersIn: candidateSecretKey).isDisjoint(with: base32Allowed.inverted))
        }
    }
    
    
    Benchmark("Union Multiple Built-In Sets") { benchmark in
        for _ in benchmark.scaledIterations {
            let exclusionCharacterSet = CharacterSet.controlCharacters
                .union(.whitespacesAndNewlines)
                .union(.punctuationCharacters)
            blackHole(exclusionCharacterSet)
        }
    }
    
    Benchmark("FormIntersection Multiple Built-In Sets") { benchmark in
        for _ in benchmark.scaledIterations {
            var legalWhitespaceSet = CharacterSet.illegalCharacters.inverted
            legalWhitespaceSet.formIntersection(CharacterSet.whitespaces)
            blackHole(legalWhitespaceSet)
        }
    }
    
    let mailBodySample: String = {
        var s = ""
        for _ in 0..<7 {
            s += "From: sender@example.com\r\nTo: recipient@example.com\r\n"
            s += "Subject: Weekly Update\r\n\r\n"
            s += "Hi team,\n\nPlease review the attached report.\n"
            s += "Let me know if you have questions.\n\nBest,\nSender\n\n"
        }
        return s
    }()
    let invertedWhitespace = CharacterSet.whitespacesAndNewlines.inverted
    Benchmark("Scan Email Body For Non-Whitespace and Non-Newline Characters") { benchmark in
        for _ in benchmark.scaledIterations {
            var count = 0
            for scalar in mailBodySample.unicodeScalars {
                if invertedWhitespace.contains(scalar) {
                    count += 1
                }
            }
            blackHole(count)
        }
    }

    let whitespaceSet = CharacterSet.whitespacesAndNewlines
    Benchmark("Scan Email Body For Whitespace Chars") { benchmark in
        for _ in benchmark.scaledIterations {
            var count = 0
            for scalar in mailBodySample.unicodeScalars {
                if whitespaceSet.contains(scalar) {
                    count += 1
                }
            }
            blackHole(count)
        }
    }

    let urlPathPlain = "api-v2-users-profile-settings"
    Benchmark("Scan Plain String for Slash") { benchmark in
        for _ in benchmark.scaledIterations {
            var count = 0
            for scalar in urlPathPlain.unicodeScalars {
                if slashSet.contains(scalar) { count += 1 }
            }
            blackHole(count)
        }
    }
    
    let urlPathWithSlashes = "api/v2/users/profile/settings"
    Benchmark("Scan URL Path for Slash") { benchmark in
        for _ in benchmark.scaledIterations {
            var count = 0
            for scalar in urlPathWithSlashes.unicodeScalars {
                if slashSet.contains(scalar) { count += 1 }
            }
            blackHole(count)
        }
    }

    let hostnameInput = "api.example-service.com"
    Benchmark("Scan Hostname for Custom Characters") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs = CharacterSet(charactersIn: "-._")
            var count = 0
            for scalar in hostnameInput.unicodeScalars {
                if cs.contains(scalar) {
                    count += 1
                }
            }
            blackHole(count)
        }
    }

    let alphanumericsSet = CharacterSet.alphanumerics
    let healthMetricInput = "HeartRate120bpmRestingEnergyBurned2340kcalStepCount8421ActiveMinutes47"
    Benchmark("Scan Health Metric For Alphanumerics") { benchmark in
        for _ in benchmark.scaledIterations {
            var count = 0
            for scalar in healthMetricInput.unicodeScalars {
                if alphanumericsSet.contains(scalar) {
                    count += 1
                }
            }
            blackHole(count)
        }
    }
    
    let mailLinkQuery = "subject=Example Bug Report&body=I encountered a bug while using CharacterSet on iOS 25&device=Betty's iPhone 13 Pro"
    Benchmark("Percent-Encode With urlQueryAllowed") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(mailLinkQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        }
    }
    #endif // FOUNDATION_FRAMEWORK
}
