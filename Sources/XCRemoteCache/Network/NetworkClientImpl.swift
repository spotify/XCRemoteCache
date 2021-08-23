// Copyright (c) 2021 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import Foundation

class NetworkClientImpl: NetworkClient {
    typealias RequestResponse = (data: Data?, response: HTTPURLResponse)
    /// Method used for file upload
    private static let uploadMethod = "PUT"
    /// Method to check if the file exists
    private static let existsMethod = "HEAD"

    private let session: URLSession
    private let fileManager: FileManager
    private let maxRetries: Int
    private let awsV4Signature: AWSV4Signature?

    init(session: URLSession, retries: Int, fileManager: FileManager, awsV4Signature: AWSV4Signature?) {
        self.session = session
        self.fileManager = fileManager
        maxRetries = retries
        self.awsV4Signature = awsV4Signature
    }

    func fileExists(_ url: URL, completion: @escaping (Result<Bool, NetworkClientError>) -> Void) {
        infoLog("Checking HTTP file \(Self.existsMethod) for \(url)")
        var request = URLRequest(url: url)
        request.httpMethod = Self.existsMethod
        setupAuthenticationSignatureIfPresent(&request)

        makeRequest(request) { result in
            switch result {
            case .success:
                completion(.success(true))
            case .failure(.unsuccessfulResponse):
                completion(.success(false))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetch(_ url: URL, completion: @escaping (Result<Data, NetworkClientError>) -> Void) {
        var request = URLRequest(url: url)

        setupAuthenticationSignatureIfPresent(&request)
        makeRequest(request) { result in
            switch result {
            case .success((.some(let response), _)):
                completion(.success(response))
            case .success:
                completion(.failure(NetworkClientError.missingBodyResponse))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func download(_ url: URL, to location: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        var request = URLRequest(url: url)
        setupAuthenticationSignatureIfPresent(&request)
        makeDownloadRequest(request, output: location, completion: completion)
    }

    func upload(_ file: URL, as url: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        let request = URLRequest(url: url)
        makeUploadRequest(request, input: file, retries: maxRetries, completion: completion)
    }

    func create(_ url: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = Self.uploadMethod
        setupAuthenticationSignatureIfPresent(&request)
        makeRequest(request) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func setupAuthenticationSignatureIfPresent(_ request: inout URLRequest, data: Data? = nil) {
        guard let signature = awsV4Signature else { return }
        request.httpBody = data
        signature.addSignatureHeaderTo(request: &request)
    }

    private func makeRequest(_ request: URLRequest, completion: @escaping (Result<RequestResponse, NetworkClientError>) -> Void) {
        infoLog("Making request \(request)")

        let dataTask = session.dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse else {
                let networkError = error.map(NetworkClientError.build) ?? .inconsistentSession
                errorLog("Network request failed: \(networkError)")
                completion(.failure(networkError))
                return
            }
            guard 200 ... 299 ~= response.statusCode else {
                infoLog("Network request failed with unsuccessful code \(response.statusCode)")
                completion(.failure(.unsuccessfulResponse(status: response.statusCode)))
                return
            }
            completion(.success(RequestResponse(data: data, response: response)))
        }
        dataTask.resume()
    }

    private func makeDownloadRequest(_ request: URLRequest, output: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        guard fileManager.fileExists(atPath: output.path) == false else {
            infoLog("Download file found in the destination, skipping download.")
            completion(.success(()))
            return
        }

        let dataTask = session.downloadTask(with: request) { [fileManager] fileURL, _, error in
            guard let fileURL = fileURL else {
                let networkError = error.map(NetworkClientError.build) ?? .inconsistentSession
                errorLog("Download request failed: \(networkError)")
                completion(.failure(networkError))
                return
            }
            do {
                if fileManager.fileExists(atPath: output.path) {
                    try fileManager.removeItem(at: output)
                }
                try self.fileManager.moveItem(at: fileURL, to: output)
                completion(.success(()))
            } catch {
                errorLog("Download request handler failed: \(error)")
                completion(.failure(.build(from: error)))
            }
        }
        dataTask.resume()
    }

    private func makeUploadRequest(_ request: URLRequest, input: URL, retries: Int, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        var uploadRequest = request
        uploadRequest.httpMethod = Self.uploadMethod
        let dataFromFile = try? Data(contentsOf: input)
        setupAuthenticationSignatureIfPresent(&uploadRequest, data: dataFromFile)
        infoLog("Making upload request to \(uploadRequest) with \(retries) retries.")
        let dataTask = session.uploadTask(with: uploadRequest, fromFile: input) { _, response, error in
            let responseError: NetworkClientError?
            switch (error, response as? HTTPURLResponse) {
            case (.some(let receivedError), _):
                responseError = .build(from: receivedError)
            case (_, .some(let httpResponse)) where 200...299 ~= httpResponse.statusCode:
                responseError = nil
            case (_, .some(let httpResponse)):
                responseError = .unsuccessfulResponse(status: httpResponse.statusCode)
            default:
                responseError = .inconsistentSession
            }

            if let error = responseError {
                if retries > 0 {
                    infoLog("Upload request failed with \(error). Left retries: \(retries).")
                    self.makeUploadRequest(request, input: input, retries: retries - 1, completion: completion)
                    return
                }
                errorLog("Upload request failed: \(error)")
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
        dataTask.resume()
    }
}

private extension NetworkClientError {
    /// Converts all know URLSession errors to the NetworkClientError
    static func build(from error: Error) -> NetworkClientError {
        switch (error as NSError).code {
        case NSURLErrorTimedOut:
            return .timeout
        default:
            return .other(error)
        }
    }
}
