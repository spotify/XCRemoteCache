import Foundation
@testable import XCRemoteCache

class TimeoutingNetworkClient: NetworkClient {
    func fileExists(_ url: URL, completion: @escaping (Result<Bool, NetworkClientError>) -> Void) {
        completion(.failure(.timeout))
    }

    func fetch(_ url: URL, completion: @escaping (Result<Data, NetworkClientError>) -> Void) {
        completion(.failure(.timeout))
    }

    func download(_ url: URL, to location: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        completion(.failure(.timeout))
    }

    func upload(_ file: URL, as url: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        completion(.failure(.timeout))
    }

    func create(_ url: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        completion(.failure(.timeout))
    }
}
