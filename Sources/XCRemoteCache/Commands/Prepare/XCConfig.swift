import Foundation
import Yams

/// Print current configuration to the console
public class XCConfig {
    private let outputEncoder: XCRemoteCacheEncoder

    public init(format: XCOutputFormat) {
        outputEncoder = XCEncoderAbstractFactory().build(for: format)
    }

    public func main() {
        let env = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        do {
            config = try XCRemoteCacheConfigReader(env: env, fileManager: fileManager).readConfiguration()
        } catch {
            exit(1, "FATAL: Prepare initialization failed with error: \(error)")
        }

        do {
            let output = try outputEncoder.encode(config)
            print(output)
        } catch {
            exit(1, "XCInfo failed with error: \(error)")
        }
    }
}
