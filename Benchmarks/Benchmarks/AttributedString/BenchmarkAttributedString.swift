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

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
#else
import Foundation
#endif

/*
 To compare the swift and objc benchmarks (struct AttributedString vs NSAttributedString), with JMH run the benchmark then:
 ```
 sed 's/-swift//g' Current_run.jmh.json > Swift.jmh.json && sed 's/-objc//g' Current_run.jmh.json > ObjC.jmh.json
 ```
 
 and compare the two JMH files
*/


/// A box for an `AttributedString`. Intentionally turns the value type into a reference, so we can make a promise that the inner value is not copied due to mutation during a test of insertion or replacing.
class AttributedStringBox {
    var attributedString: AttributedString
    
    init(attributedString: AttributedString) {
        self.attributedString = attributedString
        
        interestingIndex = self.attributedString.startIndex
        anotherString = AttributedString()
        interestingRange = self.attributedString.startIndex...self.attributedString.endIndex
    }
    
    var interestingIndex: AttributedString.Index
    var interestingRange: ClosedRange<AttributedString.Index>
    var anotherString: AttributedString
    
    /// For `insertIntoLongString`
    func insertIntoLongStringTest() {
        attributedString.insert(anotherString, at: interestingIndex)
    }
    
    /// For `replaceSubrangeOfLongString`
    func replaceSubrangeOfLongStringTest() {
        attributedString.replaceSubrange(interestingRange, with: anotherString)
    }
}

let benchmarks = {
    Benchmark.defaultConfiguration.warmupIterations = 0
    Benchmark.defaultConfiguration.maxDuration = .seconds(1)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .throughput]
    
    let manyAttributesString = createManyAttributesString()
    let longString = createLongString()
#if FOUNDATION_FRAMEWORK
    let manyAttributesNS = createManyAttributesNSString()
    let toInsertNS = NSAttributedString(string: String(repeating: "c", count: longString.characters.count))
#endif
    
    Benchmark("insertIntoLongString-swift", closure: { benchmark, box in
        for _ in benchmark.scaledIterations {
            box.insertIntoLongStringTest()
        }
    }, setup: { () -> AttributedStringBox in
        // Create the string once, then treat it as a reference for the test, which focuses on insert performance only
        var str = createLongString()
        let idx = str.characters.index(str.startIndex, offsetBy: str.characters.count / 2)
        let toInsert = AttributedString(String(repeating: "c", count: str.characters.count))

        let box = AttributedStringBox(attributedString: str)
        box.interestingIndex = idx
        box.anotherString = toInsert
        return box
    })
    
#if FOUNDATION_FRAMEWORK
    Benchmark("insertIntoLongString-objc", closure: { benchmark, strNS in
        autoreleasepool {
            let idxNS = longString.characters.count / 2

            for _ in benchmark.scaledIterations {
                strNS.insert(toInsertNS, at: idxNS)
            }
        }
    }, setup: createLongNSString)
#endif
    
    Benchmark("replaceSubrangeOfLongString-swift", closure: { benchmark, box in
        for _ in benchmark.scaledIterations {
            box.replaceSubrangeOfLongStringTest()
        }
    }, setup: { () -> AttributedStringBox in
        // Create the string once, then treat it as a reference for the test, which focuses on replace performance only
        var str = createLongString()
        let start = str.characters.index(str.startIndex, offsetBy: str.characters.count / 2)
        let range = start ... str.characters.index(start, offsetBy: 10)
        let toInsert = AttributedString(String(repeating: "d", count: str.characters.count / 2), attributes: AttributeContainer().testDouble(2.5))

        let box = AttributedStringBox(attributedString: str)
        box.interestingIndex = start
        box.anotherString = toInsert
        box.interestingRange = range
        return box
    })
    
