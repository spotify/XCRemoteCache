import Foundation

enum WorkerResult {
    case successes
    case errors([Error])
}

/// Worker that manages executing blocks
protocol Worker {
    /// Adding an action to run in parallel
    /// - Parameter action: action to perform
    func appendAction(_ action: @escaping () throws -> Void)
    /// Wait for actions to finish
    /// - Returns: execution result of all appended actions
    func waitForResult() -> WorkerResult
}

/// Worker that executes actions in pararell using DispatchGroup
/// Warning! This implementation is not thread safe: all functions have to be called from the same thread
class DispatchGroupParallelizationWorker: Worker {
    private let group: DispatchGroup
    private let queue: DispatchQueue
    private let qos: DispatchQoS.QoSClass
    private var observedErrors: [Error]

    /// Default initializer
    /// - Parameter qos: QoS of the background queue to execute actions
    init(qos: DispatchQoS.QoSClass = .userInteractive) {
        group = DispatchGroup()
        queue = DispatchQueue(
            label: "DispatchGroupParallelization",
            qos: .userInteractive,
            attributes: .concurrent,
            autoreleaseFrequency: .inherit,
            target: .global(qos: qos)
        )
        observedErrors = []
        self.qos = qos
    }


    func appendAction(_ action: @escaping () throws -> Void) {
        group.enter()
        queue.async {
            do {
                try action()
            } catch {
                // Errors are not expected to be frequent so just enqueing another block to the working group
                self.group.enter()
                self.queue.async(group: self.group, qos: self.qos.dispatchQoS, flags: .barrier) {
                    self.observedErrors.append(error)
                    self.group.leave()
                }
            }
            self.group.leave()
        }
    }

    func waitForResult() -> WorkerResult {
        group.wait()
        if observedErrors.isEmpty {
            return .successes
        }
        defer {
            observedErrors = []
        }
        return .errors(observedErrors)
    }
}

extension DispatchQoS.QoSClass {
    /// Trivial transform from DispatchQoS.QoSClass to DispatchQoS
    var dispatchQoS: DispatchQoS {
        switch self {
        case .background: return .background
        case .default: return .default
        case .unspecified: return .unspecified
        case .userInitiated: return .userInitiated
        case .userInteractive: return .userInteractive
        case .utility: return .utility
        @unknown default:
            return .default
        }
    }
}
