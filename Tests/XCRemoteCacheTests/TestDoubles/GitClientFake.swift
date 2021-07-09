import Foundation
@testable import XCRemoteCache

class GitClientFake: GitClient {
    private let shaHistory: [(sha: String, date: Date)]
    private let primaryBranchIndex: Int

    init(shaHistory: [(sha: String, date: Date)], primaryBranchIndex: Int) {
        self.shaHistory = shaHistory
        self.primaryBranchIndex = primaryBranchIndex
    }

    func getCurrentSha() throws -> String {
        try (shaHistory.first?.sha).unwrap()
    }

    func getCommonPrimarySha() throws -> String {
        shaHistory[primaryBranchIndex].sha
    }

    func getShaDate(sha: String) throws -> Date {
        try (shaHistory.first(where: { $0.sha == sha })?.date).unwrap()
    }

    func getPreviousCommits(starting sha: String, maximum: Int) throws -> [String] {
        let index = try shaHistory.firstIndex(where: { $0.sha == sha }).unwrap()
        return shaHistory.suffix(from: index).suffix(maximum).map { $0.sha }
    }
}
