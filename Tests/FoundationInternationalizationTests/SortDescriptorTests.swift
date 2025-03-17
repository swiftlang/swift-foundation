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
import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

class Hello {
    var str: NSMutableString = "hi"
}

@available(*, unavailable)
extension Hello : Sendable {}

final class SortDescriptorTests: XCTestCase {
    struct NonNSObjectRoot {
        enum Gadget: Int, Comparable {
            case foo = 0
            case bar = 2
            case baz = 1

            static func < (_ lhs: Self, _ rhs: Self) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }

        var o = Hello()
        let number: Int
        let word: String
        let maybeWord: String?
        let gadget: Gadget
        let maybeGadget: Gadget?

        init(number: Int = 0, word: String = "", maybeWord: String? = nil, gadget: Gadget = .foo, maybeGadget: Gadget? = nil) {
            self.number = number
            self.word = word
            self.maybeWord = maybeWord
            self.gadget = gadget
            self.maybeGadget = maybeGadget
        }
    }

    func test_none_nsobject_comparable() {
        let forwardComparator = SortDescriptor(\NonNSObjectRoot.gadget)
        let reverseComparator = SortDescriptor(\NonNSObjectRoot.gadget, order: .reverse)

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(gadget: .foo), NonNSObjectRoot(gadget: .bar)),
            .orderedAscending
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(gadget: .foo), NonNSObjectRoot(gadget: .bar)),
            .orderedDescending
        )

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(gadget: .bar), NonNSObjectRoot(gadget: .baz)),
            .orderedDescending
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(gadget: .bar), NonNSObjectRoot(gadget: .baz)),
            .orderedAscending
        )

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(gadget: .baz), NonNSObjectRoot(gadget: .baz)),
            .orderedSame
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(gadget: .baz), NonNSObjectRoot(gadget: .baz)),
            .orderedSame
        )
    }

    func test_none_nsobject_optional_comparable() {
        let forwardComparator = SortDescriptor(\NonNSObjectRoot.maybeGadget)
        let reverseComparator = SortDescriptor(
            \NonNSObjectRoot.maybeGadget, order: .reverse)

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(maybeGadget: .foo), NonNSObjectRoot(maybeGadget: .bar)),
            .orderedAscending
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(maybeGadget: .foo), NonNSObjectRoot(maybeGadget: .bar)),
            .orderedDescending
        )

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(maybeGadget: nil), NonNSObjectRoot(maybeGadget: .bar)),
            .orderedAscending
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(maybeGadget: nil), NonNSObjectRoot(maybeGadget: .bar)),
            .orderedDescending
        )

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(maybeGadget: .bar), NonNSObjectRoot(maybeGadget: .baz)),
            .orderedDescending
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(maybeGadget: .bar), NonNSObjectRoot(maybeGadget: .baz)),
            .orderedAscending
        )

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(maybeGadget: .bar), NonNSObjectRoot(maybeGadget: nil)),
            .orderedDescending
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(maybeGadget: .bar), NonNSObjectRoot(maybeGadget: nil)),
            .orderedAscending
        )

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(maybeGadget: .baz), NonNSObjectRoot(maybeGadget: .baz)),
            .orderedSame
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(maybeGadget: .baz), NonNSObjectRoot(maybeGadget: .baz)),
            .orderedSame
        )

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(maybeGadget: nil), NonNSObjectRoot(maybeGadget: nil)),
            .orderedSame
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(maybeGadget: nil), NonNSObjectRoot(maybeGadget: nil)),
            .orderedSame
        )
    }

    func test_none_nsobject_optional_string_comparable() {
        let forwardComparator = SortDescriptor(\NonNSObjectRoot.maybeWord)
        let reverseComparator = SortDescriptor(\NonNSObjectRoot.maybeWord, order: .reverse)

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(maybeWord: "a"), NonNSObjectRoot(maybeWord: "b")),
            .orderedAscending
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(maybeWord: "a"), NonNSObjectRoot(maybeWord: "b")),
            .orderedDescending
        )

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(maybeWord: nil), NonNSObjectRoot(maybeWord: "b")),
            .orderedAscending
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(maybeWord: nil), NonNSObjectRoot(maybeWord: "b")),
            .orderedDescending
        )

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(maybeWord: "a"), NonNSObjectRoot(maybeWord: nil)),
            .orderedDescending
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(maybeWord: "a"), NonNSObjectRoot(maybeWord: nil)),
            .orderedAscending
        )

        XCTAssertEqual(
            forwardComparator.compare(NonNSObjectRoot(maybeWord: nil), NonNSObjectRoot(maybeWord: nil)),
            .orderedSame
        )

        XCTAssertEqual(
            reverseComparator.compare(NonNSObjectRoot(maybeWord: nil), NonNSObjectRoot(maybeWord: nil)),
            .orderedSame
        )
    }

    func test_none_nsobject_string_comparison() {
        let forwardComparator = SortDescriptor(\NonNSObjectRoot.word)
        let reverseComparator = SortDescriptor(\NonNSObjectRoot.word, order: .reverse)

        XCTAssert(
            forwardComparator.compare(NonNSObjectRoot(word: "a"), NonNSObjectRoot(word: "b")) == .orderedAscending
        )

        XCTAssert(
            reverseComparator.compare(NonNSObjectRoot(word: "a"), NonNSObjectRoot(word: "b")) == .orderedDescending
        )
    }

    func test_encoding_comparable_throws() {
        let descriptors : [SortDescriptor<SortDescriptorTests.NonNSObjectRoot>] = [
            SortDescriptor(\NonNSObjectRoot.word),
            SortDescriptor(\NonNSObjectRoot.maybeWord),
            SortDescriptor(\NonNSObjectRoot.gadget),
            SortDescriptor(\NonNSObjectRoot.maybeGadget),
        ]

        for descriptor in descriptors {
            let encoder = JSONEncoder()
            XCTAssertThrowsError(try encoder.encode(descriptor))
        }
    }

