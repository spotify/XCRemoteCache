import Foundation

/// Removes Artifacts from Cache
public protocol CacheInvalidator {
    /// Invalidates and removes artifacts if they exist
    func invalidateArtifacts()
}

enum LocalCacheInvalidatorError: Error {
    case invalidDate
}

public class LocalCacheInvalidator: CacheInvalidator {

    private let localCacheURL: URL
    private let ageInDaysToInvalidate: Int

    private static let metaDir = "meta"
    private static let artifactsDir = "file"

    public init(localCacheURL: URL, maximumAgeInDays: Int) {
        self.localCacheURL = localCacheURL
        ageInDaysToInvalidate = maximumAgeInDays
    }

    public func invalidateArtifacts() {
        // Invalidate and remove artifacts if they exist
        try? removeFiles(from: Self.metaDir)
        try? removeFiles(from: Self.artifactsDir)
    }

    private func removeFiles(from: String) throws {
        // TODO: check if we can change to use .contentAccessDateKey property

        let metaFiles = try FileManager.default.contentsOfDirectory(
            at: localCacheURL.appendingPathComponent(from),
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )
        guard let oldestAllowedDate = Date().daysAgo(days: ageInDaysToInvalidate) else {
            throw LocalCacheInvalidatorError.invalidDate
        }
        try metaFiles.filter { file -> Bool in
            let resourceValues = try file.resourceValues(forKeys: [.creationDateKey])
            guard let creationDate = resourceValues.creationDate else {
                return false
            }
            return creationDate < oldestAllowedDate
        }.forEach { file in
            try FileManager.default.removeItem(at: file)
        }
    }
}