#if FOUNDATION_FRAMEWORK
    Benchmark("replaceSubrangeOfLongString-objc", closure: { benchmark, strs in
        autoreleasepool {
            let (strNS, toInsertNS) = strs
            let startNS = strNS.length / 2
            let rangeNS = NSRange(location: startNS, length: 10)
                        
            for _ in benchmark.scaledIterations {
                strNS.replaceCharacters(in: rangeNS, with: toInsertNS)
            }
        }
    }, setup: { () -> (NSMutableAttributedString, NSAttributedString) in
        let longNSString = createLongNSString()
        let toInsertNS = NSAttributedString(string: String(repeating: "d", count: longNSString.length / 2), attributes: [.testDouble: NSNumber(value: 2.5)])
        return (longNSString, toInsertNS)
    })
#endif
    
    // MARK: - Attribute Manipulation
    
    Benchmark("setAttribute-swift") { benchmark in
        var str = manyAttributesString
        str.testDouble = 1.5
    }
    
#if FOUNDATION_FRAMEWORK
    Benchmark("setAttribute-objc", closure: { benchmark, strNS in
        autoreleasepool {
            strNS.addAttributes([.testDouble: NSNumber(value: 1.5)], range: NSRange(location: 0, length: strNS.length))
        }
    }, setup: { () -> NSMutableAttributedString in
        return manyAttributesNS.mutableCopy() as! NSMutableAttributedString
    })
#endif
    
    Benchmark("getAttribute-swift") { benchmark in
        for (a, b) in manyAttributesString.runs[\.testDouble] {
            blackHole(a)
            blackHole(b)
        }
    }
    
#if FOUNDATION_FRAMEWORK
    Benchmark("getAttribute-objc") { benchmark in
        autoreleasepool {
            manyAttributesNS.enumerateAttribute(.testDouble, in: NSRange(location: 0, length: manyAttributesNS.length), options: []) { (attr, range, pointer) in
                blackHole(attr)
            }
        }
    }
#endif
    
    Benchmark("setAttributeSubrange-swift") { benchmark in
        var str = manyAttributesString
        let range = str.characters.index(str.startIndex, offsetBy: str.characters.count / 2)...
        
        str[range].testDouble = 1.5
    }
    
#if FOUNDATION_FRAMEWORK
    Benchmark("setAttributeSubrange-objc") { benchmark in
        autoreleasepool {
            // Copy the string each time - that is equivalent to the Swift one above
            let strNS = manyAttributesNS.mutableCopy() as! NSMutableAttributedString
            let rangeNS = NSRange(location: 0, length: strNS.length)
            
            strNS.addAttributes([.testDouble: NSNumber(value: 1.5)], range: rangeNS)
        }
    }
#endif
    
    Benchmark("getAttributeSubrange-swift") { benchmark in
        let range = manyAttributesString.characters.index(manyAttributesString.startIndex, offsetBy: manyAttributesString.characters.count / 2)...
        for (a, b) in manyAttributesString[range].runs[\.testDouble] {
            blackHole(a)
            blackHole(b)
        }
    }
    
#if FOUNDATION_FRAMEWORK
    Benchmark("getAttributeSubrange-objc", closure: { benchmark, strNS in
        autoreleasepool {
            let rangeNS = NSRange(location: 0, length: strNS.length)
            
            strNS.enumerateAttribute(.testDouble, in: rangeNS, options: []) { (attr, range, pointer) in
                blackHole(attr)
            }
        }
    }, setup: { () -> NSMutableAttributedString in
        return manyAttributesNS.mutableCopy() as! NSMutableAttributedString
    })
#endif
    
    Benchmark("modifyAttributes-swift") { benchmark in
        let r = manyAttributesString.transformingAttributes(\.testInt) { transformer in
            if let val = transformer.value {
                transformer.value = val + 2
            }
        }
        blackHole(r)
    }
    
#if FOUNDATION_FRAMEWORK
    Benchmark("modifyAttributes-objc", closure: { benchmark, strNS in
        autoreleasepool {
            strNS.enumerateAttribute(.testInt, in: NSRange(location: 0, length: strNS.length), options: []) { (val, range, pointer) in
                if let value = val as? NSNumber {
                    strNS.addAttributes([.testInt: NSNumber(value: value.intValue + 2)], range: range)
                }
            }
        }
    }, setup: { () -> NSMutableAttributedString in
        return manyAttributesNS.mutableCopy() as! NSMutableAttributedString
    })
