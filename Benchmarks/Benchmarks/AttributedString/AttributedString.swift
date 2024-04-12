//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
import Benchmark
import Foundation

enum AttributedStringBenchmark {
    fileprivate static func createLongString() -> AttributedString {
        var str = AttributedString(String(repeating: "a", count: 10000), attributes: AttributeContainer().testInt(1))
        str += AttributedString(String(repeating: "b", count: 10000), attributes: AttributeContainer().testInt(2))
        str += AttributedString(String(repeating: "c", count: 10000), attributes: AttributeContainer().testInt(3))
        return str
    }

    fileprivate func createManyAttributesString() -> AttributedString {
        var str = AttributedString("a")
        for i in 0..<10000 {
            str += AttributedString("a", attributes: AttributeContainer().testInt(i))
        }
        return str
    }

    fileprivate func createLongNSString() -> NSMutableAttributedString {
        let str = NSMutableAttributedString(string: String(repeating: "a", count: 10000), attributes: [.testInt: NSNumber(1)])
        str.append(NSMutableAttributedString(string: String(repeating: "b", count: 10000), attributes: [.testInt: NSNumber(2)]))
        str.append(NSMutableAttributedString(string: String(repeating: "c", count: 10000), attributes: [.testInt: NSNumber(3)]))
        return str
    }

