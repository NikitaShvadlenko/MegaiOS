import Foundation

protocol ShareUseCaseProtocol {
    func allPublicLinks(sortBy order: SortOrderEntity) -> [NodeEntity]
    func allOutShares(sortBy order: SortOrderEntity) -> [ShareEntity]
}

struct ShareUseCase: ShareUseCaseProtocol {
    private let repo: ShareRepositoryProtocol
    init(repo: ShareRepositoryProtocol) {
        self.repo = repo
    }
    
    func allPublicLinks(sortBy order: SortOrderEntity) -> [NodeEntity] {
        repo.allPublicLinks(sortBy: order)
    }
    
    func allOutShares(sortBy order: SortOrderEntity) -> [ShareEntity] {
        repo.allOutShares(sortBy: order)
    }
}
