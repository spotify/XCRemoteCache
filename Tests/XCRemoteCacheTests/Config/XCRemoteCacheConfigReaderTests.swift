// Copyright (c) 2022 Spotify AB.
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

@testable import XCRemoteCache
import XCTest

class XCRemoteCacheConfigReaderTests: XCTestCase {

    func testReadsFromExtraConfig() throws {
        let fileReader = FileAccessorFake(mode: .normal)
        try fileReader.write(toPath: "/.rcinfo", contents: "cache_addresses: [test]")
        let reader = XCRemoteCacheConfigReader(srcRootPath: "/", fileReader: fileReader)

        let config = try reader.readConfiguration()

        XCTAssertEqual(config.cacheAddresses, ["test"])
    }

    func testOverridesExtraConfigFromExtra() throws {
        let fileReader = FileAccessorFake(mode: .normal)
        try fileReader.write(toPath: "/.rcinfo", contents: "cache_addresses: [test]")
        try fileReader.write(toPath: "/user.rcinfo", contents: "cache_addresses: [user]")
        let reader = XCRemoteCacheConfigReader(srcRootPath: "/", fileReader: fileReader)

        let config = try reader.readConfiguration()

        XCTAssertEqual(config.cacheAddresses, ["user"])
    }

    func testReadsExtraMultipleTimes() throws {
        let fileReader = FileAccessorFake(mode: .normal)
        try fileReader.write(toPath: "/.rcinfo", contents: "cache_addresses: [test]")
        try fileReader.write(toPath: "/user.rcinfo", contents: """
        cache_addresses: [user]
        extra_configuration_file: user2.rcinfo
        """)
        try fileReader.write(toPath: "/user2.rcinfo", contents: "cache_addresses: [user2]")
        let reader = XCRemoteCacheConfigReader(srcRootPath: "/", fileReader: fileReader)

        let config = try reader.readConfiguration()

        XCTAssertEqual(config.cacheAddresses, ["user2"])
    }

    func testBreaksImportingIfReachingALoop() throws {
        let fileReader = FileAccessorFake(mode: .normal)
        try fileReader.write(toPath: "/.rcinfo", contents: "cache_addresses: [test]")
        try fileReader.write(toPath: "/user.rcinfo", contents: """
        cache_addresses: [user]
        extra_configuration_file: .rcinfo
        """)
        let reader = XCRemoteCacheConfigReader(srcRootPath: "/", fileReader: fileReader)

        let config = try reader.readConfiguration()

        XCTAssertEqual(config.cacheAddresses, ["user"])
    }

    func testBreaksImportingIfExtraFileDoesntExist() throws {
        let fileReader = FileAccessorFake(mode: .normal)
        try fileReader.write(toPath: "/.rcinfo", contents: "cache_addresses: [test]")
        try fileReader.write(toPath: "/user.rcinfo", contents: """
        cache_addresses: [user]
        extra_configuration_file: nonexisting.rcinfo
        """)
        let reader = XCRemoteCacheConfigReader(srcRootPath: "/", fileReader: fileReader)

        let config = try reader.readConfiguration()

        XCTAssertEqual(config.cacheAddresses, ["user"])
        XCTAssertEqual(config.extraConfigurationFile, "nonexisting.rcinfo")
    }
}
