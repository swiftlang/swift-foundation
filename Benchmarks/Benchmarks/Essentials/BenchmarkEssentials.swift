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
    
    // MARK: UUID
    
    Benchmark("UUIDEqual", configuration: .init(scalingFactor: .mega)) { benchmark in
        let u1 = UUID()
        let u2 = UUID()
        for _ in benchmark.scaledIterations {
            assert(u1 != u2)
        }
    }
    
    // MARK: Data
    
    func createSomeData(_ length: Int) -> Data {
        var d = Data(repeating: 42, count: length)
        // Set a byte to be another value just so we know we have a unique pointer to the backing
        // For maximum inefficiency in the not equal case, set the last byte
        d[length - 1] = UInt8.random(in: UInt8.min..<UInt8.max)
        return d
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
    
    Benchmark("DataEqualEmpty", closure: { benchmark, box in
        blackHole(box.d1 == box.d2)
    }, setup: { () -> TwoDatasBox in
        let d1 = Data()
        let d2 = d1
        let box = TwoDatasBox(d1: d1, d2: d2)
        return box
    })

    Benchmark("DataEqualInline", closure: { benchmark, box in
        blackHole(box.d1 == box.d2)
    }, setup: { () -> TwoDatasBox in
        let d1 = createSomeData(12) // Less than size of InlineData.Buffer
        let d2 = d1
        let box = TwoDatasBox(d1: d1, d2: d2)
        return box
    })
    
    Benchmark("DataNotEqualInline", closure: { benchmark, box in
        blackHole(box.d1 != box.d2)
    }, setup: { () -> TwoDatasBox in
        let d1 = createSomeData(12) // Less than size of InlineData.Buffer
        let d2 = createSomeData(12)
        let box = TwoDatasBox(d1: d1, d2: d2)
        return box
    })
    
    Benchmark("DataEqualLarge", closure: { benchmark, box in
        blackHole(box.d1 == box.d2)
    }, setup: { () -> TwoDatasBox in
        let d1 = createSomeData(1024 * 8)
        let d2 = d1
        let box = TwoDatasBox(d1: d1, d2: d2)
        return box
    })
    
    Benchmark("DataNotEqualLarge", closure: { benchmark, box in
        blackHole(box.d1 != box.d2)
    }, setup: { () -> TwoDatasBox in
        let d1 = createSomeData(1024 * 8)
        let d2 = createSomeData(1024 * 8)
        let box = TwoDatasBox(d1: d1, d2: d2)
        return box
    })

    Benchmark("DataEqualReallyLarge", closure: { benchmark, box in
        blackHole(box.d1 == box.d2)
    }, setup: { () -> TwoDatasBox in
        let d1 = createSomeData(1024 * 1024 * 8)
        let d2 = d1
        let box = TwoDatasBox(d1: d1, d2: d2)
        return box
    })

    Benchmark("DataNotEqualReallyLarge", closure: { benchmark, box in
        blackHole(box.d1 != box.d2)
    }, setup: { () -> TwoDatasBox in
        let d1 = createSomeData(1024 * 1024 * 8)
        let d2 = createSomeData(1024 * 1024 * 8)
        let box = TwoDatasBox(d1: d1, d2: d2)
        return box
    })

}
