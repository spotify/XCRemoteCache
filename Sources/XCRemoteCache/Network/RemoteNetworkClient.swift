import Foundation

/// Client for downloading/uploading RemoteCache files
public protocol RemoteNetworkClient {
    /// Checks if the remote location exists
    func fileExists(_ file: RemoteCacheFile) throws -> Bool
    /// Reads content of the remote location
    func fetch(_ file: RemoteCacheFile) throws -> Data
    /// Downloads a file from the remote side to the local location
    func download(_ file: RemoteCacheFile, to location: URL) throws
    /// Uploads a file to the remote location
    func uploadSynchronously(_ file: URL, as remote: RemoteCacheFile) throws
    /// Creates an empty file at the remote location
    func createSynchronously(_ remote: RemoteCacheFile) throws
}

class RemoteNetworkClientImpl: RemoteNetworkClient {
    private let networkClient: NetworkClient
    private let urlBuilder: URLBuilder

    init(_ networkClient: NetworkClient, _ urlBuilder: URLBuilder) {
        self.networkClient = networkClient
        self.urlBuilder = urlBuilder
    }

    func fileExists(_ file: RemoteCacheFile) throws -> Bool {
        let url = try urlBuilder.location(for: file)
        return try networkClient.fileExistsSynchronously(url)
    }

    func fetch(_ file: RemoteCacheFile) throws -> Data {
        let url = try urlBuilder.location(for: file)
        return try networkClient.fetchSynchronously(url)
    }

    func download(_ file: RemoteCacheFile, to location: URL) throws {
        let url = try urlBuilder.location(for: file)
        try networkClient.downloadSynchronously(url, to: location)
    }

    func uploadSynchronously(_ file: URL, as remote: RemoteCacheFile) throws {
        let url = try urlBuilder.location(for: remote)
        try networkClient.uploadSynchronously(file, as: url)
    }

    func createSynchronously(_ remote: RemoteCacheFile) throws {
        let url = try urlBuilder.location(for: remote)
        try networkClient.createSynchronously(url)
    }
}
