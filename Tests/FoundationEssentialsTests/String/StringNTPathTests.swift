//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if os(Windows)

import Testing

#if FOUNDATION_FRAMEWORK
import Foundation
#else
import FoundationEssentials
#endif

@Suite("String NT Path Tests")
struct StringNTPathTests {

    @Test("Normal drive path, no prefix")
    func noPrefix() {
        let path = "C:\\Windows\\System32"
        #expect(path.removingNTPathPrefix() == "C:\\Windows\\System32")
    }

    @Test("Extended-length path prefix (\\\\?\\)")
    func extendedPrefix() {
        let path = #"\\?\C:\Windows\System32"#
        #expect(path.removingNTPathPrefix() == "C:\\Windows\\System32")
    }

    @Test("UNC path with extended prefix (\\\\?\\UNC\\)")
    func uncExtendedPrefix() {
        let path = #"\\?\UNC\Server\Share\Folder"#
        #expect(path.removingNTPathPrefix() == #"\\Server\Share\Folder"#)
    }

    @Test("UNC path without extended prefix")
    func uncNormal() {
        let path = #"\\Server\Share\Folder"#
        #expect(path.removingNTPathPrefix() == #"\\Server\Share\Folder"#)
    }

    @Test("Empty string should stay empty")
    func emptyString() {
        let path = ""
        #expect(path.removingNTPathPrefix() == "")
    }

    @Test("Path with only prefix should return empty")
    func prefixOnly() {
        let path = #"\\?\C:\"#
        #expect(path.removingNTPathPrefix() == #"C:\"#)
    }

    @Test("Path longer than MAX_PATH (260 chars)")
    func longPathBeyondMaxPath() {
        // Create a folder name repeated to exceed 260 chars
        let longComponent = String(repeating: "A", count: 280)
        let rawPath = #"\\?\C:\Test\"# + longComponent

        // After stripping, it should drop the \\?\ prefix but keep the full long component
        let expected = "C:\\Test\\" + longComponent

        let stripped = rawPath.removingNTPathPrefix()
        #expect(stripped == expected)
    }    
}
#endif