import Foundation

public enum RemoteCacheFile {
    /// Metadata data about a build agains given commit
    case meta(commit: String)
    /// A package of build products
    case artifact(id: String)
    /// Marker file to indicate valid artifacts generation for a given commit
    case marker(commit: String)
}

/// Builds remote URL for the RemoteCache file
protocol URLBuilder {
    func location(for remote: RemoteCacheFile) throws -> URL
}

public class URLBuilderImpl: URLBuilder {
    private let address: URL
    private let configuration: String
    private let platform: String
    private let targetName: String
    private let xcode: String
    private let envFingerprint: String
    private let schemaVersion: String

    init(address: URL, env: [String: String], envFingerprint: String, schemaVersion: String) throws {
        self.address = address
        configuration = try env.readEnv(key: "CONFIGURATION")
        platform = try env.readEnv(key: "PLATFORM_NAME")
        targetName = try env.readEnv(key: "TARGET_NAME")
        xcode = try env.readEnv(key: "XCODE_PRODUCT_BUILD_VERSION")
        self.envFingerprint = envFingerprint
        self.schemaVersion = schemaVersion
    }

    init(
        address: URL,
        configuration: String,
        platform: String,
        targetName: String,
        xcode: String,
        envFingerprint: String,
        schemaVersion: String
    ) {
        self.address = address
        self.configuration = configuration
        self.platform = platform
        self.targetName = targetName
        self.xcode = xcode
        self.envFingerprint = envFingerprint
        self.schemaVersion = schemaVersion
    }

    func location(for remote: RemoteCacheFile) throws -> URL {
        switch remote {
        case .artifact(let artifact):
            return address.appendingPathComponents(["file", "\(artifact).zip"])
        case .meta(let commit):
            let filename = "\(commit)-\(targetName)-\(configuration)-\(platform)-\(xcode)-\(envFingerprint)"
            return address.appendingPathComponents(["meta", "\(filename).json"])
        case .marker(let commit):
            let filename = "\(commit)-\(configuration)-\(platform)-\(xcode)-\(schemaVersion)"
            return address.appendingPathComponents(["marker", filename])
        }
    }
}

private extension URL {
    func appendingPathComponents(_ components: [String]) -> URL {
        return components.reduce(self) { $0.appendingPathComponent($1) }
    }
}
