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

import Testing

#if canImport(FoundationEssentials) && !FOUNDATION_FRAMEWORK
@_spi(SwiftCorelibsFoundation) import FoundationEssentials

@Suite("PropertyListSerialization")
private struct PropertyListSerializationTests {
    private struct Sample : Encodable {
        var string = "héllo €"
        var ascii = "plain"
        var negative = -42
        var unsigned: UInt64 = .max
        var real = 1.5
        var bool = true
        var date = Date(timeIntervalSinceReferenceDate: 1000)
        var data = Data([1, 2, 3])
        var array = ["a", "plain", "a"]
        var nested = ["k": 7]
        var nullString = "$null"
    }

    private func read(_ data: Data, options: PropertyListSerialization.ReadOptions = []) throws -> (value: Any, format: PropertyListSerialization.PropertyListFormat) {
        var format = PropertyListSerialization.PropertyListFormat.binary
        let value = try PropertyListSerialization.propertyList(from: data, options: options, format: &format)
        return (value, format)
    }

    private func read(_ string: String) throws -> (value: Any, format: PropertyListSerialization.PropertyListFormat) {
        try read(Data(string.utf8))
    }

    private func xml(_ body: String, encoding: String = "UTF-8") -> String {
        "<?xml version=\"1.0\" encoding=\"\(encoding)\"?><plist version=\"1.0\">\(body)</plist>"
    }

    /// A binary property list with `objects` in order, each one the bytes of one object. Object references and offsets are one byte, so the whole property list must be shorter than 256 bytes.
    private func bplist(_ objects: [[UInt8]], top: UInt8 = 0) -> Data {
        var bytes = Array("bplist00".utf8)
        var offsets: [UInt8] = []
        for object in objects {
            offsets.append(UInt8(bytes.count))
            bytes += object
        }
        let offsetTableOffset = UInt8(bytes.count)
        bytes += offsets
        // Trailer: 6 unused bytes, offset size, reference size, object count, top object, offset table offset.
        bytes += [0, 0, 0, 0, 0, 0, 1, 1]
        bytes += [0, 0, 0, 0, 0, 0, 0, UInt8(objects.count)]
        bytes += [0, 0, 0, 0, 0, 0, 0, top]
        bytes += [0, 0, 0, 0, 0, 0, 0, offsetTableOffset]
        return Data(bytes)
    }

