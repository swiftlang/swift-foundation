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

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
#else
import Foundation
import Dispatch
#endif

private final class ObservedObject: Sendable {}

private struct BenchmarkMessage: NotificationCenter.AsyncMessage {
    typealias Subject = ObservedObject
}

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .mallocCountTotal]

    Benchmark("NotificationCenter/Message/Post/NoObservers") { benchmark in
        let center = NotificationCenter()
        for _ in benchmark.scaledIterations {
            center.post(BenchmarkMessage())
        }
    }

#if !(os(macOS) && USE_PACKAGE)
    // A center with one observer on each of 1,000 other names, so posts run against populated tables
    func makeCenter() -> NotificationCenter {
        let center = NotificationCenter()
        for i in 0..<1_000 {
            _ = center.addObserver(forName: Notification.Name("background.\(i)"), object: nil, queue: nil) { _ in }
        }
        return center
    }

    func addObservers(_ count: Int, to center: NotificationCenter, name: Notification.Name) {
        for _ in 0..<count {
            _ = center.addObserver(forName: name, object: nil, queue: nil) { _ in }
        }
    }

    Benchmark("NotificationCenter/Post/UnobservedName") { benchmark in
        let center = makeCenter()
        let name = Notification.Name("unobserved")
        for _ in benchmark.scaledIterations {
            center.post(name: name, object: nil)
        }
    }

    // Observers of every name for one object must not slow down posts that nobody observes
    Benchmark("NotificationCenter/Post/UnobservedName/WithObjectObservers") { benchmark in
        let center = makeCenter()
        let observedObjects = (0..<10).map { _ in ObservedObject() }
        for object in observedObjects {
            _ = center.addObserver(forName: nil, object: object, queue: nil) { _ in }
        }
        let name = Notification.Name("unobserved")
        let poster = ObservedObject()
        for _ in benchmark.scaledIterations {
            center.post(name: name, object: poster)
        }
    }

    Benchmark("NotificationCenter/Post/ObservedForOtherObject") { benchmark in
        let center = makeCenter()
        let name = Notification.Name("observed")
        let observed = ObservedObject()
        let posted = ObservedObject()
        _ = center.addObserver(forName: name, object: observed, queue: nil) { _ in }
        for _ in benchmark.scaledIterations {
            center.post(name: name, object: posted)
        }
    }

    for count in [1, 3, 5, 30, 50] {
        Benchmark("NotificationCenter/Post/Observers/\(count)") { benchmark in
            let center = makeCenter()
            let name = Notification.Name("observed")
            addObservers(count, to: center, name: name)
            for _ in benchmark.scaledIterations {
                center.post(name: name, object: nil)
            }
        }
    }

    Benchmark("NotificationCenter/Post/Mix") { benchmark in
        let center = makeCenter()
        let light = (1...9).map { Notification.Name("light.\($0)") }
        let heavy = Notification.Name("heavy")
        for (i, name) in light.enumerated() {
            addObservers(i % 5 + 1, to: center, name: name)
        }
        addObservers(40, to: center, name: heavy)

        // Out of every 100 posts: 1 to the heavy name, 9 to light names, 90 to unobserved names
        var mix: [Notification.Name] = [heavy]
        mix += light
        mix += (0..<90).map { Notification.Name("unobserved.\($0)") }

        var i = 0
        for _ in benchmark.scaledIterations {
            center.post(name: mix[i % mix.count], object: nil)
            i += 1
        }
    }

    Benchmark("NotificationCenter/AddRemoveObserver") { benchmark in
        let center = makeCenter()
        let name = Notification.Name("observed")
        for _ in benchmark.scaledIterations {
            let observer = center.addObserver(forName: name, object: nil, queue: nil) { _ in }
            center.removeObserver(observer)
        }
    }

    // Apps add and remove observers between posts; about a quarter of real-world operations are adds or removes
    Benchmark("NotificationCenter/Mix/WithChurn") { benchmark in
        let center = makeCenter()
        let observed = Notification.Name("observed")
        let unobserved = Notification.Name("unobserved")
        addObservers(3, to: center, name: observed)
        for _ in benchmark.scaledIterations {
            let observer = center.addObserver(forName: observed, object: nil, queue: nil) { _ in }
            center.post(name: observed, object: nil)
            center.post(name: unobserved, object: nil)
            center.post(name: unobserved, object: nil)
            center.post(name: unobserved, object: nil)
            center.removeObserver(observer)
        }
    }

    // Each iteration, every thread posts 1,000 notifications to the same center; a third of them are observed
    for threads in [4, 10] {
        Benchmark("NotificationCenter/Post/Concurrent/\(threads)", configuration: .init(scalingFactor: .one)) { benchmark in
            let center = makeCenter()
            let observed = Notification.Name("observed")
            let unobserved = Notification.Name("unobserved")
            addObservers(5, to: center, name: observed)
            for _ in benchmark.scaledIterations {
                DispatchQueue.concurrentPerform(iterations: threads) { _ in
                    for i in 0..<1_000 {
                        center.post(name: i % 3 == 0 ? observed : unobserved, object: nil)
                    }
                }
            }
        }
    }
#endif
}
