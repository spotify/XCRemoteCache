@testable import XCRemoteCache

import XCTest
import Zip

class ZipArtifactCreatorTests: FileXCTestCase {

    struct SimpleMeta: Meta, Equatable {
        var fileKey: String
    }

    private let sampleMeta = SimpleMeta(fileKey: "2")
    private var workingDir: URL!
    private var creator: ZipArtifactCreator!

    override func setUpWithError() throws {
        try super.setUpWithError()
        workingDir = try prepareTempDir().appendingPathComponent("creator")
        creator = ZipArtifactCreator(workingDir: workingDir, fileManager: fileManager)
    }

    func testCreatingArtifactGeneratesValidArtifactId() throws {
        let artifact = try creator.createArtifact(zipContent: [], artifactKey: "1", meta: sampleMeta)

        XCTAssertEqual(artifact.id, "1")
    }

    func testCreatingArtifactGeneratesMeta() throws {
        let artifact = try creator.createArtifact(zipContent: [], artifactKey: "1", meta: sampleMeta)

        let parsedMeta = try JSONDecoder().decode(SimpleMeta.self, from: Data(contentsOf: artifact.meta))
        XCTAssertEqual(parsedMeta, sampleMeta)
    }

    func testCreatingArtifactContainsContentAndMetaFiles() throws {
        let sampleFile = try fileManager.spt_createEmptyFile(prepareTempDir().appendingPathComponent("file.a"))

        let artifact = try creator.createArtifact(zipContent: [sampleFile], artifactKey: "1", meta: sampleMeta)

        let unzippedURL = try prepareTempDir().appendingPathComponent("unzipped")
        try Zip.unzipFile(artifact.package, destination: unzippedURL, overwrite: true, password: nil, progress: nil)
        let allFiles = try fileManager.spt_allFilesRecusively(unzippedURL)
        XCTAssertEqual(Set(allFiles), [
            unzippedURL.appendingPathComponent("file.a"),
            unzippedURL.appendingPathComponent("2.json"),
        ])
    }
}