    private func expectReadCorrupt(_ data: Data, sourceLocation: SourceLocation = #_sourceLocation) {
        let error = #expect(throws: CocoaError.self, sourceLocation: sourceLocation) {
            _ = try read(data)
        }
        #expect(error?.code == .propertyListReadCorrupt, sourceLocation: sourceLocation)
    }

    @Test(arguments: [PropertyListSerialization.PropertyListFormat.binary, .xml])
    func valuesFromEncoder(format: PropertyListSerialization.PropertyListFormat) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = format
        let result = try read(try encoder.encode(Sample()))
        #expect(result.format == format)

        let dictionary = try #require(result.value as? [String : Any])
        #expect(dictionary.count == 11)
        #expect(dictionary["string"] as? String == "héllo €")
        #expect(dictionary["ascii"] as? String == "plain")
        #expect(dictionary["negative"] as? Int == -42)
        #expect(dictionary["unsigned"] as? UInt64 == .max)
        #expect(dictionary["real"] as? Double == 1.5)
        #expect(dictionary["bool"] as? Bool == true)
        #expect(dictionary["date"] as? Date == Date(timeIntervalSinceReferenceDate: 1000))
        #expect(dictionary["data"] as? Data == Data([1, 2, 3]))
        #expect(dictionary["array"] as? [String] == ["a", "plain", "a"])
        #expect((dictionary["nested"] as? [String : Any])?["k"] as? Int == 7)
        #expect(dictionary["nullString"] as? String == "$null")
    }

    @Test func openStep() throws {
        let result = try read("{ a = b; list = (one, \"two words\"); data = <0102>; }")
        #expect(result.format == .openStep)
        let dictionary = try #require(result.value as? [String : Any])
        #expect(dictionary["a"] as? String == "b")
        #expect(dictionary["list"] as? [String] == ["one", "two words"])
        #expect(dictionary["data"] as? Data == Data([1, 2]))
    }

    @Test func topLevelScalar() throws {
        let result = try read(xml("<string>top</string>"))
        #expect(result.format == .xml)
        #expect(result.value as? String == "top")

        #expect(try read(bplist([[0x10, 0x07]])).value as? Int == 7)
    }

    @Test func xmlDuplicateKeysKeepLastValue() throws {
        let result = try read(xml("<dict><key>a</key><integer>1</integer><key>a</key><integer>2</integer></dict>"))
        #expect((result.value as? [String : Any])?["a"] as? Int == 2)
    }

    @Test func binaryDuplicateKeysKeepFirstValue() throws {
        // {"a": 1, "a": 2}, with each key a separate object.
        let data = bplist([
            [0xD2, 1, 2, 3, 4],
            [0x51, UInt8(ascii: "a")],
            [0x51, UInt8(ascii: "a")],
            [0x10, 0x01],
            [0x10, 0x02],
        ])
        #expect((try read(data).value as? [String : Any])?["a"] as? Int == 1)
    }

    @Test func nullIsString() throws {
        let xmlResult = try read(xml("<array><string>$null</string></array>"))
        #expect(xmlResult.value as? [String] == ["$null"])

        // [null]
        let binaryResult = try read(bplist([[0xA1, 1], [0x00]]))
        #expect(binaryResult.value as? [String] == ["$null"])
    }

    @Test func binarySetIsError() {
        // A set with one integer.
        expectReadCorrupt(bplist([[0xC1, 1], [0x10, 0x05]]))
    }

    @Test func keyedArchiverUID() throws {
        let xmlResult = try read(xml("<dict><key>u</key><dict><key>CF$UID</key><integer>5</integer></dict></dict>"))
        #expect((xmlResult.value as? [String : Any])?["u"] as? _PropertyListUID == _PropertyListUID(value: 5))

        // {"u": UID(5)}
        let binaryResult = try read(bplist([[0xD1, 1, 2], [0x51, UInt8(ascii: "u")], [0x80, 0x05]]))
        #expect((binaryResult.value as? [String : Any])?["u"] as? _PropertyListUID == _PropertyListUID(value: 5))
    }

    @Test func integerLimits() throws {
        let result = try read(xml("<array><integer>18446744073709551615</integer><integer>-9223372036854775808</integer><integer>9223372036854775807</integer></array>"))
        let array = try #require(result.value as? [Any])
        #expect(array[0] as? UInt64 == .max)
        #expect(array[1] as? Int == .min)
        #expect(array[2] as? Int == .max)
    }

    @Test func utf16XMLWithByteOrderMark() throws {
        let text = xml("<string>héllo</string>", encoding: "UTF-16")
        var bytes: [UInt8] = [0xFF, 0xFE]
        for unit in text.utf16 {
            bytes.append(UInt8(truncatingIfNeeded: unit))
            bytes.append(UInt8(truncatingIfNeeded: unit >> 8))
        }
        let result = try read(Data(bytes))
        #expect(result.format == .xml)
        #expect(result.value as? String == "héllo")
    }

    @Test func mutabilityOptionsHaveNoEffect() throws {
        let data = Data(xml("<dict><key>a</key><array><string>b</string></array></dict>").utf8)
        for options: PropertyListSerialization.ReadOptions in [[], .mutableContainers, .mutableContainersAndLeaves] {
            let value = try read(data, options: options).value
            #expect((value as? [String : Any])?["a"] as? [String] == ["b"])
        }
    }

    @Test func binaryASCIIStringIsStrictUTF8() throws {
        // {"\u{E9}": ...}, with an ASCII string object that holds the valid UTF-8 bytes of U+00E9.
        let data = bplist([[0xD1, 1, 2], [0x52, 0xC3, 0xA9], [0x51, 0x61]])
        let dictionary = try #require(try read(data).value as? [String : Any])
        #expect(dictionary["\u{E9}"] as? String == "a")

        // A lone 0xE9 is not valid UTF-8.
        expectReadCorrupt(bplist([[0x51, 0xE9]]))
    }

    @Test func binaryUnpairedSurrogateIsReplacementCharacter() throws {
        // A UTF-16 string object with U+D800 between "a" and "z".
        let data = bplist([[0x63, 0x00, 0x61, 0xD8, 0x00, 0x00, 0x7A]])
        #expect(try read(data).value as? String == "a\u{FFFD}z")
    }

    @Test func binaryObjectOffsetInHeaderIsError() {
        // [1], with the offset of the integer changed to 0, which is inside the header.
        var bytes = Array(bplist([[0xA1, 1], [0x10, 0x01]]))
        let offsetTableOffset = Int(bytes[bytes.count - 1])
        bytes[offsetTableOffset + 1] = 0
        expectReadCorrupt(Data(bytes))
    }

    @Test func openStepEscapes() throws {
        let result = try read(#"{ a = "\a\b\f\n\r\t\v\"\\\101\U00e9"; }"#)
        #expect((result.value as? [String : Any])?["a"] as? String == "\u{7}\u{8}\u{C}\n\r\t\u{B}\"\\A\u{E9}")
    }

    @Test func utf16TextWithUnpairedSurrogateAndOddLength() throws {
        // UTF-16LE with a byte order mark, an unpaired surrogate, and one more byte at the end.
        var bytes: [UInt8] = [0xFF, 0xFE]
        for unit in Array("{ k = \"a".utf16) + [0xD800] + Array("z\"; }".utf16) {
            bytes.append(UInt8(truncatingIfNeeded: unit))
            bytes.append(UInt8(truncatingIfNeeded: unit >> 8))
        }
        bytes.append(0x41)
        let result = try read(Data(bytes))
        #expect(result.format == .openStep)
        #expect((result.value as? [String : Any])?["k"] as? String == "a\u{FFFD}z")
    }

    @Test func xmlDeclaredEncoding() throws {
        // "café" with é as the ISO Latin 1 byte 0xE9.
        let bytes = Array("<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><plist version=\"1.0\"><string>caf".utf8) + [0xE9] + Array("</string></plist>".utf8)
        let result = try read(Data(bytes))
        #expect(result.format == .xml)
        #expect(result.value as? String == "caf\u{E9}")

        expectReadCorrupt(Data(xml("<string>cafe</string>", encoding: "bogus").utf8))
    }

    @Test func corruptData() {
        expectReadCorrupt(Data())
        expectReadCorrupt(Data(xml("<dict><key>a</key></dict>").utf8))
        expectReadCorrupt(Data(xml("<integer>twelve</integer>").utf8))
        expectReadCorrupt(Data("{ a = ".utf8))
        // A binary property list whose only object has a reference past the object table.
        expectReadCorrupt(bplist([[0xA1, 9]]))
    }
}

#endif
