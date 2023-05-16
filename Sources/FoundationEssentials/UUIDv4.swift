//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

extension UUID {
    static func v4_generatedRandom() -> uuid_t {
        var randomBits = (0 ... 15).map { _ in UInt8.random(in: .min ... .max) }
        randomBits[6] = (randomBits[6] & 0x0F) | 0x40
        randomBits[8] = (randomBits[8] & 0x3F) | 0x80

        return randomBits.withUnsafeBytes { buffer in
            return buffer.bindMemory(to: uuid_t.self)[0]
        }
    }

    static func v4_parse(uuidString string: __shared String) -> uuid_t? {
        let components = string
            .replacing("-", with: "")
            .split(by: 2)
            .compactMap { UInt8($0, radix: 16) }

        guard components.count == 16 else {
            return nil
        }

        return components.withUnsafeBytes { buffer in
            return buffer.bindMemory(to: uuid_t.self)[0]
        }
    }
}

private extension String {
    func split(by length: Int) -> [String] {
        var startIndex = self.startIndex
        var results = [Substring]()

        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }

        return results.map { String($0) }
    }
}