#endif
    
    Benchmark("replaceAttributes-swift") { benchmark in
        var str = manyAttributesString
        let old = AttributeContainer().testInt(100)
        let new = AttributeContainer().testDouble(100.5)
        
        str.replaceAttributes(old, with: new)
    }
    
#if FOUNDATION_FRAMEWORK
    Benchmark("replaceAttributes-objc", closure: { benchmark, strNS in
        autoreleasepool {
            strNS.enumerateAttribute(.testInt, in: NSRange(location: 0, length: strNS.length), options: []) { (val, range, pointer) in
                if let value = val as? NSNumber, value == 100 {
                    strNS.removeAttribute(.testInt, range: range)
                    strNS.addAttribute(.testDouble, value: NSNumber(value: 100.5), range: range)
                }
            }
        }
    }, setup: { () -> NSMutableAttributedString in
        return manyAttributesNS.mutableCopy() as! NSMutableAttributedString
    })
#endif
    
    Benchmark("mergeMultipleAttributes-swift") { benchmark in
        var str = manyAttributesString
        let new = AttributeContainer().testDouble(1.5).testString("test")
        
        str.mergeAttributes(new)
    }
    
#if FOUNDATION_FRAMEWORK
    Benchmark("mergeMultipleAttributes-objc") { benchmark in
        autoreleasepool {
            // Copy string each time
            let strNS = manyAttributesNS.mutableCopy() as! NSMutableAttributedString
            let newNS: [NSAttributedString.Key: Any] = [.testDouble: NSNumber(value: 1.5), .testString: "test"]
            
            strNS.addAttributes(newNS, range: NSRange(location: 0, length: strNS.length))
        }
    }
#endif
    
    Benchmark("setMultipleAttributes-swift") { benchmark in
        var str = manyAttributesString
        let new = AttributeContainer().testDouble(1.5).testString("test")
        
        str.setAttributes(new)
    }
    
#if FOUNDATION_FRAMEWORK
    Benchmark("setMultipleAttributes-objc") { benchmark in
        autoreleasepool {
            // Copy string each time
            let strNS = manyAttributesNS.mutableCopy() as! NSMutableAttributedString
            let rangeNS = NSRange(location: 0, length: strNS.length)
            let newNS: [NSAttributedString.Key: Any] = [.testDouble: NSNumber(value: 1.5), .testString: "test"]
            
            strNS.setAttributes(newNS, range: rangeNS)
        }
    }
#endif
    
    // MARK: - Attribute Enumeration
    
    Benchmark("enumerateAttributes-swift") { benchmark in
        for r in manyAttributesString.runs {
            blackHole(r)
        }
    }
    
#if FOUNDATION_FRAMEWORK
    Benchmark("enumerateAttributes-objc") { benchmark in
        autoreleasepool {
            manyAttributesNS.enumerateAttributes(in: NSRange(location: 0, length: manyAttributesNS.length), options: []) { (attrs, range, pointer) in
                // pass
            }
        }
    }
#endif
    
    Benchmark("enumerateAttributesSlice-swift") { benchmark in
        for (a, b) in manyAttributesString.runs[\.testInt] {
            blackHole(a)
            blackHole(b)
        }
    }
    
#if FOUNDATION_FRAMEWORK
    Benchmark("enumerateAttributesSlice-objc") { benchmark in
        autoreleasepool {
            manyAttributesNS.enumerateAttribute(.testInt, in: NSRange(location: 0, length: manyAttributesNS.length), options: []) { (val, range, pointer) in
                // pass
            }
        }
    }
#endif
    
    // MARK: - NSAttributedString Conversion
    
#if FOUNDATION_FRAMEWORK
    Benchmark("convertToNSAS") { benchmark in
        blackHole(try! NSAttributedString(manyAttributesString, including: AttributeScopes.TestAttributes.self))
    }
    
    Benchmark("convertFromNSAS") { benchmark in
        autoreleasepool {
            blackHole(try! AttributedString(manyAttributesNS, including: AttributeScopes.TestAttributes.self))
        }
    }
