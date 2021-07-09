import Foundation
import Yams

/// Manages XCRemoteCache statistics: rests, print to the standard output etc
public class XCStats {
    private let outputEncoder: XCRemoteCacheEncoder
    private let reset: Bool

    public init(format: XCOutputFormat, reset: Bool) {
        self.reset = reset

        outputEncoder = XCEncoderAbstractFactory().build(for: format)
    }

    public func main() {
        let env = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        let context: XCStatsContext
        do {
            config = try XCRemoteCacheConfigReader(env: env, fileManager: fileManager).readConfiguration()
            try context = XCStatsContext(config, fileManager: fileManager)
        } catch {
            exit(1, "FATAL: Prepare initialization failed with error: \(error)")
        }

        do {
            let counterFactory: FileStatsCoordinator.CountersFactory = { file, count in
                ExclusiveFileCounter(ExclusiveFile(file, mode: .override), countersCount: count)
            }
            let statsCoordinator = try FileStatsCoordinator(
                statsLocation: context.statsDir,
                cacheLocationDir: context.cacheLocation,
                counterFactory: counterFactory,
                fileManager: fileManager
            )
            if reset {
                try statsCoordinator.reset()
            }
            let stats = try statsCoordinator.readStats()
            let output = try outputEncoder.encode(stats)
            print(output)
        } catch {
            exit(1, "XCStats failed with error: \(error)")
        }
    }
}
