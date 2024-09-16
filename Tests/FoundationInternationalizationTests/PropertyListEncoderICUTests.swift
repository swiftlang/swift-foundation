// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//

import Testing

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#elseif FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

struct PropertyListEncoderICUTests {
    @Test func test_reallyOldDates_5842198() {
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<date>0009-09-15T23:16:13Z</date>\n</plist>"
        let data = plist.data(using: String._Encoding.utf8)!
        
        #expect(throws: Never.self) {
            try PropertyListDecoder().decode(Date.self, from: data)
        }
    }
    
    @Test func test_badDates() {
        let timeInterval = TimeInterval(-63145612800) // This is the equivalent of an all-zero gregorian date.
        let date = Date(timeIntervalSinceReferenceDate: timeInterval)
        
        _testRoundTrip(of: [date], in: .xml)
        _testRoundTrip(of: [date], in: .binary)
    }
    
    @Test func test_badDate_encode() throws {
        let date = Date(timeIntervalSinceReferenceDate: -63145612800) // 0000-01-02 AD
        
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode([date])
        let str = String(data: data, encoding: String.Encoding.utf8)
        #expect(str == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<array>\n\t<date>0000-01-02T00:00:00Z</date>\n</array>\n</plist>\n")
    }
    
    @Test func test_badDate_decode() throws {
        // Test that we can correctly decode a distant date in the past
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<date>0000-01-02T00:00:00Z</date>\n</plist>"
        let data = plist.data(using: String._Encoding.utf8)!
        
        let d = try PropertyListDecoder().decode(Date.self, from: data)
        #expect(d.timeIntervalSinceReferenceDate == -63145612800)
    }
    
    @Test func test_122065123_encode() throws {
        let date = Date(timeIntervalSinceReferenceDate: 728512994) // 2024-02-01 20:43:14 UTC
        
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode([date])
        let str = String(data: data, encoding: String.Encoding.utf8)
        #expect(str == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<array>\n\t<date>2024-02-01T20:43:14Z</date>\n</array>\n</plist>\n") // Previously encoded as "2024-01-32T20:43:14Z"
    }
    
    @Test func test_122065123_decodingCompatibility() throws {
        // Test that we can correctly decode an invalid date
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<date>2024-01-32T20:43:14Z</date>\n</plist>"
        let data = plist.data(using: String._Encoding.utf8)!
        
        let d = try PropertyListDecoder().decode(Date.self, from: data)
        #expect(d.timeIntervalSinceReferenceDate == 728512994) // 2024-02-01T20:43:14Z
    }
    
    @Test func test_farFutureDates() {
        let date = Date(timeIntervalSince1970: 999999999999.0)
        
        _testRoundTrip(of: [date], in: .xml)
    }
    
    struct GenericProperties : Decodable {
        enum CodingKeys: String, CodingKey {
            case array1, item1, item2
        }
        
        init(from decoder: Decoder) throws {
            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            
            var arrayContainer = try keyed.nestedUnkeyedContainer(forKey: .array1)
            #expect(try arrayContainer.decode(String.self) == "arr0")
            #expect(try arrayContainer.decode(Int.self) == 42)
            #expect(try arrayContainer.decode(Bool.self) == false)
            
            let comps = DateComponents(calendar: .init(identifier: .gregorian), timeZone: .init(secondsFromGMT: 0), year: 1976, month: 04, day: 01, hour: 12, minute: 00, second: 00)
            let date = comps.date!
            #expect(try arrayContainer.decode(Date.self) == date)
            
            let someData = Data([0xaa, 0xbb, 0xcc, 0xdd, 0x00, 0x11, 0x22, 0x33])
            #expect(try arrayContainer.decode(Data.self) == someData)
            
            #expect(try keyed.decode(String.self, forKey: .item1) == "value1")
            #expect(try keyed.decode(String.self, forKey: .item2) == "value2")
        }
    }
    
    @Test func test_genericProperties_XML() throws {
        let data = try testData(forResource: "Generic_XML_Properties", withExtension: "plist")
        
        #expect(throws: Never.self) {
            try PropertyListDecoder().decode(GenericProperties.self, from: data)
        }
    }
    
    @Test func test_genericProperties_binary() throws {
        let data = try testData(forResource: "Generic_XML_Properties_Binary", withExtension: "plist")
        
        #expect(throws: Never.self) {
            try PropertyListDecoder().decode(GenericProperties.self, from: data)
        }
    }
    
    // <rdar://problem/5877417> Binary plist parser should parse any version 'bplist0?'
    @Test func test_5877417() throws {
        var data = try testData(forResource: "Generic_XML_Properties_Binary", withExtension: "plist")
        
        // Modify the data so the header starts with bplist0x
        data[7] = UInt8(ascii: "x")
        
        #expect(throws: Never.self) {
            try PropertyListDecoder().decode(GenericProperties.self, from: data)
        }
    }
    
    @Test func test_xmlErrors() throws {
        let data = try testData(forResource: "Generic_XML_Properties", withExtension: "plist")
        let originalXML = try #require(String(data: data, encoding: .utf8))
        
        // Try an empty plist
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode(GenericProperties.self, from: Data())
        }
        // We'll modify this string in all kinds of nasty ways to introduce errors
        // ---
        /*
         <?xml version="1.0" encoding="UTF-8"?>
         <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
         <plist version="1.0">
         <dict>
         <key>array1</key>
         <array>
         <string>arr0</string>
         <integer>42</integer>
         <false/>
         <date>1976-04-01T12:00:00Z</date>
         <data>
         qrvM3QARIjM=
         </data>
         </array>
         <key>item1</key>
         <string>value1</string>
         <key>item2</key>
         <string>value2</string>
         </dict>
         </plist>
         */
        
        var errorPlists = [String : String]()
        
        errorPlists["Deleted leading <"] = String(originalXML[originalXML.index(after: originalXML.startIndex)...])
        errorPlists["Unterminated comment"] = originalXML.replacingOccurrences(of: "<dict>", with: "<-- unending comment\n<dict>")
        errorPlists["Mess with DOCTYPE"] = originalXML.replacingOccurrences(of: "DOCTYPE", with: "foobar")
        
        let range = originalXML.range(of: "//EN")!
        errorPlists["Early EOF"] = String(originalXML[originalXML.startIndex ..< range.lowerBound])
        
        errorPlists["MalformedDTD"] = originalXML.replacingOccurrences(of: "<!DOCTYPE", with: "<?DOCTYPE")
        errorPlists["Mismathed close tag"] = originalXML.replacingOccurrences(of: "</array>", with: "</somethingelse>")
        errorPlists["Bad open tag"] = originalXML.replacingOccurrences(of: "<array>", with: "<invalidtag>")
        errorPlists["Extra plist object"] = originalXML.replacingOccurrences(of: "</plist>", with: "<string>hello</string>\n</plist>")
        errorPlists["Non-key inside dict"] = originalXML.replacingOccurrences(of: "<key>array1</key>", with: "<string>hello</string>\n<key>array1</key>")
        errorPlists["Missing value for key"] = originalXML.replacingOccurrences(of: "<string>value1</string>", with: "")
        errorPlists["Malformed real tag"] = originalXML.replacingOccurrences(of: "<integer>42</integer>", with: "<real>abc123</real>")
        errorPlists["Empty int tag"] = originalXML.replacingOccurrences(of: "<integer>42</integer>", with: "<integer></integer>")
        errorPlists["Strange int tag"] = originalXML.replacingOccurrences(of: "<integer>42</integer>", with: "<integer>42q</integer>")
        errorPlists["Hex digit in non-hex int"] = originalXML.replacingOccurrences(of: "<integer>42</integer>", with: "<integer>42A</integer>")
        errorPlists["Enormous int"] = originalXML.replacingOccurrences(of: "<integer>42</integer>", with: "<integer>99999999999999999999999999999999999999999</integer>")
        errorPlists["Empty plist"] = "<plist></plist>"
        errorPlists["Empty date"] = originalXML.replacingOccurrences(of: "<date>1976-04-01T12:00:00Z</date>", with: "<date></date>")
        errorPlists["Empty real"] = originalXML.replacingOccurrences(of: "<integer>42</integer>", with: "<real></real>")
        errorPlists["Fake inline DTD"] = originalXML.replacingOccurrences(of: "PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"", with: "[<!ELEMENT foo (#PCDATA)>]")
        for (name, badPlist) in errorPlists {
            let data = try #require(badPlist.data(using: String._Encoding.utf8))
            #expect(throws: (any Error).self, "Case \(name) did not fail as expected") {
                try PropertyListDecoder().decode(GenericProperties.self, from: data)
            }
        }
        
    }
}