#endif
    
    // MARK: - Encoding and Decoding

    // TODO: AttributedString Codable conformance is not yet part of FoundationEssentials
#if FOUNDATION_FRAMEWORK
    struct CodableType: Codable {
        @CodableConfiguration(from: AttributeScopes.TestAttributes.self)
        var str = AttributedString()
    }
    
    let encodeMe = CodableType(str: manyAttributesString)
    
    Benchmark("encode-swift") { benchmark in
        let encoder = JSONEncoder()
        blackHole(try! encoder.encode(encodeMe))
    }
#endif
    
#if FOUNDATION_FRAMEWORK
    Benchmark("encode-objc") { benchmark in
        autoreleasepool {
            blackHole(try! NSKeyedArchiver.archivedData(withRootObject: manyAttributesNS, requiringSecureCoding: false))
        }
    }
#endif
    
    // TODO: AttributedString Codable conformance is not yet part of FoundationEssentials
#if FOUNDATION_FRAMEWORK
    let encodedData = try! JSONEncoder().encode(encodeMe)
    
    Benchmark("decode-swift") { benchmark in
        let decoder = JSONDecoder()
        
        blackHole(try! decoder.decode(CodableType.self, from: encodedData))
    }
#endif
    
#if FOUNDATION_FRAMEWORK
    let encodedNSAttributedStringData = try! NSKeyedArchiver.archivedData(withRootObject: manyAttributesNS, requiringSecureCoding: false)
    Benchmark("decode-objc") { benchmark in
        autoreleasepool {
            blackHole(try! NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: encodedNSAttributedStringData))
        }
    }
#endif
    
    // MARK: - Other
    
    Benchmark("createLongString-swift") { benchmark in
        blackHole(createLongString())
    }
    
#if FOUNDATION_FRAMEWORK
    Benchmark("createLongString-objc") { benchmark in
        autoreleasepool {
            blackHole(createLongNSString())
        }
    }
#endif
    
    Benchmark("createManyAttributesString-swift") { benchmark in
        blackHole(createManyAttributesString())
    }
    
#if FOUNDATION_FRAMEWORK
    Benchmark("createManyAttributesString-objc") { benchmark in
        autoreleasepool {
            blackHole(createManyAttributesNSString())
        }
    }
#endif
    
    let manyAttributesString2 = createManyAttributesString()
    let manyAttributesString3 =  {
        var str = createManyAttributesString()
        str.characters.append("a")
        return str
    }()
    let manyAttributesStringRange = manyAttributesString.characters.index(manyAttributesString.startIndex, offsetBy: manyAttributesString.characters.count / 2)...
    let manyAttributesSubstring = manyAttributesString[manyAttributesStringRange]
    let manyAttributes2Substring = manyAttributesString2[manyAttributesStringRange]

    Benchmark("equalityShared") { benchmark in
        blackHole(manyAttributesString == manyAttributesString)
    }

    Benchmark("equality") { benchmark in
        blackHole(manyAttributesString == manyAttributesString2)
    }

    Benchmark("isIdentical") { benchmark in
        blackHole(manyAttributesString.isIdentical(to: manyAttributesString))
    }

    Benchmark("equalityDifferingCharacters") { benchmark in
        blackHole(manyAttributesString == manyAttributesString3)
    }

    Benchmark("substringEqualityShared") { benchmark in
        blackHole(manyAttributesSubstring == manyAttributesSubstring)
    }
    
    Benchmark("substringEquality") { benchmark in
        blackHole(manyAttributesSubstring == manyAttributes2Substring)
    }

    Benchmark("substringIsIdentical") { benchmark in
        blackHole(manyAttributesSubstring.isIdentical(to: manyAttributesSubstring))
    }

    Benchmark("hashAttributedString") { benchmark in
        var hasher = Hasher()
        manyAttributesString.hash(into: &hasher)
        blackHole(hasher.finalize())
    }
    
    Benchmark("removeNonExistentAttribute") { benchmark in
        var str = manyAttributesString
        str.testBool = nil
        blackHole(str)
    }
    
    struct TestAttribute : AttributedStringKey {
        static var name = "0"
        typealias Value = Int
    }
    var hashAttributeContainer = AttributeContainer()
    for i in 0 ..< 100000 {
        TestAttribute.name = "\(i)"
        hashAttributeContainer[TestAttribute.self] = i
    }

