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

enum DatWriterError: Error {
    /// Called when a string to dump to a file cannot be safely converted to bytes
    case invalidStringToSave(string: String)
}

/// Writes step input and output files in a MachO format
protocol DatWriter {
    func enable(dependencies: [URL], outputs: [URL]) throws
}

/// Implementation of the depedency-info data file writer
/// Mirrors clang implementation from `MachOLinkingContext::createDependencyFile`
/// http://llvm.org/viewvc/llvm-project/lld/trunk/lib/ReaderWriter/MachO/MachOLinkingContext.cpp?view=markup
class FileDatWriter: DatWriter {
    private static let inputFileOpcode = Data([0x10])
    private static let outputFileOpcode = Data([0x40])
    private static let separator = Data([0x0])

    private let file: URL
    private let fileManager: FileManager

    init(_ file: URL, fileManager: FileManager) {
        self.file = file
        self.fileManager = fileManager
    }


    /// Saves input and output dependencies to the `self.file` location
    ///
    /// Sample output:
    /// `{0x0}cctools-959.0.1{0x0}{0x10}inputFile1.swift{0x0}{0x10}inputFile2.m{0x0}{0x40}outputLibrary.a{0x0}`
    func enable(dependencies: [URL], outputs: [URL]) throws {
        var data = Self.separator
        try data.append("cctools-959.0.1".spt_utf8())
        data.append(Self.separator)

        try dependencies.forEach { file in
            data.append(Self.inputFileOpcode)
            try data.append(file.path.spt_utf8())
            data.append(Self.separator)
        }
        try outputs.forEach { file in
            data.append(Self.outputFileOpcode)
            try data.append(file.path.spt_utf8())
            data.append(Self.separator)
        }
        try fileManager.spt_writeToFile(atPath: file.path, contents: data)
    }
}

private extension String {
    func spt_utf8() throws -> Data {
        guard let content = data(using: .utf8) else {
            throw DatWriterError.invalidStringToSave(string: self)
        }
        return content
    }
}
