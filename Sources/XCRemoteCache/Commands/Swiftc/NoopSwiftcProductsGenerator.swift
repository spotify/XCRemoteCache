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

/// Products generator that doesn't create any swiftmodule. It is used in the compilation swift-frontend mocking, where
/// only individual .o files are created and not .swiftmodule of -Swift.h
/// (which is part of swift-frontend -emit-module invocation)
class NoopSwiftcProductsGenerator: SwiftcProductsGenerator {
    func generateFrom(
        artifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL],
        artifactSwiftModuleObjCFile: URL
    ) throws -> SwiftcProductsGeneratorOutput {
        infoLog("""
        Invoking module generation from NoopSwiftcProductsGenerator does nothing. \
        It might be a side-effect of a plugin asking to generate a module.
        """)
        // NoopSwiftcProductsGenerator is intended only for the swift-frontend
        let trivialURL = URL(fileURLWithPath: "/non-existing")
        return SwiftcProductsGeneratorOutput(swiftmoduleDir: trivialURL, objcHeaderFile: trivialURL)
    }
}