#if compiler(>=6.0)
    Benchmark("hashAttributeContainer") { benchmark in
        var hasher = Hasher()
        hashAttributeContainer.hash(into: &hasher)
        blackHole(hasher.finalize())
    }
#endif
    
    let manyAttributesWithParagraph = {
        var str = createManyAttributesString()
        str.testParagraphConstrained = 2
        return str
    }()
    
    Benchmark("paragraphBoundSliceEnumeration-shortRuns") { benchmark in
        for (value, range) in manyAttributesWithParagraph.runs[\.testParagraphConstrained] {
            blackHole(value)
        }
    }
    
    Benchmark("paragraphBoundSliceEnumeration-shortRuns-reversed") { benchmark in
        for (value, range) in manyAttributesWithParagraph.runs[\.testParagraphConstrained].reversed() {
            blackHole(value)
        }
    }
    
    let longParagraphsString = {
        var str = String(repeating: "a", count: 10000) + "\n"
        str += String(repeating: "b", count: 10000) + "\n"
        str += String(repeating: "c", count: 10000)
        return AttributedString(str, attributes: AttributeContainer.testParagraphConstrained(1).testInt(2))
    }()
    
    Benchmark("paragraphBoundSliceEnumeration-longRuns") { benchmark in
        for (value, range) in longParagraphsString.runs[\.testParagraphConstrained] {
            blackHole(value)
        }
    }
    
    Benchmark("paragraphBoundSliceEnumeration-longRuns-reversed") { benchmark in
        for (value, range) in longParagraphsString.runs[\.testParagraphConstrained].reversed() {
            blackHole(value)
        }
    }
    
    Benchmark("range(of:)") { benchmark in
        longString.range(of: "cccc")
    }

    Benchmark("runs") {benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(manyAttributesString.runs)
        }
    }

    Benchmark("stringConversion") { benchmark in
        blackHole(String(longString.characters))
    }
}


// MARK: - Helpers

func createLongString() -> AttributedString {
    var str = AttributedString(String(repeating: "a", count: 10000), attributes: AttributeContainer().testInt(1))
    str += AttributedString(String(repeating: "b", count: 10000), attributes: AttributeContainer().testInt(2))
    str += AttributedString(String(repeating: "c", count: 10000), attributes: AttributeContainer().testInt(3))
    return str
}

func createManyAttributesString() -> AttributedString {
    var str = AttributedString("a")
    for i in 0..<10000 {
        str += AttributedString("a", attributes: AttributeContainer().testInt(i))
    }
    return str
}

#if FOUNDATION_FRAMEWORK

func createLongNSString() -> NSMutableAttributedString {
    let str = NSMutableAttributedString(string: String(repeating: "a", count: 10000), attributes: [.testInt: NSNumber(1)])
    str.append(NSMutableAttributedString(string: String(repeating: "b", count: 10000), attributes: [.testInt: NSNumber(2)]))
    str.append(NSMutableAttributedString(string: String(repeating: "c", count: 10000), attributes: [.testInt: NSNumber(3)]))
    return str
}

func createManyAttributesNSString() -> NSMutableAttributedString {
    let str = NSMutableAttributedString(string: "a")
    for i in 0..<10000 {
        str.append(NSAttributedString(string: "a", attributes: [.testInt: NSNumber(value: i)]))
    }
    return str
}

extension NSAttributedString.Key {
    static let testInt = NSAttributedString.Key("TestInt")
    static let testString = NSAttributedString.Key("TestString")
    static let testDouble = NSAttributedString.Key("TestDouble")
    static let testBool = NSAttributedString.Key("TestBool")
#if compiler(>=6.0)
    static let testParagraphConstrained = NSAttributedString.Key("TestParagraphConstrained")
    static let testSecondParagraphConstrained = NSAttributedString.Key("TestSecondParagraphConstrained")
    static let testCharacterConstrained = NSAttributedString.Key("TestCharacterConstrained")
#endif
}
#endif

