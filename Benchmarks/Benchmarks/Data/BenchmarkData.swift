//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
#else
import Foundation
#endif

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .throughput]
    
    #if _pointerBitWidth(_64)
    typealias HalfInt = Int32
    #elseif _pointerBitWidth(_32)
    typealias HalfInt = Int16
    #endif

    func createSomeData(_ length: Int) -> Data {
        var d = Data(repeating: 42, count: length)
        // Set a byte to be another value just so we know we have a unique pointer to the backing
        // For maximum inefficiency in the not equal case, set the last byte
        d[length - 1] = UInt8.random(in: UInt8.min..<UInt8.max)
        return d
    }

    func createInlineData() -> Data {
        createSomeData(10) // 10B, Smaller than InlineData.Buffer
    }

    func createSmallSliceData() -> Data {
        createSomeData(1024 * 8) // 8KB, Smaller than HalfInt.max but larger than InlineData.Buffer
    }

    func createLargeSliceData() -> Data {
        createSomeData(Int(HalfInt.max) + 1024) // HalfInt + 1KB, Larger than HalfInt.max
    }

    let dataKinds: [(Data, String)] = [
        (Data(), "empty"),
        (createInlineData(), "inline"),
        (createSmallSliceData(), "smallSlice"),
        (createLargeSliceData(), "largeSlice")
    ]

    let dataKinds2: [(Data, String)] = [
        (Data(), "empty"),
        (createInlineData(), "inline"),
        (createSmallSliceData(), "smallSlice"),
        (createLargeSliceData(), "largeSlice")
    ]

    class DataBox {
        var d: Data

        init(d: Data) {
            self.d = d
        }
    }

    /// A box `Data`. Intentionally turns the value type into a reference, so we can make a promise that the inner value is not copied due to mutation during a test of insertion or replacing.
    class TwoDatasBox {
        var d1: Data
        var d2: Data
        
        init(d1: Data, d2: Data) {
            self.d1 = d1
            self.d2 = d2
        }
    }
    
    // MARK: -

    Benchmark("DataInitSequence", configuration: .init(tags: ["kind": "inline"]), closure: { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Data([1, 3, 5, 7]))
        }
    })

    Benchmark("DataInitSequence", configuration: .init(tags: ["kind": "smallSlice"]), closure: { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Data([1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33]))
        }
    })

    for (data, name) in dataKinds {
        Benchmark("DataEqual", configuration: .init(tags: ["kind": name]), closure: { _, box in
            blackHole(box.d1 == box.d2)
        }, setup: { () -> TwoDatasBox in
            TwoDatasBox(d1: data, d2: data)
        })
    }

    for ((data1, name), (data2, _)) in zip(dataKinds, dataKinds2) {
        Benchmark("DataNotEqual", configuration: .init(tags: ["kind": name]), closure: { _, box in
            blackHole(box.d1 != box.d2)
        }, setup: { () -> TwoDatasBox in
            TwoDatasBox(d1: data1, d2: data2)
        })
    }

    for (data, name) in dataKinds {
        Benchmark("DataIterate", configuration: .init(tags: ["kind": name, "iteration": "iterator"])) { _ in
            for byte in data {
                blackHole(byte)
            }
        }
    }

    for (data, name) in dataKinds {
        Benchmark("DataIterate", configuration: .init(tags: ["kind": name, "iteration": "indices"])) { _ in
            for index in data.startIndex ..< data.endIndex {
                blackHole(data[index])
            }
        }
    }

    for (data, name) in dataKinds {
        Benchmark("DataCount", configuration: .init(tags: ["kind": name])) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(data.count)
            }
        }
    }

    for (data, name) in dataKinds {
        Benchmark("DataMakeRawSpan", configuration: .init(tags: ["kind": name])) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(data.bytes.isEmpty)
            }
        }
    }

    for (data, name) in dataKinds.dropFirst() {
        Benchmark("DataAppend", configuration: .init(tags: ["kind": name]), closure: { benchmark, box in
            for _ in benchmark.scaledIterations {
                box.d.append(5)
                box.d.removeLast()
            }
        }, setup: { () -> DataBox in
            DataBox(d: data)
        })
    }

    for (data, name) in dataKinds.dropFirst() {
        Benchmark("DataInsert", configuration: .init(tags: ["kind": name]), closure: { benchmark, box in
            box.d.insert(5, at: 3)
            box.d.remove(at: 3)
        }, setup: { () -> DataBox in
            DataBox(d: data)
        })
    }

    Benchmark("DataFromString", closure: { benchmark, string in
        blackHole(string.data(using: .ascii))
    }, setup: { () -> String in
        Array(repeating: "A", count: 1024 * 1024).joined()
    })
}
