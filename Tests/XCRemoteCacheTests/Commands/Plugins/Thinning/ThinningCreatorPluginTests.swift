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

@testable import XCRemoteCache
import XCTest

class ThinningCreatorPluginTests: FileXCTestCase {

    private static let sampleMeta = MainArtifactSampleMeta.defaults
    private var targetTempDirRoot: URL!
    private var currentTargetTempDir: URL!
    private var plugin: ThinningCreatorPlugin!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let workingDir = try prepareTempDir()
        targetTempDirRoot = workingDir.appendingPathComponent("Root")
        currentTargetTempDir = targetTempDirRoot.appendingPathComponent("Current.build")
        try fileManager.spt_createEmptyDir(currentTargetTempDir)
        plugin = ThinningCreatorPlugin(
            targetTempDir: currentTargetTempDir,
            modeMarkerPath: "rc.enabled",
            dirScanner: FileManager.default)
    }

    func testReturnsEmptyExtraKeysForNoArtifacts() throws {
        let extraKeys = try plugin.extraMetaKeys(Self.sampleMeta)

        XCTAssertEqual(extraKeys, [:])
    }

    func testDefinesExtraMetaKeysForOtherTargetThatUploadedArtifact() throws {
        let otherTargetTempDir = targetTempDirRoot.appendingPathComponent("Other.build")
        let generatedArtifact = otherTargetTempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent("produced")
            .appendingPathComponent("123")
            .appendingPathExtension("zip")
        try fileManager.spt_createEmptyFile(generatedArtifact)

        let extraKeys = try plugin.extraMetaKeys(Self.sampleMeta)

        XCTAssertEqual(extraKeys, ["thinning_Other": "123"])
    }

    func testThrowsErrorWhenATargetHasMultipleArtifactsGenerated() throws {
        let otherTargetTempDir = targetTempDirRoot.appendingPathComponent("Other.build")
        let generatedArtifact = otherTargetTempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent("produced")
            .appendingPathComponent("123")
            .appendingPathExtension("zip")
        let otherGeneratedArtifact = otherTargetTempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent("produced")
            .appendingPathComponent("321")
            .appendingPathExtension("zip")
        try fileManager.spt_createEmptyFile(generatedArtifact)
        try fileManager.spt_createEmptyFile(otherGeneratedArtifact)

        XCTAssertThrowsError(try plugin.extraMetaKeys(Self.sampleMeta))
    }

    func testDefinesExtraMetaKeysForTargetsThatReusedArtifact() throws {
        let otherTargetTempDir = targetTempDirRoot.appendingPathComponent("Other.build")
        let marker = otherTargetTempDir.appendingPathComponent("rc.enabled")
        let reusedArtifact = otherTargetTempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent("123")
            .appendingPathExtension("zip")
        try fileManager.spt_createEmptyFile(marker)
        try fileManager.spt_createEmptyFile(reusedArtifact)

        let extraKeys = try plugin.extraMetaKeys(Self.sampleMeta)

        XCTAssertEqual(extraKeys, ["thinning_Other": "123"])
    }

    func testFailsGeneratingExtraMetaKeysForTwoArtifactsInTargetTempDir() throws {
        let otherTargetTempDir = targetTempDirRoot.appendingPathComponent("Other.build")
        let marker = otherTargetTempDir.appendingPathComponent("rc.enabled")
        let reusedArtifact1 = otherTargetTempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent("001")
            .appendingPathExtension("zip")
        let reusedArtifact2 = otherTargetTempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent("002")
            .appendingPathExtension("zip")
        try fileManager.spt_createEmptyFile(marker)
        try fileManager.spt_createEmptyFile(reusedArtifact1)
        try fileManager.spt_createEmptyFile(reusedArtifact2)

        XCTAssertThrowsError(try plugin.extraMetaKeys(Self.sampleMeta))
    }

    func testDefinesExtraMetaKeysForGeneratedAndReusedArtifact() throws {
        let otherTargetTempDir = targetTempDirRoot.appendingPathComponent("Generated.build")
        let generatedArtifact = otherTargetTempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent("produced")
            .appendingPathComponent("000")
            .appendingPathExtension("zip")
        try fileManager.spt_createEmptyFile(generatedArtifact)
        let reusedTargetTempDir = targetTempDirRoot.appendingPathComponent("Reused.build")
        let marker = reusedTargetTempDir.appendingPathComponent("rc.enabled")
        let reusedArtifact = reusedTargetTempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent("999")
            .appendingPathExtension("zip")
        try fileManager.spt_createEmptyFile(marker)
        try fileManager.spt_createEmptyFile(reusedArtifact)

        let extraKeys = try plugin.extraMetaKeys(Self.sampleMeta)

        XCTAssertEqual(extraKeys, [
            "thinning_Generated": "000",
            "thinning_Reused": "999"
        ])
    }
}
