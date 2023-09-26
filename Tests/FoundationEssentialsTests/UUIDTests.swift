//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(TestSupport)
import TestSupport
#endif

final class UUIDTests : XCTestCase {
    func test_UUIDEquality() {
        let uuidA = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        let uuidB = UUID(uuidString: "e621e1f8-c36c-495a-93fc-0c247a3e6e5f")
        let uuidC = UUID(uuid: (0xe6,0x21,0xe1,0xf8,0xc3,0x6c,0x49,0x5a,0x93,0xfc,0x0c,0x24,0x7a,0x3e,0x6e,0x5f))
        let uuidD = UUID()

        XCTAssertEqual(uuidA, uuidB, "String case must not matter.")
        XCTAssertEqual(uuidA, uuidC, "A UUID initialized with a string must be equal to the same UUID initialized with its UnsafePointer<UInt8> equivalent representation.")
        XCTAssertNotEqual(uuidC, uuidD, "Two different UUIDs must not be equal.")
    }

    func test_UUIDInvalid() {
        let invalid = UUID(uuidString: "Invalid UUID")
        XCTAssertNil(invalid, "The convenience initializer `init?(uuidString string:)` must return nil for an invalid UUID string.")
    }

    // `uuidString` should return an uppercase string
    // See: https://bugs.swift.org/browse/SR-865
    func test_UUIDuuidString() {
        let uuid = UUID(uuid: (0xe6,0x21,0xe1,0xf8,0xc3,0x6c,0x49,0x5a,0x93,0xfc,0x0c,0x24,0x7a,0x3e,0x6e,0x5f))
        XCTAssertEqual(uuid.uuidString, "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "The uuidString representation must be uppercase.")
    }

    func test_UUIDdescription() {
        let uuid = UUID()
        let description: String = uuid.description
        let uuidString: String = uuid.uuidString
        XCTAssertEqual(description, uuidString, "The description must be the same as the uuidString.")
    }

    func test_hash() {
        let values: [UUID] = [
            // This list takes a UUID and tweaks every byte while
            // leaving the version/variant intact.
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a63baa1c-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53caa1c-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53bab1c-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1d-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b5f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f6-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-49db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48dc-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9567-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9468-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9886b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9787b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b86b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b76c256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b76b266c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b76b256d")!,
        ]
        checkHashable(values, equalityOracle: { $0 == $1 })
    }

    func test_AnyHashableContainingUUID() {
        let values: [UUID] = [
            UUID(uuidString: "e621e1f8-c36c-495a-93fc-0c247a3e6e5f")!,
            UUID(uuidString: "f81d4fae-7dec-11d0-a765-00a0c91e6bf6")!,
            UUID(uuidString: "f81d4fae-7dec-11d0-a765-00a0c91e6bf6")!,
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(UUID.self, type(of: anyHashables[0].base))
        expectEqual(UUID.self, type(of: anyHashables[1].base))
        expectEqual(UUID.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }

    // rdar://71190003 (UUID has no customMirror)
    func test_UUID_custom_mirror() {
        let uuid = UUID(uuidString: "89E90DC6-5EBA-41A8-A64D-81D3576EE46E")!
        XCTAssertEqual(String(reflecting: uuid), "89E90DC6-5EBA-41A8-A64D-81D3576EE46E")
    }

    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func test_UUID_Comparable() throws {
        var uuid1 = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        var uuid2 = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        XCTAssertTrue(uuid1 < uuid2)
        XCTAssertFalse(uuid2 < uuid1)
        XCTAssertFalse(uuid2 == uuid1)

        uuid1 = try XCTUnwrap(UUID(uuidString: "9707CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        uuid2 = try XCTUnwrap(UUID(uuidString: "9807CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        XCTAssertTrue(uuid1 < uuid2)
        XCTAssertFalse(uuid2 < uuid1)
        XCTAssertFalse(uuid2 == uuid1)

        uuid1 = try XCTUnwrap(UUID(uuidString: "9707CE8D-261F-4858-8BF9-C9EC3D690FCE"))
        uuid2 = try XCTUnwrap(UUID(uuidString: "9707CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        XCTAssertTrue(uuid1 > uuid2)
        XCTAssertFalse(uuid2 > uuid1)
        XCTAssertFalse(uuid2 == uuid1)

        uuid1 = try XCTUnwrap(UUID(uuidString: "9707CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        uuid2 = try XCTUnwrap(UUID(uuidString: "9707CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        XCTAssertFalse(uuid1 > uuid2)
        XCTAssertFalse(uuid2 > uuid1)
        XCTAssertTrue(uuid2 == uuid1)
    }
}
