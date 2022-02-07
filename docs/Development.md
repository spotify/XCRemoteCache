## Development - How to build

### Building the library:

`CONFIG=Debug rake build`

### Testing the library:

`CONFIG=Debug rake test`

### Code styling:

The library uses [swift-format](https://github.com/apple/swift-format) linting tool.

* To verify that the library aligns to the formatting style, call `rake lint`
* To apply all possible autocorrections, run `rake autocorrect`

### Iterating on this library in Xcode

If you prefer to edit in Xcode, run `swift package generate-xcodeproj`. Do **not** check it in, the source of truth is the `Package.swift` file.

#### Building the app

The generated Xcode project contains schemes for each output application (like `xcswiftc`, `xcprebuild` etc.) so to build a single app, just select the appropriate scheme and build (⌘+B). If you want to build all applications at once, select `Aggregator` scheme that automatically builds all apps. `Aggregator` target in `Package.swift` is defined only for development convenience, it shouldn't be ever used as a dependency.   

#### Running tests in Xcode

All unit tests are placed in `XCRemoteCacheTests`. To run them from Xcode, just pick any application scheme and run tests (⌘+U).

#### Running E2E tests

E2E tests build a CocoaPods plugin, locally build both `producer` and `consumer` modes and verify 100% hit rate. All `Podfile` templates are placed in [e2eTests/tests](../e2eTests/tests). As a backend server, nginx server with a sample [nginx.conf](../e2eTests/nginx/nginx.conf) configuration is used. The sample server exposes local location `/tmp/cache` under http://localhost:8080.

To run tests locally, install `nginx` (e.g. `brew install nginx`) and call: 

```bash
rake 'build[release]'
rake e2e_only
```

## Project organization

### Parsing the input parameters.

The entry point of each application, `main.swift` parses the command arguments using [swift-argument-parser](https://github.com/apple/swift-argument-parser) or manually iterating all arguments. All wrappers that XCRemoteCache provides should be a thin layer and detailed parameters (like `-module-cache-path` or `-enable-objc-interop`) are irrelevant - these parameters are only transparently passed if a fallback to a local command happens. Because `ArgumentParser` fails if a non-documented argument is passed, that library can be used only for non-wrappers apps (`xcprepare`, `xcprebuild`, `xcpostbuild`) where we have a full control of all supported arguments.

### `XCRemoteCache` target

Majority of XCRemoteCache logic is stored in a `XCRemoteCache` target. It is shared between all applications and provides several entry points for each application. For example, the `xcprepare` application parses all arguments in the `XCPrepareMain` class (part of the `xcprepare` target) and calls one of the public entry point in the `XCRemoteCache`, `XCPrepare().main`. 

### Dependency management

XCRemoteCache applications trigger an entrypoint in a class with `XC` prefix (e.g. `XCPrepare`) that instantiates concrete implementations of protocol abstractions. The business logic is usually placed in the corresponding class without the `XC` prefix (e.f. `Prepare`). Concrete implementations of the protocol should not be referenced outside of that entry point class - the rest of the codebase should rely only on protocol abstraction.

Besides dependencies instantiation, the entry point class is responsible to parse a shared configuration (`.rcinfo`) and collect all context information, so the rest of the codebase doesn't rely on global variables like environment variables. 

Since `XC*` entrypoint classes do not contain any business logic and only behave as a glue class that links all required objects, this is the only class that cannot and shouldn't be tested.

### Networking

XCRemoteCache logic is very procedural, with very limited parallelization. Because almost every step depends on a result from a previous phase, the majority of network requests are done synchronously. The class that makes HTTP requests is described by the `NetworkClient` protocol. There are two implementations that conform to that protocol: `NetworkClientImpl` and `CachedNetworkClient`.
All business logic classes should depend on `RemoteNetworkClient`, transport-agnostic protocol responsible to download/upload file represented by `RemoteCacheFile` enum. 

### Plugins

XCRemoteCache allows extending caching phases (like prebuild or postbuild) with some extra features.  The Plugin API is defined in [Sources/XCRemoteCache/Artifacts/ArtifactPlugin.swift](../Sources/XCRemoteCache/Artifacts/ArtifactPlugin.swift). 

#### Thinning Plugin

Thinning plugin allows aggregating caching multiple targets from a single target (called aggregation target). With that, the Xcode project can contain only a subset of targets while in runtime, all thinned targets will be available (taken from the remote cache).

To enable thinning target on the consumer side:
* enable `thinning_enabled=true` in `.rcinfo`
* set a list of all thinned targets in `SPT_XCREMOTE_CACHE_THINNED_TARGETS=Target1,Taret2...` build settings for the aggregation target

##### Thinning Plugin limitations:

* static libraries only

### Testing recommendations

* Prefer using fakes instead of spies or mocks. Place testing doubles in [Tests/XCRemoteCacheTests/TestDoubles](../Tests/XCRemoteCacheTests/TestDoubles) so other tests can reuse them

* If you test a scenario that accesses a file on a disk, consider using the `DiskUsageSizeProviderTests` class that isolates a working directory and eliminates potential file leaks between testcases

* For dependency injection arguments, avoid passing default values (e.g. `init(dep: SomeDependency = SomeDependency())` and require passing explicit values (e.g. `init(dep: SomeDependency))`. It will be clear from a call site which dependencies is used and suggests adding a testcase when a new dependency is added.
