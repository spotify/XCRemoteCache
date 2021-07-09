import Foundation

/// NetworkClient with several upload streams
class ReplicatedRemotesNetworkClient: RemoteNetworkClientImpl {
    private let networkClient: NetworkClient
    private let uploadURLBuilders: [URLBuilder]

    init(_ networkClient: NetworkClient, download: URLBuilder, uploads uploadURLBuilders: [URLBuilder]) {
        self.networkClient = networkClient
        self.uploadURLBuilders = uploadURLBuilders
        super.init(networkClient, download)
    }

    /// Uploads file for all remotes in parallel (taken from `uploadURLBuilders`) and waits for all to finish
    override func uploadSynchronously(_ file: URL, as remote: RemoteCacheFile) throws {
        let urls = try uploadURLBuilders.map { builder in
            try builder.location(for: remote)
        }

        let group = DispatchGroup()
        var results: [Result<Void, NetworkClientError>] = Array(repeating: .failure(.noResponse), count: urls.count)
        urls.enumerated().forEach { index, url in
            group.enter()
            networkClient.upload(file, as: url) { receivedResult in
                results[index] = receivedResult
                group.leave()
            }
        }
        group.wait()
        try results.forEach { try $0.get() }
    }

    /// Create a file for all remotes in parallel (taken from `uploadURLBuilders`) and waits for all to finish
    override func createSynchronously(_ remote: RemoteCacheFile) throws {
        let urls = try uploadURLBuilders.map { builder in
            try builder.location(for: remote)
        }

        let group = DispatchGroup()
        var results: [Result<Void, NetworkClientError>] = Array(repeating: .failure(.noResponse), count: urls.count)
        urls.enumerated().forEach { index, url in
            group.enter()
            networkClient.create(url) { receivedResult in
                results[index] = receivedResult
                group.leave()
            }
        }
        group.wait()
        try results.forEach { try $0.get() }
    }
}
