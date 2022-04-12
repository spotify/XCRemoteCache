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

    private var fileReader: FileAccessorFake!
    private var reader: XCRemoteCacheConfigReader!

    override func setUp() {
        super.setUp()
        fileReader = FileAccessorFake(mode: .normal)
        reader = XCRemoteCacheConfigReader(srcRootPath: "/", fileReader: fileReader)
    }

    func testReadsFromExtraConfig() throws {
        try fileReader.write(toPath: "/.rcinfo", contents: "cache_addresses: [test]")

        let config = try reader.readConfiguration()

        XCTAssertEqual(config.cacheAddresses, ["test"])
    }

    func testOverridesExtraConfigFromExtraFile() throws {
        try fileReader.write(toPath: "/.rcinfo", contents: "cache_addresses: [test]")
        try fileReader.write(toPath: "/user.rcinfo", contents: "cache_addresses: [user]")

        let config = try reader.readConfiguration()

        XCTAssertEqual(config.cacheAddresses, ["user"])
    }

    func testReadsExtraConfigMultipleTimes() throws {
        try fileReader.write(toPath: "/.rcinfo", contents: "cache_addresses: [test]")
        try fileReader.write(toPath: "/user.rcinfo", contents: """
        cache_addresses: [user]
        extra_configuration_file: user2.rcinfo
        """)
        try fileReader.write(toPath: "/user2.rcinfo", contents: "cache_addresses: [user2]")

        let config = try reader.readConfiguration()

        XCTAssertEqual(config.cacheAddresses, ["user2"])
    }

    func testBreaksImportingExtraConfigIfReachingALoop() throws {
        try fileReader.write(toPath: "/.rcinfo", contents: "cache_addresses: [test]")
        try fileReader.write(toPath: "/user.rcinfo", contents: """
        cache_addresses: [user]
        extra_configuration_file: .rcinfo
        """)

        let config = try reader.readConfiguration()

        XCTAssertEqual(config.cacheAddresses, ["user"])
    }

    func testBreaksImportingExtraConfigIfFileDoesntExist() throws {
        try fileReader.write(toPath: "/.rcinfo", contents: "cache_addresses: [test]")
        try fileReader.write(toPath: "/user.rcinfo", contents: """
        cache_addresses: [user]
        extra_configuration_file: nonexisting.rcinfo
        """)

        let config = try reader.readConfiguration()

        XCTAssertEqual(config.cacheAddresses, ["user"])
        XCTAssertEqual(config.extraConfigurationFile, "nonexisting.rcinfo")
    }
}
