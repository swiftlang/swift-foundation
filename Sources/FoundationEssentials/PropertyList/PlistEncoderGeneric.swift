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

protocol PlistEncodingReference {
    static var emptyArray : Self { get }
    static var emptyDictionary : Self { get }
    
    func insert(_ ref: Self, for key: Self)
    func insert(_ ref: Self, at index: Int)
    func insert(_ ref: Self)

    var count: Int { get }

    subscript (_ key: Self) -> Self? { get }
    
    var isBool : Bool { get }
    var isString : Bool { get }
    var isNumber : Bool { get }
    var isDate : Bool { get }
    
    var isDictionary : Bool { get }
    var isArray : Bool { get }
    
}

protocol PlistWriting<Reference> {
    associatedtype Reference : PlistEncodingReference
    
    init()
    mutating func serializePlist(_ ref: Reference) throws -> Data
}

protocol PlistEncodingFormat {
    associatedtype Reference : PlistEncodingReference
    associatedtype Writer: PlistWriting<Reference>
    
    init()
    
    var null : Reference { get }
    var `true` : Reference { get }
    var `false` : Reference { get }
    
    // Mutating because it allows the format to unique values.
    mutating func string(_ str: String) -> Reference
    mutating func number(from num: some FixedWidthInteger) -> Reference
    mutating func number(from num: some BinaryFloatingPoint) -> Reference
    mutating func date(_ date: Date) -> Reference
    mutating func data(_ data: Data) -> Reference
}

extension PlistEncodingFormat {
    func bool(_ b: Bool) -> Reference { b ? self.true : self.false }
}
