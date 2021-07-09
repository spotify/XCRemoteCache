import Foundation

/// Factory for the RemoteNetworkClient
/// Switches between "single remote" and "mulitple upstream remotes" implementations
class RemoteNetworkClientAbstractFactory {
    private let mode: Mode
    private let downloadStreamURL: URL
    private let upstreamStreamURL: [URL]
    private let networkClient: NetworkClient
    private let urlBuilderFactory: (URL) throws -> URLBuilder

    init(mode: Mode, downloadStreamURL: URL, upstreamStreamURL: [URL], networkClient: NetworkClient, urlBuilderFactory: @escaping (URL) throws -> URLBuilder) {
        self.mode = mode
        self.downloadStreamURL = downloadStreamURL
        self.upstreamStreamURL = upstreamStreamURL
        self.networkClient = networkClient
        self.urlBuilderFactory = urlBuilderFactory
    }

    /// Builds remote network client that uses concrete remote address for download
    /// and multiple uploads (`.producer` mode)
    func build() throws -> RemoteNetworkClient {
        let downloadURLBuilder = try urlBuilderFactory(downloadStreamURL)
        guard !upstreamStreamURL.isEmpty else {
            return RemoteNetworkClientImpl(networkClient, downloadURLBuilder)
        }
        switch mode {
        case .producer:
            let upstreamBuilders = try upstreamStreamURL.map(urlBuilderFactory)
            return ReplicatedRemotesNetworkClient(
                networkClient,
                download: downloadURLBuilder,
                uploads: upstreamBuilders
            )
        case .consumer:
            return RemoteNetworkClientImpl(networkClient, downloadURLBuilder)
        }
    }
}
