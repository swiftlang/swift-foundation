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

#if canImport(TestSupport)
import TestSupport
#endif

final class AttributedStringIndexTrackingTests: XCTestCase {
    func testBasic() throws {
        var text = AttributedString("ABC. Hello, world!")
        let original = text
        let helloRange = try XCTUnwrap(text.range(of: "Hello"))
        let worldRange = try XCTUnwrap(text.range(of: "world"))
        
        let updatedRanges = try XCTUnwrap(text.transform(updating: [helloRange, worldRange]) {
            $0.insert(AttributedString("Goodbye. "), at: $0.startIndex)
        })
        
        XCTAssertEqual(updatedRanges.count, 2)
        XCTAssertEqual(text[updatedRanges[0]], original[helloRange])
        XCTAssertEqual(text[updatedRanges[1]], original[worldRange])
    }
    
    func testInsertionWithinRange() throws {
        var text = AttributedString("Hello, world")
        let helloRange = try XCTUnwrap(text.range(of: "Hello"))
        
        let updatedRange = try XCTUnwrap(text.transform(updating: helloRange) {
            $0.insert(AttributedString("_Goodbye_"), at: $0.index($0.startIndex, offsetByCharacters: 3))
        })
        
        XCTAssertEqual(String(text[updatedRange].characters), "Hel_Goodbye_lo")
    }
    
    func testInsertionAtStartOfRange() throws {
        var text = AttributedString("Hello, world")
        let helloRange = try XCTUnwrap(text.range(of: "llo"))
        
        let updatedRange = try XCTUnwrap(text.transform(updating: helloRange) {
            $0.insert(AttributedString("_"), at: helloRange.lowerBound)
        })
        
        XCTAssertEqual(String(text[updatedRange].characters), "llo")
    }
    
    func testInsertionAtEndOfRange() throws {
        var text = AttributedString("Hello, world")
        let helloRange = try XCTUnwrap(text.range(of: "llo"))
        
        let updatedRange = try XCTUnwrap(text.transform(updating: helloRange) {
            $0.insert(AttributedString("_"), at: helloRange.upperBound)
        })
        
        XCTAssertEqual(String(text[updatedRange].characters), "llo")
    }
    
    func testInsertionAtEmptyRange() throws {
        var text = AttributedString("ABCDE")
        let idx = text.index(text.startIndex, offsetByCharacters: 3)
        
        let updatedRange = try XCTUnwrap(text.transform(updating: idx ..< idx) {
            $0.insert(AttributedString("_"), at: idx)
        })
        
        XCTAssertEqual(updatedRange.lowerBound, updatedRange.upperBound)
        XCTAssertEqual(text.characters[updatedRange.lowerBound], "D")
    }
    
    func testRemovalWithinRange() throws {
        var text = AttributedString("Hello, world")
        let helloRange = try XCTUnwrap(text.range(of: "Hello"))
        
        let updatedRange = try XCTUnwrap(text.transform(updating: helloRange) {
            $0.removeSubrange(try XCTUnwrap($0.range(of: "ll")))
        })
        
        XCTAssertEqual(String(text[updatedRange].characters), "Heo")
    }
    
    func testFullCollapse() throws {
        do {
            var text = AttributedString("Hello, world")
            let helloRange = try XCTUnwrap(text.range(of: "Hello"))
            
            let updatedRange = try XCTUnwrap(text.transform(updating: helloRange) {
                $0.removeSubrange($0.startIndex ..< $0.endIndex)
            })
            
            XCTAssertEqual(String(text[updatedRange].characters), "")
        }
        
        do {
            var text = AttributedString("Hello, world")
            let helloRange = try XCTUnwrap(text.range(of: "Hello"))
            
            let updatedRange = try XCTUnwrap(text.transform(updating: helloRange) {
                $0.removeSubrange(helloRange)
            })
            
            XCTAssertEqual(String(text[updatedRange].characters), "")
        }
        
        do {
            var text = AttributedString("Hello, world")
            let helloRange = try XCTUnwrap(text.range(of: ", "))
            
            let updatedRange = try XCTUnwrap(text.transform(updating: helloRange) {
                $0.removeSubrange(try XCTUnwrap($0.range(of: "o, w")))
            })
            
            XCTAssertEqual(String(text[updatedRange].characters), "")
            let collapsedIdx = text.index(text.startIndex, offsetByCharacters: 4)
            XCTAssertEqual(updatedRange, collapsedIdx ..< collapsedIdx)
        }
    }
    
