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

internal import FoundationICU

extension ICU {

    final class Enumerator {
        let enumerator: OpaquePointer

        init(enumerator: OpaquePointer) {
            self.enumerator = enumerator
        }

        deinit {
            uenum_close(enumerator)
        }

        var elements: Elements {
            Elements(enumerator: self)
        }

        struct Elements : Sequence {
            let enumerator: Enumerator
            init(enumerator: Enumerator) {
                self.enumerator = enumerator
            }

            func makeIterator() -> Iterator {
                Iterator(enumerator: enumerator)
            }

            struct Iterator : IteratorProtocol {
                var beginIndex: Int32 = 0
                var endIndex: Int32 = 0
                let enumerator: Enumerator
                init(enumerator: Enumerator) {
                    self.enumerator = enumerator
                }
                mutating func next() -> String? {
                    var status = U_ZERO_ERROR
                    var resultLength = Int32(0)
                    let result = uenum_next(enumerator.enumerator, &resultLength, &status)
                    guard status.isSuccess, let result else {
                        return nil
                    }
                    return String(cString: result)
                }
            }
        }
    }
}
