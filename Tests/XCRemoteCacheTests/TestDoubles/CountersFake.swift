@testable import XCRemoteCache

class CountersFake: Counters {
    private var counters: [Int]

    init(_ size: Int) {
        counters = Array(repeating: 0, count: size)
    }

    func readCounters() throws -> [Int] {
        return counters
    }

    func writeCounters(_ counters: [Int]) throws {
        self.counters = counters
    }

    func reset() throws {
        counters = Array(repeating: 0, count: counters.count)
    }

    func bumpCounter(position: Int) throws {
        counters[position] += 1
    }
}
