//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
import Foundation
#else
import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

#if FOUNDATION_FRAMEWORK

/// Tests interop with Objective-C `NSSortDescriptor`.
class SortDescriptorConversionTests: XCTestCase {
    @objcMembers class Root: NSObject {
        let word: String
        let number: Int
        let double: Double
        let float: Float
        let int16: Int16
        let int32: Int32
        let int64: Int64
        let uInt8: UInt8
        let uInt16: UInt16
        let uInt32: UInt32
        let uInt64: UInt64
        let uInt: UInt
        let data: Data

        init(
            word: String = "wow",
            number: Int = 1,
            double: Double = 1,
            float: Float = 1,
            int16: Int16 = 1,
            int32: Int32 = 1,
            int64: Int64 = 1,
            uInt8: UInt8 = 1,
            uInt16: UInt16 = 1,
            uInt32: UInt32 = 1,
            uInt64: UInt64 = 1,
            uInt: UInt = 1,
            data: Data = Data()
        ) {
            self.word = word
            self.number = number
            self.double = double
            self.float = float
            self.int16 = int16
            self.int32 = int32
            self.int64 = int64
            self.uInt8 = uInt8
            self.uInt16 = uInt16
            self.uInt32 = uInt32
            self.uInt64 = uInt64
            self.uInt = uInt
            self.data = data
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? Root else { return false }
            return self == other
        }

        static func ==(_ lhs: Root, _ rhs: Root) -> Bool {
            return lhs.word == rhs.word &&
                lhs.number == rhs.number &&
                lhs.double == rhs.double &&
                lhs.float == rhs.float &&
                lhs.int16 == rhs.int16 &&
                lhs.int32 == rhs.int32 &&
                lhs.int64 == rhs.int64 &&
                lhs.uInt == rhs.uInt &&
                lhs.data == rhs.data
        }
    }

    func test_sortdescriptor_to_nssortdescriptor_selector_conversion() {
        let localizedStandard = SortDescriptor(\Root.word, comparator: .localizedStandard)
        let localized = SortDescriptor(\Root.word, comparator: .localized)
        let lexical = SortDescriptor(\Root.word, comparator: .lexical)
        let nsLocalizedStandard = NSSortDescriptor(localizedStandard)
        let nsLocalized = NSSortDescriptor(localized)
        let nsLexical = NSSortDescriptor(lexical)
        
        XCTAssert(nsLocalizedStandard.selector != nil)
        XCTAssertEqual(NSStringFromSelector(nsLocalizedStandard.selector!), "localizedStandardCompare:")
        XCTAssert(nsLocalized.selector != nil)
        XCTAssertEqual(NSStringFromSelector(nsLocalized.selector!), "localizedCompare:")
        XCTAssert(nsLexical.selector != nil)
        XCTAssertEqual(NSStringFromSelector(nsLexical.selector!), "compare:")

        let compareBased: [SortDescriptor<Root>] = [
            .init(\.word, comparator: .lexical),
            .init(\.double),
            .init(\.float),
            .init(\.int16),
            .init(\.int32),
            .init(\.int64),
            .init(\.number),
            .init(\.uInt16),
            .init(\.uInt32),
            .init(\.uInt64),
            .init(\.uInt),
        ]

        for descriptor in compareBased {
            let nsDescriptor = NSSortDescriptor(descriptor)
            XCTAssert(nsDescriptor.selector != nil)
            XCTAssertEqual(NSStringFromSelector(nsDescriptor.selector!), "compare:")
        }
    }

    func test_sortdescriptor_to_nssortdescriptor_order_conversion() {
        let forward = SortDescriptor(\Root.number, order: .forward)
        let reverse = SortDescriptor(\Root.number, order: .reverse)
        let nsAscending = NSSortDescriptor(forward)
        let nsDescending = NSSortDescriptor(reverse)
        XCTAssert(nsAscending.ascending)
        XCTAssertFalse(nsDescending.ascending)
    }