    func testCollapseLeft() throws {
        var text = AttributedString("Hello, world")
        let helloRange = try XCTUnwrap(text.range(of: "Hello"))
        
        let updatedRange = try XCTUnwrap(text.transform(updating: helloRange) {
            $0.removeSubrange(try XCTUnwrap($0.range(of: "llo, wo")))
        })
        
        XCTAssertEqual(String(text[updatedRange].characters), "He")
    }
    
    func testCollapseRight() throws {
        var text = AttributedString("Hello, world")
        let worldRange = try XCTUnwrap(text.range(of: "world"))
        
        let updatedRange = try XCTUnwrap(text.transform(updating: worldRange) {
            $0.removeSubrange(try XCTUnwrap($0.range(of: "llo, wo")))
        })
        
        XCTAssertEqual(String(text[updatedRange].characters), "rld")
    }
    
    func testNesting() throws {
        var text = AttributedString("Hello, world")
        let helloRange = try XCTUnwrap(text.range(of: "Hello"))
        let updatedHelloRange = try XCTUnwrap(text.transform(updating: [helloRange]) {
            let worldRange = try XCTUnwrap($0.range(of: "world"))
            let updatedWorldRange = try XCTUnwrap($0.transform(updating: [worldRange]) {
                $0.removeSubrange(try XCTUnwrap($0.range(of: "llo, wo")))
            })
            XCTAssertEqual(updatedWorldRange.count, 1)
            XCTAssertEqual(String($0[updatedWorldRange[0]].characters), "rld")
        })
        XCTAssertEqual(updatedHelloRange.count, 1)
        XCTAssertEqual(String(text[updatedHelloRange[0]].characters), "He")
    }
    
    func testTrackingLost() throws {
        let text = AttributedString("Hello, world")
        let helloRange = try XCTUnwrap(text.range(of: "Hello"))
        
        do {
            var copy = text
            XCTAssertNil(copy.transform(updating: helloRange) {
                $0 = AttributedString("Foo")
            })
        }
        
        do {
            var copy = text
            XCTAssertNil(copy.transform(updating: helloRange) {
                $0 = AttributedString("Hello world")
            })
        }
        
        do {
            var copy = text
            XCTAssertNotNil(copy.transform(updating: helloRange) {
                $0 = $0
            })
        }
        
        do {
            var copy = text
            XCTAssertNotNil(copy.transform(updating: helloRange) {
                var reference = $0
                reference.testInt = 2
                $0 = $0
            })
            XCTAssertNil(copy.testInt)
        }
    }
    
    func testAttributeMutation() throws {
        var text = AttributedString("Hello, world!")
        let original = text
        let helloRange = try XCTUnwrap(text.range(of: "Hello"))
        let worldRange = try XCTUnwrap(text.range(of: "world"))
        
        let updatedRanges = try XCTUnwrap(text.transform(updating: [helloRange, worldRange]) {
            $0.testInt = 2
        })
        
        XCTAssertEqual(updatedRanges.count, 2)
        XCTAssertEqual(AttributedString(text[updatedRanges[0]]), original[helloRange].settingAttributes(AttributeContainer.testInt(2)))
        XCTAssertEqual(AttributedString(text[updatedRanges[1]]), original[worldRange].settingAttributes(AttributeContainer.testInt(2)))
    }
}