    fileprivate func createManyAttributesNSString() -> NSMutableAttributedString {
        let str = NSMutableAttributedString(string: "a")
        for i in 0..<10000 {
            str.append(NSAttributedString(string: "a", attributes: [.testInt: NSNumber(value: i)]))
        }
        return str
    }
}

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .mallocCountTotal, .throughput]

    /// Set to true to record a baseline for equivalent operations on `NSAttributedString`
    let runWithNSAttributedString = false

    // MARK: - String Manipulation
    Benchmark(
        "testInsertIntoLongString",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        var str = createLongString()
        let idx = str.characters.index(str.startIndex, offsetBy: str.characters.count / 2)
        let toInsert = AttributedString(String(repeating: "c", count: str.characters.count))

        let strNS = createLongNSString()
        let idxNS = str.characters.count / 2
        let toInsertNS = NSAttributedString(string: String(repeating: "c", count: str.characters.count))

        for _ in benchmark.scaledIterations {
            if runWithNSAttributedString {
                strNS.insert(toInsertNS, at: idxNS)
            } else {
                str.insert(toInsert, at: idx)
            }
        }
    }

    Benchmark(
        "testReplaceSubrangeOfLongString",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        var str = createLongString()
        let start = str.characters.index(str.startIndex, offsetBy: str.characters.count / 2)
        let range = start ... str.characters.index(start, offsetBy: 10)
        let toInsert = AttributedString(String(repeating: "d", count: str.characters.count / 2), attributes: AttributeContainer().testDouble(2.5))

        let strNS = createLongNSString()
        let startNS = strNS.string.count / 2
        let rangeNS = NSRange(location: startNS, length: 10)
        let toInsertNS = NSAttributedString(string: String(repeating: "d", count: strNS.string.count / 2), attributes: [.testDouble: NSNumber(value: 2.5)])


        for _ in benchmark.scaledIterations {
            if runWithNSAttributedString {
                strNS.replaceCharacters(in: rangeNS, with: toInsertNS)
            } else {
                str.replaceSubrange(range, with: toInsert)
            }
        }
    }

    // MARK: - Attribute Manipulation
    Benchmark(
        "testSetAttribute",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        var str = createManyAttributesString()
        let strNS = createManyAttributesNSString()

        for _ in benchmark.scaledIterations {
            if runWithNSAttributedString {
                strNS.addAttributes([.testDouble: NSNumber(value: 1.5)], range: NSRange(location: 0, length: strNS.string.count))
            } else {
                str.testDouble = 1.5
            }
        }
    }

    Benchmark(
        "testSetAttribute",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        let str = createManyAttributesString()
        let strNS = createManyAttributesNSString()

        for _ in benchmark.scaledIterations {
            if runWithNSAttributedString {
                strNS.enumerateAttribute(.testDouble, in: NSRange(location: 0, length: strNS.string.count), options: []) { (attr, range, pointer) in
                    let _ = attr
                }
            } else {
                let _ = str.testDouble
            }
        }
    }

    Benchmark(
        "testSetAttribute",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        var str = createManyAttributesString()
        let range = str.characters.index(str.startIndex, offsetBy: str.characters.count / 2)...

        let strNS = createManyAttributesNSString()
        let rangeNS = NSRange(location: 0, length: str.characters.count / 2)

        for _ in benchmark.scaledIterations {
            if TestAttributedStringPerformance.runWithNSAttributedString {
                strNS.addAttributes([.testDouble: NSNumber(value: 1.5)], range: rangeNS)
            } else {
                str[range].testDouble = 1.5
            }
        }
    }

    Benchmark(
        "testGetAttributeSubrange",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        let str = createManyAttributesString()
        let range = str.characters.index(str.startIndex, offsetBy: str.characters.count / 2)...

        let strNS = createManyAttributesNSString()
        let rangeNS = NSRange(location: 0, length: str.characters.count / 2)

        for _ in benchmark.scaledIterations {
            if TestAttributedStringPerformance.runWithNSAttributedString {
                strNS.enumerateAttribute(.testDouble, in: rangeNS, options: []) { (attr, range, pointer) in
                    let _ = attr
                }
            } else {
                let _ = str[range].testDouble
            }
        }
    }

    Benchmark(
        "testModifyAttributes",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        let str = createManyAttributesString()
        let strNS = createManyAttributesNSString()

        for _ in benchmark.scaledIterations {
            if self.runWithNSAttributedString {
                strNS.enumerateAttribute(.testInt, in: NSRange(location: 0, length: strNS.string.count), options: []) { (val, range, pointer) in
                    if let value = val as? NSNumber {
                        strNS.addAttributes([.testInt: NSNumber(value: value.intValue + 2)], range: range)
                    }
                }
            } else {
                let _ = str.transformingAttributes(\.testInt) { transformer in
                    if let val = transformer.value {
                        transformer.value = val + 2
                    }
                }
            }
        }
    }

    Benchmark(
        "testReplaceAttributes",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        var str = createManyAttributesString()
        let old = AttributeContainer().testInt(100)
        let new = AttributeContainer().testDouble(100.5)

        let strNS = createManyAttributesNSString()

        for _ in benchmark.scaledIterations {
            if TestAttributedStringPerformance.runWithNSAttributedString {
                strNS.enumerateAttribute(.testInt, in: NSRange(location: 0, length: strNS.string.count), options: []) { (val, range, pointer) in
                    if let value = val as? NSNumber, value == 100 {
                        strNS.removeAttribute(.testInt, range: range)
                        strNS.addAttribute(.testDouble, value: NSNumber(value: 100.5), range: range)
                    }
                }
            } else {
                str.replaceAttributes(old, with: new)
            }
        }
    }

    Benchmark(
        "testMergeMultipleAttributes",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        var str = createManyAttributesString()
        let new = AttributeContainer().testDouble(1.5).testString("test")

        let strNS = createManyAttributesNSString()
        let newNS: [NSAttributedString.Key: Any] = [.testDouble: NSNumber(value: 1.5), .testString: "test"]

        for _ in benchmark.scaledIterations {
            if TestAttributedStringPerformance.runWithNSAttributedString {
                strNS.addAttributes(newNS, range: NSRange(location: 0, length: strNS.string.count))
            } else {
                str.mergeAttributes(new)
            }
        }
    }

    Benchmark(
        "testSetMultipleAttributes",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        var str = createManyAttributesString()
        let new = AttributeContainer().testDouble(1.5).testString("test")

        let strNS = createManyAttributesNSString()
        let rangeNS = NSRange(location: 0, length: str.characters.count / 2)
        let newNS: [NSAttributedString.Key: Any] = [.testDouble: NSNumber(value: 1.5), .testString: "test"]

        for _ in benchmark.scaledIterations {
            if TestAttributedStringPerformance.runWithNSAttributedString {
                strNS.setAttributes(newNS, range: rangeNS)
            } else {
                str.setAttributes(new)
            }
        }
    }

    // MARK: - Attribute Enumeration

    Benchmark(
        "testEnumerateAttributes",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        let str = createManyAttributesString()
        let strNS = createManyAttributesNSString()

        for _ in benchmark.scaledIterations {
            if self.runWithNSAttributedString {
                strNS.enumerateAttributes(in: NSRange(location: 0, length: strNS.string.count), options: []) { (attrs, range, pointer) in

                }
            } else {
                for _ in str.runs {

                }
            }
        }
    }

    Benchmark(
        "testEnumerateAttributesSlice",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        let str = createManyAttributesString()
        let strNS = createManyAttributesNSString()

        for _ in benchmark.scaledIterations {
            if TestAttributedStringPerformance.runWithNSAttributedString {
                strNS.enumerateAttribute(.testInt, in: NSRange(location: 0, length: strNS.string.count), options: []) { (val, range, pointer) in

                }
            } else {
                for (_, _) in str.runs[\.testInt] {

                }
            }
        }
    }

    // MARK: - NSAS Conversion
    if !runWithNSAttributedString {
        Benchmark(
            "testConvertToNSAS",
            configuration: .init(scalingFactor: .mega)
        ) { benchmark in
            let str = createManyAttributesString()

            for _ in benchmark.scaledIterations {
                let _ = try! NSAttributedString(str, including: AttributeScopes.TestAttributes.self)
            }
        }

        Benchmark(
            "testConvertToNSAS",
            configuration: .init(scalingFactor: .mega)
        ) { benchmark in
            let str = createManyAttributesString()
            let ns = try NSAttributedString(str, including: AttributeScopes.TestAttributes.self)

            for _ in benchmark.scaledIterations {
                let _ = try! AttributedString(ns, including: AttributeScopes.TestAttributes.self)
            }
        }

        Benchmark(
            "testEquality",
            configuration: .init(scalingFactor: .mega)
        ) { benchmark in
            let str = createManyAttributesString()
            let str2 = createManyAttributesString()

            for _ in benchmark.scaledIteration {
                _ = str == str2
            }
        }

        Benchmark(
            "testSubstringEquality",
            configuration: .init(scalingFactor: .mega)
        ) { benchmark in
            let str = createManyAttributesString()
            let str2 = createManyAttributesString()
            let range = str.characters.index(str.startIndex, offsetBy: str.characters.count / 2)...
            let substring = str[range]
            let substring2 = str2[range]

            for _ in benchmark.scaledIteration {
                _ = substring == substring2
            }
        }

        Benchmark(
            "testHashAttributedString",
            configuration: .init(scalingFactor: .mega)
        ) { benchmark in
            let str = createManyAttributesString()
            for _ in benchmark.scaledIteration {
                var hasher = Hasher()
                str.hash(into: &hasher)
                _ = hasher.finalize()
            }
        }

        Benchmark(
            "testHashAttributeContainer",
            configuration: .init(scalingFactor: .mega)
        ) { benchmark in
            struct TestAttribute : AttributedStringKey {
                static var name = "0"
                typealias Value = Int
            }

            var container = AttributeContainer()
            for i in 0 ..< 100000 {
                TestAttribute.name = "\(i)"
                container[TestAttribute.self] = i
            }
            for _ in benchmark.scaledIteration {
                var hasher = Hasher()
                container.hash(into: &hasher)
                _ = hasher.finalize()
            }
        }
    }

    // MARK: - Encoding and Decoding

    Benchmark(
        "testEnumerateAttributesSlice",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        struct CodableType: Codable {
            @CodableConfiguration(from: AttributeScopes.TestAttributes.self)
            var str = AttributedString()
        }

        let str = createManyAttributesString()
        let codableType = CodableType(str: str)
        let encoder = JSONEncoder()

        let ns = createManyAttributesNSString()

        for _ in benchmark.scaledIterations {
            if runWithNSAttributedString {
                let _ = try! NSKeyedArchiver.archivedData(withRootObject: ns, requiringSecureCoding: false)
            } else {
                let _ = try! encoder.encode(codableType)
            }
        }
    }

    Benchmark(
        "testDecode",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        struct CodableType: Codable {
            @CodableConfiguration(from: AttributeScopes.TestAttributes.self)
            var str = AttributedString()
        }

        let str = createManyAttributesString()
        let codableType = CodableType(str: str)
        let encoder = JSONEncoder()
        let data = try encoder.encode(codableType)
        let decoder = JSONDecoder()

        let ns = createManyAttributesNSString()
        let dataNS = try NSKeyedArchiver.archivedData(withRootObject: ns, requiringSecureCoding: false)

        for _ in benchmark.scaledIterations {
            if runWithNSAttributedString {
                let _ = try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(dataNS)
            } else {
                let _ = try! decoder.decode(CodableType.self, from: data)
            }
        }
    }

    // MARK: - Other
    Benchmark(
        "testCreateLongString",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        for _ in benchmark.scaledIteration {
            if TestAttributedStringPerformance.runWithNSAttributedString {
                let _ = createLongNSString()
            } else {
                let _ = createLongString()
            }
        }
    }

    Benchmark(
        "testCreateManyAttributesString",
        configuration: .init(scalingFactor: .mega)
    ) { benchmark in
        for _ in benchmark.scaledIteration {
            if TestAttributedStringPerformance.runWithNSAttributedString {
                let _ = createManyAttributesNSString()
            } else {
                let _ = createManyAttributesString()
            }
        }
    }
}

#endif // FOUNDATION_FRAMEWORK
