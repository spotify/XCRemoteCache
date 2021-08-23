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

/// Provider of all swift products location, expected by the Xcode
protocol SwiftProductsLocationProvider {
    /// Destination of the ObjC header
    /// - Parameters:
    ///   - targetName: target name of the swift target
    ///   - moduleName: name of the module
    func objcHeaderLocation(targetName: String, moduleName: String) -> URL
    /// Destination of the .swiftmodule file
    /// - Parameters:
    ///   - moduleName: name of the module
    ///   - architecture: architecture of the swiftmodule
    func swiftmoduleFileLocation(moduleName: String, architecture: String) -> URL
}

class DefaultSwiftProductsLocationProvider: SwiftProductsLocationProvider {

    private let builtProductsDir: URL
    private let derivedSourcesDir: URL

    /// Default initializer
    /// - Parameters:
    ///   - builtProductsDir: current $(BUILD_PRODUCTS_DIR)
    ///   - derivedSourcesDir: current $(DERIVED_SOURCES_DIR)
    init(
        builtProductsDir: URL,
        derivedSourcesDir: URL
    ) {
        self.derivedSourcesDir = derivedSourcesDir
        self.builtProductsDir = builtProductsDir
    }

    func objcHeaderLocation(targetName: String, moduleName: String) -> URL {
        // By default, Xcode generates ObjC headers for a Swift module in
        // $(DERIVED_SOURCES_DIR)/$(SWIFT_OBJC_INTERFACE_HEADER_NAME), where $(SWIFT_OBJC_INTERFACE_HEADER_NAME)
        // has a format of "\(moduleName)-Swift.h"
        // To generate a header location for some other target,
        // we need to replaced the last component of $DERIVED_SOURCES_DIR with {{targetName}}.build

        let derivedPathDirFormat = derivedSourcesDir.lastPathComponent
        let targetSpecificDerivedSourcesDir = derivedSourcesDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("\(targetName).build")
            .appendingPathComponent(derivedPathDirFormat)
        return targetSpecificDerivedSourcesDir.appendingPathComponent("\(moduleName)-Swift.h")
    }

    func swiftmoduleFileLocation(moduleName: String, architecture: String) -> URL {
        // swiftmodule should be generated in a DerivedData's Product dir with a format:
        // "{{ModuleName}}.swiftmodule/{{arch}}.swiftmodule"
        builtProductsDir
            .appendingPathComponent("\(moduleName).swiftmodule")
            .appendingPathComponent(architecture)
            .appendingPathExtension("swiftmodule")
    }
}
