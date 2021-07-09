import Foundation

/// Shared logic between thinning plugin producers and consumers
enum ThinningPlugin {
    /// Prefix of the meta keys that correspond to the Thinning Plugin
    static let fileKeyPrefix = "thinning_"

    /// Finds all artifact fileKeys from the thinned artifact meta
    /// Returns a dictionary with Product names keys and aritfact fileKey values
    static func extractAllProductArtifacts(meta: MainArtifactMeta) -> [String: String] {
        let rawKeys = meta.pluginsKeys

        let filteredArtifacts = rawKeys.compactMap { key, value -> (String, String)? in
            guard key.hasPrefix(fileKeyPrefix) else {
                return nil
            }
            return (String(key.dropFirst(fileKeyPrefix.count)), value)
        }
        return Dictionary(uniqueKeysWithValues: filteredArtifacts)
    }
}