extension AttributeScopes.TestAttributes {
    
    enum TestIntAttribute: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestInt"
    }
    
    enum TestStringAttribute: CodableAttributedStringKey {
        typealias Value = String
        static let name = "TestString"
    }
    
    enum TestDoubleAttribute: CodableAttributedStringKey {
        typealias Value = Double
        static let name = "TestDouble"
    }
    
    enum TestBoolAttribute: CodableAttributedStringKey {
        typealias Value = Bool
        static let name = "TestBool"
    }
    
    enum TestNonExtended: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestNonExtended"
        static let inheritedByAddedText: Bool = false
    }
    
#if compiler(>=6.0)
    enum TestParagraphConstrained: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestParagraphConstrained"
        static let runBoundaries: AttributedString.AttributeRunBoundaries? = .paragraph
    }

    enum TestSecondParagraphConstrained: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestSecondParagraphConstrained"
        static let runBoundaries: AttributedString.AttributeRunBoundaries? = .paragraph
    }

    enum TestCharacterConstrained: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestCharacterConstrained"
        static let runBoundaries: AttributedString.AttributeRunBoundaries? = .character("*")
    }
    
    enum TestUnicodeCharacterConstrained: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestUnicodeCharacterConstrained"
        static let runBoundaries: AttributedString.AttributeRunBoundaries? = .character("\u{FFFD}") // U+FFFD Replacement Character
    }
    
    enum TestAttributeDependent: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestAttributeDependent"
        static let invalidationConditions: Set<AttributedString.AttributeInvalidationCondition>? = [.attributeChanged(\.testInt)]
    }
    
    enum TestCharacterDependent: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestCharacterDependent"
        static let invalidationConditions: Set<AttributedString.AttributeInvalidationCondition>? = [.textChanged]
    }
#endif

    enum NonCodableAttribute : AttributedStringKey {
        typealias Value = NonCodableType
        static let name = "NonCodable"
    }
    
    enum CustomCodableAttribute : CodableAttributedStringKey {
        typealias Value = NonCodableType
        static let name = "NonCodableConvertible"
        
        static func encode(_ value: NonCodableType, to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            try c.encode(value.inner)
        }
        
        static func decode(from decoder: Decoder) throws -> NonCodableType {
            let c = try decoder.singleValueContainer()
            let inner = try c.decode(Int.self)
            return NonCodableType(inner: inner)
        }
    }
}

#if FOUNDATION_FRAMEWORK
extension AttributeScopes.TestAttributes.TestIntAttribute : MarkdownDecodableAttributedStringKey {}
extension AttributeScopes.TestAttributes.TestStringAttribute : MarkdownDecodableAttributedStringKey {}
extension AttributeScopes.TestAttributes.TestBoolAttribute : MarkdownDecodableAttributedStringKey {}
extension AttributeScopes.TestAttributes.TestDoubleAttribute : MarkdownDecodableAttributedStringKey {}
#endif // FOUNDATION_FRAMEWORK

struct NonCodableType : Hashable {
    var inner : Int
}

extension AttributeScopes {
    var test: TestAttributes.Type { TestAttributes.self }
    
    struct TestAttributes : AttributeScope {
        var testInt : TestIntAttribute
        var testString : TestStringAttribute
        var testDouble : TestDoubleAttribute
        var testBool : TestBoolAttribute
        var testNonExtended : TestNonExtended
#if compiler(>=6.0)
        var testParagraphConstrained : TestParagraphConstrained
        var testSecondParagraphConstrained : TestSecondParagraphConstrained
        var testCharacterConstrained : TestCharacterConstrained
        var testUnicodeScalarConstrained : TestUnicodeCharacterConstrained
        var testAttributeDependent : TestAttributeDependent
        var testCharacterDependent : TestCharacterDependent
#endif
    }
}

extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.TestAttributes, T>) -> T {
        get { self[T.self] }
    }
}
