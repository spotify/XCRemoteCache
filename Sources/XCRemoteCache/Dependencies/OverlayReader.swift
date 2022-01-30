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

/// Maps overlay's virtual URL with an actual (local) location
struct OverlayMapping: Hashable {
    let virtual: URL
    let local: URL
}

enum JsonOverlayReaderError: Error {
    /// The source file is missing
    case missingSourceFile(URL)
    /// The file exists but its content is invalid
    case invalidSourceContent(URL)
    /// the overlay format is not supported - either contains a nested directory or a single file 
    case unsupportedFormat
}
/// Provides virtual file system overlay mappings
protocol OverlayReader {
    func provideMappings() throws -> [OverlayMapping]
}

class JsonOverlayReader: OverlayReader {

    enum Mode {
        /// Interrupts the operation if the representation file is missing
        case strict
        /// Assume empty overlay mapping if the file doesn't exist
        case bestEffort
    }

    private struct Overlay: Decodable {
        enum OverlayType: String, Decodable {
            case file
            case directory
        }

        struct Content: Decodable {
            let externalContents: String
            let name: String
            let type: OverlayType

            enum CodingKeys: String, CodingKey {
                case externalContents = "external-contents"
                case name
                case type
            }
        }

        struct RootContent: Decodable {
            let contents: [Content]
            let name: String
            let type: OverlayType
        }
        let roots: [RootContent]
    }

    private lazy var jsonDecoder = JSONDecoder()
    private let json: URL
    private let mode: Mode
    private let fileReader: FileReader


    init(_ json: URL, mode: Mode, fileReader: FileReader) {
        self.json = json
        self.mode = mode
        self.fileReader = fileReader
    }

    func provideMappings() throws -> [OverlayMapping] {
        guard let jsonContent = try fileReader.contents(atPath: json.path) else {
            switch mode {
            case .strict:
                throw JsonOverlayReaderError.missingSourceFile(json)
            case .bestEffort:
                printWarning("overlay mapping file \(json) doesn't exist. Skipping overlay for the best-effort mode.")
                return []
            }
        }

        let overlay: Overlay = try jsonDecoder.decode(Overlay.self, from: jsonContent)
        let mappings: [OverlayMapping] = try overlay.roots.reduce([]) { prev, root in
            switch root.type {
            case .directory:
                //iterate all contents
                let dir = URL(fileURLWithPath: root.name)
                let mappings: [OverlayMapping] = try root.contents.map { content in
                    switch content.type {
                    case .file:
                        let virtual = dir.appendingPathComponent(content.name)
                        let local = URL(fileURLWithPath: content.externalContents)
                        return .init(virtual: virtual, local: local)
                    case .directory:
                        throw JsonOverlayReaderError.unsupportedFormat
                    }

                }
                return prev + mappings
            case .file:
                throw JsonOverlayReaderError.unsupportedFormat
            }
        }

        return mappings
    }

}
