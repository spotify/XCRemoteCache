import Foundation

enum FingerprintSyncerError: Error {
    case missingResourceValue(URL)
    case invalidFingerprint
}

/// Syncs custom fingerprint overrides
protocol FingerprintSyncer {
    /// Sets a fingerprint override for all files placed directly in a source location
    func decorate(sourceDir: URL, fingerprint: String) throws
    /// Deletes fingerprint overrides in the dir (if already created)
    func delete(sourceDir: URL) throws
}

class FileFingerprintSyncer: FingerprintSyncer {
    /// Extension of the file that keeps fingerprint override
    private let fingerprintExtension: String
    private let dirAccessor: DirAccessor
    /// A list of all extensions that should be decorated with an override
    private let extensions: [String]

    init(
        fingerprintOverrideExtension: String,
        dirAccessor: DirAccessor,
        extensions: [String]
    ) {
        self.dirAccessor = dirAccessor
        fingerprintExtension = fingerprintOverrideExtension
        self.extensions = extensions
    }

    func decorate(sourceDir: URL, fingerprint: String) throws {
        guard let fingerprintData = fingerprint.data(using: .utf8) else {
            throw FingerprintSyncerError.invalidFingerprint
        }
        guard case .dir = try dirAccessor.itemType(atPath: sourceDir.path) else {
            // no directory to decorate (no module was generated)
            return
        }
        let allURLs = try dirAccessor.items(at: sourceDir)
        // recursive search is not required as all files are located in a root dir
        for file in allURLs {
            if extensions.contains(file.pathExtension) {
                let fingerprintFile = file.appendingPathExtension(fingerprintExtension)
                try dirAccessor.write(toPath: fingerprintFile.path, contents: fingerprintData)
            }
        }
    }

    func delete(sourceDir: URL) throws {
        guard case .dir = try dirAccessor.itemType(atPath: sourceDir.path) else {
            // no directory to decorate (no module was generated)
            return
        }
        let allURLs = try dirAccessor.items(at: sourceDir)
        // recursive search is not required as all files are located in a root dir
        for file in allURLs where file.pathExtension == fingerprintExtension {
            try dirAccessor.removeItem(atPath: file.path)
        }
    }
}
