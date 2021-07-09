enum RemoteCommitInfo: Equatable {
    /// No commit to use for the remote cache - remote cache is disabled
    case unavailable
    /// Valid remote commit sha to reuse artifacts is available
    case available(commit: String)
}

extension RemoteCommitInfo {
    init(_ commit: String?) {
        switch commit {
        case .some(let value) where !value.isEmpty :
            self = .available(commit: value)
        default:
            self = .unavailable
        }
    }
}
