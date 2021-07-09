@testable import XCRemoteCache
import XCTest

class ReplicatedRemotesNetworkClientTests: XCTestCase {

    private let fileManager = FileManager.default
    private var networkClient: NetworkClientFake!
    private var localSampleFile: URL!
    private var downloadURL: URL!
    private var uploadURLs: [URL]!
    private var download: URLBuilder!
    private var uploads: [URLBuilder]!
    private var client: RemoteNetworkClient!

    override func setUpWithError() throws {
        try super.setUpWithError()
        networkClient = NetworkClientFake(fileManager: fileManager)
        localSampleFile = try prepareLocalEmptyFile()
        downloadURL = try URL(string: "http://download.com").unwrap()
        uploadURLs = try [URL(string: "http://upload1.com").unwrap(), URL(string: "http://upload2.com").unwrap()]
        download = URLBuilderFake(downloadURL)
        uploads = uploadURLs.map(URLBuilderFake.init)
        client = ReplicatedRemotesNetworkClient(networkClient, download: download, uploads: uploads)
    }

    private func prepareLocalEmptyFile() throws -> URL {
        let testName = try (testRun?.test.name).unwrap()
        let url = fileManager.temporaryDirectory.appendingPathComponent(testName)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        fileManager.createFile(atPath: url.path, contents: Data(), attributes: nil)
        return url
    }

    func testUploadsToAllStreams() throws {
        let expectedArtifact1 = try URL(string: "http://upload1.com/file/id1").unwrap()
        let expectedArtifact2 = try URL(string: "http://upload2.com/file/id1").unwrap()

        try client.uploadSynchronously(localSampleFile, as: .artifact(id: "id1"))

        XCTAssertTrue(try networkClient.fileExistsSynchronously(expectedArtifact1))
        XCTAssertTrue(try networkClient.fileExistsSynchronously(expectedArtifact2))
    }

    func testCreatesInAllStreams() throws {
        let expectedMeta1 = try URL(string: "http://upload1.com/meta/commit_id").unwrap()
        let expectedMeta2 = try URL(string: "http://upload2.com/meta/commit_id").unwrap()

        try client.createSynchronously(.meta(commit: "commit_id"))

        XCTAssertTrue(try networkClient.fileExistsSynchronously(expectedMeta1))
        XCTAssertTrue(try networkClient.fileExistsSynchronously(expectedMeta2))
    }
}
