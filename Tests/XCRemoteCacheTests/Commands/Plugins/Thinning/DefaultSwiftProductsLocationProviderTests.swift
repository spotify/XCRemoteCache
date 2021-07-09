@testable import XCRemoteCache
import XCTest

class DefaultSwiftProductsLocationProviderTests: XCTestCase {

    private let builtProductsDir: URL = "/builtProductsDir"
    private let derivedSourcesDir: URL = "/derivedSourcesDir/ThinningTarget.build/DerivedSources"
    private var provider: SwiftProductsLocationProvider!

    override func setUp() {
        super.setUp()
        provider = DefaultSwiftProductsLocationProvider(
            builtProductsDir: builtProductsDir,
            derivedSourcesDir: derivedSourcesDir
        )
    }

    func testObjcHeaderLocationReplacesTargetNameAndSetsValidHeaderName() {
        let objcPath = provider.objcHeaderLocation(targetName: "TargetName", moduleName: "MyModule")

        XCTAssertEqual(objcPath, "/derivedSourcesDir/TargetName.build/DerivedSources/MyModule-Swift.h")
    }

    func testObjcHeaderLocationResuesDerivedSourcesPattern() {
        let derivedSourcesDir: URL = "/derivedSourcesDir/ThinningTarget.build/CustomPattern"
        provider = DefaultSwiftProductsLocationProvider(
            builtProductsDir: builtProductsDir,
            derivedSourcesDir: derivedSourcesDir
        )

        let objcPath = provider.objcHeaderLocation(targetName: "TargetName", moduleName: "MyModule")

        XCTAssertEqual(objcPath, "/derivedSourcesDir/TargetName.build/CustomPattern/MyModule-Swift.h")
    }

    func testSwiftmoduleLocation() {
        let swifmoduleLocation = provider.swiftmoduleFileLocation(moduleName: "MyModule", architecture: "arm64")

        XCTAssertEqual(swifmoduleLocation, "/builtProductsDir/MyModule.swiftmodule/arm64.swiftmodule")
    }
}
