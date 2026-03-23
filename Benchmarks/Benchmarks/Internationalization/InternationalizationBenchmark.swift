import Benchmark


#if !FOUNDATION_FRAMEWORK
let benchmarks = {
    calendarBenchmarks()
    localeBenchmarks()
    timeZoneBenchmarks()
}
#endif
