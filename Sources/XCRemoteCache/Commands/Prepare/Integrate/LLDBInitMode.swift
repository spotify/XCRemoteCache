public enum LLDBInitMode: String, Codable, CaseIterable {
    /// Do not add anything to .lldbinit (might affect debugging experience)
    case none
    /// Installs lldb command in a ~/.lldbinit
    case user
}
