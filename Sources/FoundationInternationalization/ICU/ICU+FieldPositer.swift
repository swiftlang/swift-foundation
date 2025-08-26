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

internal import _FoundationICU

extension ICU {
    final class FieldPositer {
        let positer: OpaquePointer?

        internal init() throws {
            var status = U_ZERO_ERROR
            positer = ufieldpositer_open(&status)
            try status.checkSuccess()
        }

        deinit {
            ufieldpositer_close(positer)
        }

        var fields: Fields {
            Fields(positer: self)
        }

        struct Fields : Sequence {
            struct Element {
                var field: Int
                var begin: Int
                var end: Int
            }

            let positer: FieldPositer
            init(positer: FieldPositer) {
                self.positer = positer
            }

            func makeIterator() -> Iterator {
                Iterator(positer: positer)
            }

            struct Iterator : IteratorProtocol {
                var beginIndex: Int32 = 0
                var endIndex: Int32 = 0
                let positer: FieldPositer
                init(positer: FieldPositer) {
                    self.positer = positer
                }
                mutating func next() -> Element? {
                    let next = ufieldpositer_next(positer.positer, &beginIndex, &endIndex)
                    guard next >= 0 else { return nil }
                    return Element(field: Int(next), begin: Int(beginIndex), end: Int(endIndex))
                }
            }
        }
    }
}
