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

import Testing

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

@Suite("SortDescriptor")
private struct SortDescriptorTests {
    struct NonNSObjectRoot {
        enum Gadget: Int, Comparable {
            case foo = 0
            case bar = 2
            case baz = 1

            static func < (_ lhs: Self, _ rhs: Self) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }

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

    @Test func none_nsobject_comparable() {
        let forwardComparator = SortDescriptor(\NonNSObjectRoot.gadget)
        let reverseComparator = SortDescriptor(\NonNSObjectRoot.gadget, order: .reverse)

        #expect(
            forwardComparator.compare(NonNSObjectRoot(gadget: .foo), NonNSObjectRoot(gadget: .bar)) == .orderedAscending
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(gadget: .foo), NonNSObjectRoot(gadget: .bar)) == .orderedDescending
        )

        #expect(
            forwardComparator.compare(NonNSObjectRoot(gadget: .bar), NonNSObjectRoot(gadget: .baz)) == .orderedDescending
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(gadget: .bar), NonNSObjectRoot(gadget: .baz)) == .orderedAscending
        )

        #expect(
            forwardComparator.compare(NonNSObjectRoot(gadget: .baz), NonNSObjectRoot(gadget: .baz)) == .orderedSame
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(gadget: .baz), NonNSObjectRoot(gadget: .baz)) == .orderedSame
        )
    }

    @Test func none_nsobject_optional_comparable() {
        let forwardComparator = SortDescriptor(\NonNSObjectRoot.maybeGadget)
        let reverseComparator = SortDescriptor(
            \NonNSObjectRoot.maybeGadget, order: .reverse)

        #expect(
            forwardComparator.compare(NonNSObjectRoot(maybeGadget: .foo), NonNSObjectRoot(maybeGadget: .bar)) == .orderedAscending
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(maybeGadget: .foo), NonNSObjectRoot(maybeGadget: .bar)) == .orderedDescending
        )

        #expect(
            forwardComparator.compare(NonNSObjectRoot(maybeGadget: nil), NonNSObjectRoot(maybeGadget: .bar)) == .orderedAscending
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(maybeGadget: nil), NonNSObjectRoot(maybeGadget: .bar)) == .orderedDescending
        )

        #expect(
            forwardComparator.compare(NonNSObjectRoot(maybeGadget: .bar), NonNSObjectRoot(maybeGadget: .baz)) == .orderedDescending
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(maybeGadget: .bar), NonNSObjectRoot(maybeGadget: .baz)) == .orderedAscending
        )

        #expect(
            forwardComparator.compare(NonNSObjectRoot(maybeGadget: .bar), NonNSObjectRoot(maybeGadget: nil)) == .orderedDescending
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(maybeGadget: .bar), NonNSObjectRoot(maybeGadget: nil)) == .orderedAscending
        )

        #expect(
            forwardComparator.compare(NonNSObjectRoot(maybeGadget: .baz), NonNSObjectRoot(maybeGadget: .baz)) == .orderedSame
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(maybeGadget: .baz), NonNSObjectRoot(maybeGadget: .baz)) == .orderedSame
        )

        #expect(
            forwardComparator.compare(NonNSObjectRoot(maybeGadget: nil), NonNSObjectRoot(maybeGadget: nil)) == .orderedSame
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(maybeGadget: nil), NonNSObjectRoot(maybeGadget: nil)) == .orderedSame
        )
    }

    @Test func none_nsobject_optional_string_comparable() async {
        let forwardComparator = SortDescriptor(\NonNSObjectRoot.maybeWord, comparator: .lexical)
        let reverseComparator = SortDescriptor(\NonNSObjectRoot.maybeWord, comparator: .lexical, order: .reverse)

        #expect(
            forwardComparator.compare(NonNSObjectRoot(maybeWord: "a"), NonNSObjectRoot(maybeWord: "b")) == .orderedAscending
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(maybeWord: "a"), NonNSObjectRoot(maybeWord: "b")) == .orderedDescending
        )

        #expect(
            forwardComparator.compare(NonNSObjectRoot(maybeWord: nil), NonNSObjectRoot(maybeWord: "b")) == .orderedAscending
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(maybeWord: nil), NonNSObjectRoot(maybeWord: "b")) == .orderedDescending
        )

        #expect(
            forwardComparator.compare(NonNSObjectRoot(maybeWord: "a"), NonNSObjectRoot(maybeWord: nil)) == .orderedDescending
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(maybeWord: "a"), NonNSObjectRoot(maybeWord: nil)) == .orderedAscending
        )

        #expect(
            forwardComparator.compare(NonNSObjectRoot(maybeWord: nil), NonNSObjectRoot(maybeWord: nil)) == .orderedSame
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(maybeWord: nil), NonNSObjectRoot(maybeWord: nil)) == .orderedSame
        )
    }

    @Test func none_nsobject_string_comparison() {
        let forwardComparator = SortDescriptor(\NonNSObjectRoot.word, comparator: .lexical)
        let reverseComparator = SortDescriptor(\NonNSObjectRoot.word, comparator: .lexical, order: .reverse)

        #expect(
            forwardComparator.compare(NonNSObjectRoot(word: "a"), NonNSObjectRoot(word: "b")) == .orderedAscending
        )

        #expect(
            reverseComparator.compare(NonNSObjectRoot(word: "a"), NonNSObjectRoot(word: "b")) == .orderedDescending
        )
    }

    @Test(arguments: [
        SortDescriptor(\NonNSObjectRoot.word),
        SortDescriptor(\NonNSObjectRoot.maybeWord),
        SortDescriptor(\NonNSObjectRoot.gadget),
        SortDescriptor(\NonNSObjectRoot.maybeGadget),
    ])
    func encoding_comparable_throws(descriptor: SortDescriptor<NonNSObjectRoot>) {
        let encoder = JSONEncoder()
        #expect(throws: (any Error).self) {
            try encoder.encode(descriptor)
        }
    }

