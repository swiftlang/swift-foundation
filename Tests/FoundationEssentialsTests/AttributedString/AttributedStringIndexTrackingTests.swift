//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("AttributedString Index Tracking")
private struct AttributedStringIndexTrackingTests {
    @available(FoundationAttributedString 5.5, *)
    @Test func basics() throws {
        var text = AttributedString("ABC. Hello, world!")
        let original = text
        let helloRange = try #require(text.range(of: "Hello"))
        let worldRange = try #require(text.range(of: "world"))
        
        let updatedRanges = try #require(text.transform(updating: [helloRange, worldRange]) {
            $0.insert(AttributedString("Goodbye. "), at: $0.startIndex)
        })
        
        #expect(updatedRanges.count == 2)
        #expect(text[updatedRanges[0]] == original[helloRange])
        #expect(text[updatedRanges[1]] == original[worldRange])
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func insertionWithinRange() throws {
        var text = AttributedString("Hello, world")
        var helloRange = try #require(text.range(of: "Hello"))
        
        text.transform(updating: &helloRange) {
            $0.insert(AttributedString("_Goodbye_"), at: $0.index($0.startIndex, offsetByCharacters: 3))
        }
        
        #expect(String(text[helloRange].characters) == "Hel_Goodbye_lo")
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func insertionAtStartOfRange() throws {
        var text = AttributedString("Hello, world")
        let helloRange = try #require(text.range(of: "llo"))
        
        let updatedHelloRange = try #require(text.transform(updating: helloRange) {
            $0.insert(AttributedString("_"), at: helloRange.lowerBound)
        })
        
        #expect(String(text[updatedHelloRange].characters) == "llo")
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func insertionAtEndOfRange() throws {
        var text = AttributedString("Hello, world")
        let helloRange = try #require(text.range(of: "llo"))
        
        let updatedHelloRange = try #require(text.transform(updating: helloRange) {
            $0.insert(AttributedString("_"), at: helloRange.upperBound)
        })
        
        #expect(String(text[updatedHelloRange].characters) == "llo")
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func insertionAtEmptyRange() throws {
        var text = AttributedString("ABCDE")
        let idx = text.index(text.startIndex, offsetByCharacters: 3)
        
        let updatedRange = try #require(text.transform(updating: idx ..< idx) {
            $0.insert(AttributedString("_"), at: idx)
        })
        
        #expect(updatedRange.lowerBound == updatedRange.upperBound)
        #expect(text.characters[updatedRange.lowerBound] == "D")
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func removalWithinRange() throws {
        var text = AttributedString("Hello, world")
        var helloRange = try #require(text.range(of: "Hello"))
        
        try text.transform(updating: &helloRange) {
            $0.removeSubrange(try #require($0.range(of: "ll")))
        }
        
        #expect(String(text[helloRange].characters) == "Heo")
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func fullCollapse() throws {
        do {
            var text = AttributedString("Hello, world")
            var helloRange = try #require(text.range(of: "Hello"))
            
            text.transform(updating: &helloRange) {
                $0.removeSubrange($0.startIndex ..< $0.endIndex)
            }
            
            #expect(String(text[helloRange].characters) == "")
        }
        
        do {
            var text = AttributedString("Hello, world")
            let helloRange = try #require(text.range(of: "Hello"))
            
            let updatedHelloRange = try #require(text.transform(updating: helloRange) {
                $0.removeSubrange(helloRange)
            })
            
            #expect(String(text[updatedHelloRange].characters) == "")
        }
        
        do {
            var text = AttributedString("Hello, world")
            var helloRange = try #require(text.range(of: ", "))
            
            try text.transform(updating: &helloRange) {
                $0.removeSubrange(try #require($0.range(of: "o, w")))
            }
            
            #expect(String(text[helloRange].characters) == "")
            let collapsedIdx = text.index(text.startIndex, offsetByCharacters: 4)
            #expect(helloRange == collapsedIdx ..< collapsedIdx)
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func collapseLeft() throws {
        var text = AttributedString("Hello, world")
        var helloRange = try #require(text.range(of: "Hello"))
        
        try text.transform(updating: &helloRange) {
            $0.removeSubrange(try #require($0.range(of: "llo, wo")))
        }
        
        #expect(String(text[helloRange].characters) == "He")
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func collapseRight() throws {
        var text = AttributedString("Hello, world")
        var worldRange = try #require(text.range(of: "world"))
        
        try text.transform(updating: &worldRange) {
            $0.removeSubrange(try #require($0.range(of: "llo, wo")))
        }
        
        #expect(String(text[worldRange].characters) == "rld")
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func nesting() throws {
        var text = AttributedString("Hello, world")
        var helloRange = try #require(text.range(of: "Hello"))
        try text.transform(updating: &helloRange) {
            var worldRange = try #require($0.range(of: "world"))
            try $0.transform(updating: &worldRange) {
                $0.removeSubrange(try #require($0.range(of: "llo, wo")))
            }
            #expect(String($0[worldRange].characters) == "rld")
        }
        #expect(String(text[helloRange].characters) == "He")
    }
    
    #if FOUNDATION_EXIT_TESTS
    @available(FoundationAttributedString 5.5, *)
    @Test func trackingLostPreconditions() async {
        await #expect(processExitsWith: .failure) {
            var text = AttributedString("Hello, world")
            var helloRange = try #require(text.range(of: "Hello"))
            text.transform(updating: &helloRange) {
                $0 = AttributedString("Foo")
            }
        }
        
        await #expect(processExitsWith: .failure) {
            var text = AttributedString("Hello, world")
            var helloRange = try #require(text.range(of: "Hello"))
            text.transform(updating: &helloRange) {
                $0 = AttributedString("Hello world")
            }
        }
        
        await #expect(processExitsWith: .failure) {
            var text = AttributedString("Hello, world")
            var ranges = [try #require(text.range(of: "Hello"))]
            text.transform(updating: &ranges) {
                $0 = AttributedString("Foo")
            }
        }
        
        await #expect(processExitsWith: .failure) {
            var text = AttributedString("Hello, world")
            var ranges = [try #require(text.range(of: "Hello"))]
            text.transform(updating: &ranges) {
                $0 = AttributedString("Hello world")
            }
        }
    }
    #endif
    
    @available(FoundationAttributedString 5.5, *)
    @Test func trackingLost() throws {
        let text = AttributedString("Hello, world")
        let helloRange = try #require(text.range(of: "Hello"))
        
        do {
            var copy = text
            #expect(copy.transform(updating: helloRange) {
                $0 = AttributedString("Foo")
            } == nil)
        }
        
        do {
            var copy = text
            #expect(copy.transform(updating: helloRange) {
                $0 = AttributedString("Hello world")
            } == nil)
        }
        
        do {
            var copy = text
            #expect(copy.transform(updating: helloRange) {
                $0 = $0
            } != nil)
        }
        
        do {
            var copy = text
            #expect(copy.transform(updating: helloRange) {
                var reference = $0
                reference.testInt = 2
                $0 = $0
            } != nil)
            #expect(copy.testInt == nil)
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func attributeMutation() throws {
        var text = AttributedString("Hello, world!")
        let original = text
        let helloRange = try #require(text.range(of: "Hello"))
        let worldRange = try #require(text.range(of: "world"))
        
        let updatedRanges = try #require(text.transform(updating: [helloRange, worldRange]) {
            $0.testInt = 2
        })
        
        #expect(updatedRanges.count == 2)
        #expect(AttributedString(text[updatedRanges[0]]) == original[helloRange].settingAttributes(AttributeContainer.testInt(2)))
        #expect(AttributedString(text[updatedRanges[1]]) == original[worldRange].settingAttributes(AttributeContainer.testInt(2)))
    }
    
    #if FOUNDATION_EXIT_TESTS
    @available(FoundationAttributedString 5.5, *)
    @Test func invalidInputRanges() async {
        await #expect(processExitsWith: .failure) {
            var text = AttributedString("Hello, world")
            let other = text + AttributedString("Extra text")
            let range = other.startIndex ..< other.endIndex
            _ = text.transform(updating: range) { _ in
                
            }
        }
        
        await #expect(processExitsWith: .failure) {
            var text = AttributedString("Hello, world")
            let other = text + AttributedString("Extra text")
            let range = other.endIndex ..< other.endIndex
            _ = text.transform(updating: range) { _ in
                
            }
        }
        
        await #expect(processExitsWith: .failure) {
            var text = AttributedString("Hello, world")
            _ = text.transform(updating: []) { _ in
                
            }
        }
    }
    #endif
}
