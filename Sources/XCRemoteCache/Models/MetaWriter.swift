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

protocol MetaWriter {
    func write<T>(_ meta: T, locationDir : URL) throws -> URL where T : Meta
}

class JsonMetaWriter: MetaWriter {
    private let metaEncoder: JSONEncoder
    private let fileWriter: FileWriter

    init(fileWriter: FileWriter, pretty: Bool) {
        self.fileWriter = fileWriter
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = .prettyPrinted
        }
        self.metaEncoder = encoder
    }

    func write<T>(_ meta: T, locationDir : URL) throws -> URL where T : Meta {
        let metaURL = locationDir.appendingPathComponent(meta.fileKey).appendingPathExtension("json")
        let metaData = try metaEncoder.encode(meta)
        try fileWriter.write(toPath: metaURL.path, contents: metaData)
        return metaURL
    }
}