#if FOUNDATION_FRAMEWORK
    // TODO: When String.compare(_:options:locale:) is available in FoundationInternationalization, enable these tests
    // https://github.com/apple/swift-foundation/issues/284
    
    @Test func string_comparator_order() {
        let reverseComparator = {
            var comparator = String.StandardComparator.localized
            comparator.order = .reverse
            return comparator
        }()

        #expect(SortDescriptor(\NonNSObjectRoot.word).order == .forward)

        #expect(SortDescriptor(\NonNSObjectRoot.maybeWord).order == .forward)

        #expect(SortDescriptor(\NonNSObjectRoot.word, comparator: .localized).order == .forward)

        #expect(
            SortDescriptor(\NonNSObjectRoot.maybeWord, comparator: .localized).order == .forward
        )

        #expect(
            SortDescriptor(\NonNSObjectRoot.word, comparator: reverseComparator).order == .reverse
        )

        #expect(
            SortDescriptor(\NonNSObjectRoot.maybeWord, comparator: reverseComparator).order == .reverse
        )

        #expect(
            SortDescriptor(\NonNSObjectRoot.word, comparator: .localized, order: .forward).order == .forward
        )

        #expect(
            SortDescriptor(\NonNSObjectRoot.maybeWord, comparator: .localized, order: .forward).order == .forward
        )

        #expect(
            SortDescriptor(\NonNSObjectRoot.word, comparator: reverseComparator, order: .forward).order == .forward
        )

        #expect(
            SortDescriptor(\NonNSObjectRoot.maybeWord, comparator: reverseComparator, order: .forward).order == .forward
        )

        #expect(
            SortDescriptor(\NonNSObjectRoot.word, comparator: .localized, order: .reverse).order == .reverse
        )

        #expect(
            SortDescriptor(\NonNSObjectRoot.maybeWord, comparator: .localized, order: .reverse).order == .reverse
        )
    }
    
    @Test func string_comparator_property_polarity() {
        #expect(
            SortDescriptor(\NonNSObjectRoot.word).stringComparator?.order == .forward
        )
        #expect(
            SortDescriptor(\NonNSObjectRoot.maybeWord).stringComparator?.order == .forward
        )

        #expect(
            SortDescriptor(\NonNSObjectRoot.word, order: .reverse).stringComparator?.order == .forward
        )
        #expect(
            SortDescriptor(\NonNSObjectRoot.maybeWord, order: .reverse).stringComparator?.order == .forward
        )
    }
#endif

}
