import XCRemoteCache

// Extra Xcode buildstep that verifies if the remotely available artifact can be used locally
// (1) Fetches meta json for a currently used commit, compares a local fingerprint of all dependencies found
// during a build and  (2) unzips the artifact product to the target temporary directory
// (3) Outputs marker file (e.g. enabled.rc in $TARGET_TEMP_DIR):
// - removes a file when the remote cache cannot be used locally
// - includes a list of all files that compilation steps should include to their .d output dependencies
XCPrebuild().main()
