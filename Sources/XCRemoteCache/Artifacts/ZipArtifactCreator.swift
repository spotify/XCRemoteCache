import Foundation
import Zip

class ZipArtifactCreator {
    /// Location where zip file should be generated
    private let workingDir: URL
    private let fileManager: FileManager
    private let metaEncoder = JSONEncoder()

    init(workingDir: URL, fileManager: FileManager) {
        self.workingDir = workingDir
        self.fileManager = fileManager
    }

    func createArtifact<T: Meta>(zipContent: [URL], artifactKey: String, meta: T) throws -> Artifact {
        let zipURL = workingDir.appendingPathComponent("\(artifactKey).zip")
        try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true, attributes: nil)
        // Include meta json to the artifact
        let metaURL = try dumpMeta(meta)
        let zipPaths = zipContent + [metaURL]

        try Zip.zipFiles(paths: zipPaths, zipFilePath: zipURL, password: nil, progress: nil)
        return Artifact(id: artifactKey, package: zipURL, meta: metaURL)
    }

    // Save meta to a local file
    private func dumpMeta<T: Meta>(_ meta: T) throws -> URL {
        let metaURL = workingDir.appendingPathComponent(meta.fileKey).appendingPathExtension("json")
        let metaData = try metaEncoder.encode(meta)
        try fileManager.spt_writeToFile(atPath: metaURL.path, contents: metaData)
        return metaURL
    }
}
