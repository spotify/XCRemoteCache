import Foundation

/// Abstract class for consumer's consumer and producer plugins
class ThinningConsumerPlugin {
    private var wasRun: Bool = false

    deinit {
        // initialised but never run plugin suggests that standard target fallbacks to the local development
        // and DerivedData still misses build artifacts.
        guard wasRun else {
            let errorMessage = """
            \(type(of: self)) plugin has never been run, thinning cannot be supported. Verify you \
            have active network connection to the remote cache server or fallback to the non-thinned mode.
            """
            exit(1, errorMessage)
        }
    }

    /// called when plugin is run
    func onRun() {
        wasRun = true
    }
}
