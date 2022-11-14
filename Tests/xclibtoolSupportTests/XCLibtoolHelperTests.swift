// Copyright (c) 2023 Spotify AB.
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

@testable import xclibtoolSupport
import XCTest

class XCLibtoolHelperTests: XCTestCase {
//    func testStaticFrameworkUniversalBinary() throws {
//        let mode = try XCLibtoolHelper.buildMode(
//            args: ["-o", "/universal/static", "/arch1/static", "arch2/static"]
//        )
//
//        XCTAssertEqual(mode, .createUniversalBinary(
//            output: "/universal/static",
//            inputs: ["/arch1/static", "arch2/static"]
//        ))
//    }
//
//    func testStaticLibraryUniversalBinary() throws {
//        let mode = try XCLibtoolHelper.buildMode(
//            args: ["-o", "/universal/static.a", "/arch1/static.a", "arch2/static.a"]
//        )
//
//        XCTAssertEqual(mode, .createUniversalBinary(
//            output: "/universal/static.a",
//            inputs: ["/arch1/static.a", "arch2/static.a"]
//        ))
//    }
//
//    func testUnknownExtensionInputThrowsUnsupportedMode() throws {
//        XCTAssertThrowsError(try XCLibtoolHelper.buildMode(
//            args: ["-o", "/universal/static.a", "/arch1/static.unknown"])) { error in
//            switch error {
//            case XCLibtoolHelperError.unsupportedMode: break
//            default:
//                XCTFail("Not expected error")
//            }
//        }
//    }
//
//    func testMissingOutputThrowsMissingOutput() throws {
//        XCTAssertThrowsError(try XCLibtoolHelper.buildMode(args: ["/arch1/static"])) { error in
//            switch error {
//            case XCLibtoolHelperError.missingOutput: break
//            default:
//                XCTFail("Not expected error")
//            }
//        }
//    }
}
