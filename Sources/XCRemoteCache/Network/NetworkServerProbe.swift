import Foundation

enum NetworkServerProbeError: Error {
    /// none of the servers are alive
    case noServerAlive
}

/// Determines the best remote server to use
protocol NetworkServerProbe {
    /// Finds the best remote server to use
    func determineRemoteServer() throws -> URL
}

/// Picks the remote server with the losest latency for a health request
class LowestLatencyNetworkServerProbe: NetworkServerProbe {
    private let servers: [URL]
    private let healthPath: String
    private let fallbackServer: URL?
    private let networkClient: NetworkClient

    init(servers: [URL], healthPath: String, fallbackServer: URL?, networkClient: NetworkClient) {
        self.servers = servers
        self.fallbackServer = fallbackServer
        self.networkClient = networkClient
        self.healthPath = healthPath
    }

    /// Makes the probe synchronous request to all servers and selectes the fastes one with the a response
    /// - Throws: `NetworkServerProbeError` if none of servers are alive and no fallback is provided
    /// - Returns: URL address of the fastest server
    func determineRemoteServer() throws -> URL {
        let fastest: (URL?, TimeInterval) = servers.reduce(
            (nil, TimeInterval.greatestFiniteMagnitude)
        ) { prev, serverURL in
            let probeURL = serverURL.appendingPathComponent(healthPath)
            do {
                let start = Date()
                _ = try networkClient.fileExistsSynchronously(probeURL)
                let duration = Date().timeIntervalSince(start)
                if duration < prev.1 {
                    return (serverURL, duration)
                }
            } catch {
                // don't consider that server if the request failed (e.g. no VPN access)
            }
            return prev
        }
        guard let fastestURL = fastest.0 else {
            if let fallbackURL = fallbackServer {
                return fallbackURL
            }
            throw NetworkServerProbeError.noServerAlive
        }
        return fastestURL
    }
}
