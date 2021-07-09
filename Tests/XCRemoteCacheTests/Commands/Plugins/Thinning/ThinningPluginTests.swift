@testable import XCRemoteCache
import XCTest

class ThinningPluginTests: XCTestCase {

    private var meta = MainArtifactSampleMeta.defaults

    func testExtractAllArtifactsKeys() {
        meta.pluginsKeys = [
            "thinning_Target1": "1",
            "thinning_Target2": "2",
        ]

        let result = ThinningPlugin.extractAllProductArtifacts(meta: meta)

        XCTAssertEqual(result, ["Target1": "1", "Target2": "2"])
    }

    func testSkipsOtherKeysInPluginKeys() {
        meta.pluginsKeys = [
            "foreign_key": "",
            "thinning_Target1": "1",
        ]

        let result = ThinningPlugin.extractAllProductArtifacts(meta: meta)

        XCTAssertEqual(result, ["Target1": "1"])
    }

    func testAllowsEmptyTargetName() {
        meta.pluginsKeys = [
            "thinning_": "1",
        ]

        let result = ThinningPlugin.extractAllProductArtifacts(meta: meta)

        XCTAssertEqual(result, ["": "1"])
    }
}