    func test_nssortdescriptor_to_sortdescriptor_conversion() {
        let intDescriptor = NSSortDescriptor(keyPath: \Root.number, ascending: true)
        XCTAssertEqual(SortDescriptor(intDescriptor, comparing: Root.self), SortDescriptor(\Root.number))

        let stringDescriptor = NSSortDescriptor(keyPath: \Root.word, ascending: true)
        XCTAssertEqual(SortDescriptor(stringDescriptor, comparing: Root.self), SortDescriptor(\Root.word, comparator: .lexical))

        // test custom string selector conversion
        let localizedStandard = NSSortDescriptor(key: "word", ascending: true, selector: #selector(NSString.localizedStandardCompare))
        XCTAssertEqual(SortDescriptor(localizedStandard, comparing: Root.self), SortDescriptor(\Root.word))

        let localized = NSSortDescriptor(key: "word", ascending: true, selector: #selector(NSString.localizedCompare))
        XCTAssertEqual(SortDescriptor(localized, comparing: Root.self), SortDescriptor(\Root.word, comparator: .localized))
    }

    func test_nssortdescriptor_to_sortdescriptor_conversion_failure() {
        let ascending = NSSortDescriptor(keyPath: \Root.word, ascending: true)
        let descending = NSSortDescriptor(keyPath: \Root.word, ascending: false)
        guard let forward = SortDescriptor(ascending, comparing: Root.self) else {
            XCTFail()
            return
        }
        
        guard let reverse = SortDescriptor(descending, comparing: Root.self) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(forward.order, .forward)
        XCTAssertEqual(reverse.order, .reverse)
    }
    
    func test_conversion_from_uninitializable_descriptor() throws {
        let nsDesc = NSSortDescriptor(key: "data", ascending: true)
        let desc = try XCTUnwrap(SortDescriptor(nsDesc, comparing: Root.self))

        //` NSSortDescriptor`s pointing to `Data` support equality, but not
        // full comparison so we should be able to get a same result. Anything
        // else will crash.
        let compareResult = desc.compare(Root(), Root())
        XCTAssertEqual(compareResult, .orderedSame)
    }
    
    func test_conversion_from_invalid_descriptor() throws {
        let localizedCaseInsensitive = NSSortDescriptor(key: "word", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare))
        let caseInsensitive = NSSortDescriptor(key: "word", ascending: true, selector: #selector(NSString.caseInsensitiveCompare))
        let caseInsensitiveNumeric = NSSortDescriptor(key: "word", ascending: true, selector: Selector(("_caseInsensitiveNumericCompare:")))
        XCTAssertNil(SortDescriptor(localizedCaseInsensitive, comparing: Root.self))
        XCTAssertNil(SortDescriptor(caseInsensitive, comparing: Root.self))
        XCTAssertNil(SortDescriptor(caseInsensitiveNumeric, comparing: Root.self))
    }
    
    func test_key_path_optionality() {
        XCTAssertNotNil(SortDescriptor(\SortDescriptorTests.NonNSObjectRoot.word).keyPath)
        XCTAssertNotNil(SortDescriptor(\SortDescriptorTests.NonNSObjectRoot.maybeWord).keyPath)
        XCTAssertNotNil(SortDescriptor(\SortDescriptorTests.NonNSObjectRoot.gadget).keyPath)
        XCTAssertNotNil(SortDescriptor(\SortDescriptorTests.NonNSObjectRoot.maybeGadget).keyPath)

        XCTAssertNil(SortDescriptor(\Root.word).keyPath)
        XCTAssertNil(SortDescriptor(\Root.number).keyPath)

        let ns = NSSortDescriptor(key: "number", ascending: true)
        XCTAssertNil(SortDescriptor(ns, comparing: Root.self)!.keyPath)
    }

    func test_string_comparator_optionality() {
        XCTAssertNotNil(SortDescriptor(\SortDescriptorTests.NonNSObjectRoot.word).stringComparator)
        XCTAssertNotNil(SortDescriptor(\SortDescriptorTests.NonNSObjectRoot.maybeWord).stringComparator)
        XCTAssertNil(SortDescriptor(\SortDescriptorTests.NonNSObjectRoot.gadget).stringComparator)
        XCTAssertNil(SortDescriptor(\SortDescriptorTests.NonNSObjectRoot.maybeGadget).stringComparator)

        XCTAssertNotNil(SortDescriptor(\Root.word).stringComparator)
        XCTAssertNil(SortDescriptor(\Root.number).stringComparator)

        let ns = NSSortDescriptor(key: "word", ascending: true)
        XCTAssertNil(SortDescriptor(ns, comparing: Root.self)!.stringComparator)
    }
    
    func test_ordering() {
        let forwardInt = SortDescriptor(\Root.number)
        XCTAssertEqual(forwardInt.compare(Root(number: 3), Root(number: 4)), ComparisonResult.orderedAscending)
        XCTAssertEqual(forwardInt.compare(Root(number: 4), Root(number: 3)), .orderedDescending)
        let reverseInt = SortDescriptor(\Root.number, order: .reverse)
        XCTAssertEqual(reverseInt.compare(Root(number: 3), Root(number: 4)), .orderedDescending)
        XCTAssertEqual(reverseInt.compare(Root(number: 4), Root(number: 3)), .orderedAscending)
    }

    func test_mutable_order() {
        var intComparator = SortDescriptor(\Root.number)
        XCTAssertEqual(intComparator.compare(Root(number: 3), Root(number: 4)), .orderedAscending)
        intComparator.order = .reverse
        XCTAssertEqual(intComparator.compare(Root(number: 3), Root(number: 4)), .orderedDescending)
    }

    func test_default_comparator() {
        let stringComparator = SortDescriptor(\Root.word)
        XCTAssertEqual(stringComparator.comparison, .compareString(.localizedStandard))
        let intDescriptor = SortDescriptor(\Root.number)
        let intCompare = intDescriptor.comparison
        XCTAssertEqual(intCompare, .compare)
    }

    func test_sorting_by_keypath_comparator() {
        let a = SortDescriptor(\Root.word)
        let b = SortDescriptor(\Root.number)
        let c = SortDescriptor(\Root.float, order: .reverse)

        let items: [Root] = [
            Root(word: "d", number: 10),
            Root(word: "b", number: -10),
            Root(word: "a", number: 0),
            Root(word: "d", number: 10, float: 10),
            Root(word: "d", number: 20),
            Root(word: "d", number: 5),
            Root(word: "c", number: 500),
        ]

        let expectedA: [Root] = [
            Root(word: "a", number: 0),
            Root(word: "b", number: -10),
            Root(word: "c", number: 500),
            Root(word: "d", number: 10),
            Root(word: "d", number: 10, float: 10),
            Root(word: "d", number: 20),
            Root(word: "d", number: 5),
        ]

        let expectedAB: [Root] = [
            Root(word: "a", number: 0),
            Root(word: "b", number: -10),
            Root(word: "c", number: 500),
            Root(word: "d", number: 5),
            Root(word: "d", number: 10),
            Root(word: "d", number: 10, float: 10),
            Root(word: "d", number: 20),
        ]

        let expectedABC: [Root] = [
            Root(word: "a", number: 0),
            Root(word: "b", number: -10),
            Root(word: "c", number: 500),
            Root(word: "d", number: 5),
            Root(word: "d", number: 10, float: 10),
            Root(word: "d", number: 10),
            Root(word: "d", number: 20),
        ]

        XCTAssertEqual(items.sorted(using: a), expectedA)
        XCTAssertEqual(items.sorted(using: [a, b]), expectedAB)
        XCTAssertEqual(items.sorted(using: [a, b, c]), expectedABC)
    }

    func test_codability() throws {
        let descriptor = SortDescriptor(\Root.word, comparator: .localizedStandard)
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(descriptor)
        let decoder = JSONDecoder()
        let reconstructed = try decoder.decode(SortDescriptor<Root>.self, from: encoded)
        XCTAssertEqual(descriptor, reconstructed)

        // ensure the comparison still works after reconstruction
        XCTAssertEqual(reconstructed.compare(Root(word: "a"), Root(word: "b")), .orderedAscending)
    }

    func test_decoding_dissallow_invaled() throws {
        var otherLocale: Locale {
            let attempt = Locale(identifier: "ta")
            if Locale.current == attempt {
                return Locale(identifier: "en_US")
            }
            return attempt
        }

        let encoder = JSONEncoder()
        let localeStr = String(data: try encoder.encode(Locale.current), encoding: .utf8)!
        let otherLocaleStr = String(data: try encoder.encode(otherLocale), encoding: .utf8)!

        let invalidRawValue = """
        {
            "order": true,
            "keyString": "word",
            "comparison": {
                "rawValue": 2131,
                "stringComparator": {
                    "options": 1,
                    "locale": \(localeStr),
                    "order": true
                }
            }
        }
        """.data(using: .utf8)!

        let nonStandardComparator = """
        {
            "order": true,
            "keyString": "word",
            "comparison": {
                "rawValue": 13,
                "stringComparator": {
                    "options": 8,
                    "locale": \(localeStr),
                    "order": true
                }
            }
        }
        """.data(using: .utf8)!

        let nonStandardLocale = """
        {
            "order": true,
            "keyString": "word",
            "comparison": {
                "rawValue": 13,
                "stringComparator": {
                    "options": 8,
                    "locale": \(otherLocaleStr),
                    "order": true
                }
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()

        do {
            let _ = try decoder.decode(SortDescriptor<Root>.self, from: invalidRawValue)
            XCTFail()
        } catch {}

        do {
            let _ = try decoder.decode(SortDescriptor<Root>.self, from: nonStandardComparator)
            XCTFail()
        } catch {}

        do {
            let _ = try decoder.decode(SortDescriptor<Root>.self, from: nonStandardLocale)
            XCTFail()
        } catch {}
    }
    
    func test_string_comparator_property_polarity() {
        // `.stringComparator?.order` should always be `.forward` regardless
        // of the value of `SortDescriptor().order`
        XCTAssertEqual(
            SortDescriptor(\Root.word).stringComparator?.order,
            .forward
        )
        
        XCTAssertEqual(
            SortDescriptor(\Root.word, order: .reverse).stringComparator?.order,
            .forward
        )
    }

}

#endif // FOUNDATION_FRAMEWORK
