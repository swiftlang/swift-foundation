import Benchmark


#if !FOUNDATION_FRAMEWORK
let benchmarks: @Sendable () -> Void = {
    calendarBenchmarks()
    localeBenchmarks()
    timeZoneBenchmarks()
    sortComparatorBenchmarks()
}
#endif