#if FOUNDATION_FRAMEWORK
    // TODO: When String.compare(_:options:locale:) is available in FoundationInternationalization, enable these tests
    // https://github.com/apple/swift-foundation/issues/284
    
    func test_string_comparator_order() {
        let reverseComparator = {
            var comparator = String.StandardComparator.localized
            comparator.order = .reverse
            return comparator
        }()

        XCTAssertEqual(SortDescriptor(\NonNSObjectRoot.word).order, .forward)

        XCTAssertEqual(SortDescriptor(\NonNSObjectRoot.maybeWord).order, .forward)

        XCTAssertEqual(SortDescriptor(\NonNSObjectRoot.word, comparator: .localized).order, .forward)

        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.maybeWord, comparator: .localized).order,
            .forward
        )

        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.word, comparator: reverseComparator).order,
            .reverse
        )

        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.maybeWord, comparator: reverseComparator).order,
            .reverse
        )

        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.word, comparator: .localized, order: .forward).order,
            .forward
        )

        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.maybeWord, comparator: .localized, order: .forward).order,
            .forward
        )

        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.word, comparator: reverseComparator, order: .forward).order,
            .forward
        )

        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.maybeWord, comparator: reverseComparator, order: .forward).order,
            .forward
        )

        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.word, comparator: .localized, order: .reverse).order,
            .reverse
        )

        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.maybeWord, comparator: .localized, order: .reverse).order,
            .reverse
        )
    }
    
    func test_string_comparator_property_polarity() {
        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.word).stringComparator?.order,
            .forward
        )
        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.maybeWord).stringComparator?.order,
            .forward
        )

        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.word, order: .reverse).stringComparator?.order,
            .forward
        )
        XCTAssertEqual(
            SortDescriptor(\NonNSObjectRoot.maybeWord, order: .reverse).stringComparator?.order,
            .forward
        )
    }
#endif

}
