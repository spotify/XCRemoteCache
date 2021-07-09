import XCRemoteCache

// Extra Xcode buildstep that decorates all produced non reproducible, machine-sensitive files (e.g. .swiftmodule)
// with a custom fingerprint override (with .md5 file)
// For a producer mode, it also builds an artifact package (.zip) and uploads it to the remote cache, along the
// build artifact metatadata json
XCPostbuild().main()
