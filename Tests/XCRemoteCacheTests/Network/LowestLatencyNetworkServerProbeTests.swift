@testable import XCRemoteCache
import XCTest

class LowestLatencyNetworkServerProbeTests: XCTestCase {
    private var probe: LowestLatencyNetworkServerProbe!

    func testPicksTheFastestServer() throws {
        let urlFast = try URL(string: "http://fast.com").unwrap()
        let urlSlow = try URL(string: "http://slow.com").unwrap()
        let delays: [String: TimeInterval] = ["fast.com": 0.01, "slow.com": 0.1]
        let networkClient = DelayEmulatedNetworkClientFake(hostsDelays: delays, fileManager: FileManager.default)
        let probe = LowestLatencyNetworkServerProbe(
            servers: [urlFast, urlSlow],
            healthPath: "health",
            fallbackServer: nil,
            networkClient: networkClient
        )

        let serverToUse = try probe.determineRemoteServer()

        XCTAssertEqual(serverToUse, urlFast)
    }
}

class DelayEmulatedNetworkClientFake: NetworkClientFake {
    private let hostsDelays: [String: TimeInterval]

    init(hostsDelays: [String: TimeInterval], fileManager: FileManager) {
        self.hostsDelays = hostsDelays
        super.init(fileManager: fileManager)
    }

    override func fileExists(_ url: URL, completion: @escaping (Result<Bool, NetworkClientError>) -> Void) {
        guard let host = url.host, let delay = hostsDelays[host] else {
            super.fileExists(url, completion: completion)
            return
        }
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay) {
            super.fileExists(url, completion: completion)
        }
    }
}
