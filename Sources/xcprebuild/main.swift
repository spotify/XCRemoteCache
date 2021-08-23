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

import XCRemoteCache

// Extra Xcode buildstep that verifies if the remotely available artifact can be used locally
// (1) Fetches meta json for a currently used commit, compares a local fingerprint of all dependencies found
// during a build and  (2) unzips the artifact product to the target temporary directory
// (3) Outputs marker file (e.g. enabled.rc in $TARGET_TEMP_DIR):
// - removes a file when the remote cache cannot be used locally
// - includes a list of all files that compilation steps should include to their .d output dependencies
XCPrebuild().main()
