import Foundation
@testable import XCRemoteCache

class NetworkClientFake: NetworkClient {
    private var files: [URL: Data] = [:]
    private let fileManager: FileManager

    init(fileManager: FileManager) {
        self.fileManager = fileManager
    }

    func fileExists(_ url: URL, completion: @escaping (Result<Bool, NetworkClientError>) -> Void) {
        completion(.success(files[url] != nil))
    }

    func fetch(_ url: URL, completion: @escaping (Result<Data, NetworkClientError>) -> Void) {
        let result: Result<Data, NetworkClientError>
        if let data = files[url] {
            result = .success(data)
        } else {
            result = .failure(NetworkClientError.missingBodyResponse)
        }
        completion(result)
    }

    func download(_ url: URL, to location: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        let result: Result<Void, NetworkClientError>
        if let data = files[url] {
            fileManager.createFile(atPath: location.path, contents: data, attributes: nil)
            result = .success(())
        } else {
            result = .failure(NetworkClientError.missingBodyResponse)
        }
        completion(result)
    }

    func upload(_ file: URL, as url: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        files[url] = fileManager.contents(atPath: file.path)
        completion(.success(()))
    }

    func create(_ url: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        files[url] = Data()
        completion(.success(()))
    }
}
